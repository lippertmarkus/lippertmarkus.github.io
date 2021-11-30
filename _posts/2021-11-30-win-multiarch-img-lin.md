---
title: "Building Windows multi-arch container images on Linux"
image: "/img/thumbnails/win-lin-docker.png"
bigimg: "/img/docker-hub-multiarch.jpg"
tags: [Containers,Windows,DevOps,Docker,Programming]
---

When running Windows containers the [container host version must match the image version](https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility#matching-container-host-version-with-container-image-versions). For container image publishers this often introduces the desire to provide multi-arch Windows images for all different available Windows versions for their users.

I see many publishers struggle to accomplish this because many hosted CI services often only support 1 or 2 required Windows versions and also can't run Hyper-V isolated containers.

One solution that many don't seem to know is to build multi-arch Windows images on Linux instead. This works for a large portion of applications.

## TL;DR

You can cross-build multi-arch Windows images on Linux using BuildKit as long as you don't need to execute Windows commands on the Windows image (no `RUN` instructions in the Windows stage of the Dockerfile). All other instructions can be used like normally.

Try to move the plumbing that requires `RUN` instructions (like cross-compiling, downloading binaries/libs/dependencies, creating directory structures/configs etc.) to a Linux build stage and copy the results over to the Windows image. Examples:

(a) Cross-compile [.NET app](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/tree/main/windows-examples/dotnet) on Linux and copy to Windows image:

```dockerfile
ARG WINBASE
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:6.0-alpine AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c release -o app -r win10-x64 --self-contained true /p:PublishTrimmed=true /p:PublishReadyToRun=true /p:PublishSingleFile=true

FROM ${WINBASE}
ENTRYPOINT [ "app.exe" ]
COPY --from=build /src/app/dotnet.exe app.exe
```

(b) traefik: Download [pre-compiled binary](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/blob/main/windows-examples/traefik/Dockerfile), prepare on Linux and copy to Windows image:

```dockerfile
ARG WINBASE
FROM --platform=$BUILDPLATFORM curlimages/curl:7.80.0 AS build
WORKDIR /src
RUN curl -Lo traefik.zip https://github.com/traefik/traefik/releases/download/v2.5.4/traefik_v2.5.4_windows_amd64.zip ; \
    unzip traefik.zip

FROM ${WINBASE}
ENTRYPOINT [ "traefik.exe" ]
COPY --from=build /src/traefik.exe traefik.exe
```

(c) Pull external dependencies from single-arch images and copy to Windows image:

```Dockerfile
ARG WINBASE
FROM ${WINBASE}
ENTRYPOINT [ "wins.exe", "-v" ]
COPY --from=sigwindowstools/kube-proxy:v1.22.4-1809 /utils .
```

More examples like for cross-building multi-arch Windows images for Go and Rust applications can be found [on GitHub](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/tree/main/windows-examples).

You can build these Dockerfiles on Linux with Buildkit for all six different Windows versions, create a manifest list and annotate the Windows version for each image in the list with the following script:
```bash
docker buildx create --name img-builder --use --driver docker-container --driver-opt image=moby/buildkit:v0.9.3

TARGETIMAGE="lippertmarkus/test:1.0"
BASE="mcr.microsoft.com/windows/nanoserver"
OSVERSIONS=("1809" "1903" "1909" "2004" "20H2" "ltsc2022")
MANIFESTLIST=""

for VERSION in ${OSVERSIONS[*]}
do 
    docker buildx build --platform windows/amd64 --push --pull --build-arg WINBASE=${BASE}:${VERSION} -t "$TARGETIMAGE-${VERSION}" .
    MANIFESTLIST+="${TARGETIMAGE}-${VERSION} "
done

docker manifest rm $TARGETIMAGE > /dev/null 2>&1
docker manifest create $TARGETIMAGE $MANIFESTLIST

for VERSION in ${OSVERSIONS[*]}
do 
  docker manifest rm ${BASE}:${VERSION} > /dev/null 2>&1
  full_version=`docker manifest inspect ${BASE}:${VERSION} | grep "os.version" | head -n 1 | awk '{print $$2}' | sed 's@.*:@@' | sed 's/"//g'`  || true; 
  docker manifest annotate --os-version ${full_version} --os windows --arch amd64 ${TARGETIMAGE} "${TARGETIMAGE}-${VERSION}"
done

docker manifest push $TARGETIMAGE
```

In a matter of seconds your favorite applications are available as multi-arch Windows images for every existing Windows version:

<div class="center" markdown="1">
  <img class="lazy" alt="Multi-arch Windows image for six different Windows versions" data-src="/assets/posts/win-multiarch-img-lin/docker-hub.png" />
</div>

If you want to know more details on building Windows and Linux multi-arch images and see how to combine them to a single manifest as well as use a single Dockerfile for Linux and Windows images, read on! You'll also get tips on [preventing `RUN`](#conclusion) in your target platform stages to enable cross-building.


## Intro to multi-arch images

There are three main ways to build multi-arch images in general:
1. Cross-building images through cross-compiling/downloading the binaries/scripts for each architecture on the build platform in build stages and copy them into the target platform stage. I'll refer to this as *cross-building* in the following but like I mentioned, depending on the application this could mean cross-compilation, downloading pre-compiled binaries, setting up scripts/libs/directories/configs etc. in the build stages (see Windows examples in [TL;DR](#tldr)).
2. Natively build the images for each architecture using machine emulation like QEMU on Linux or Hyper-V on Windows.
3. Natively build the images for each architecture directly on that target architectures.

The third path isn't widely used as it requires separate machines for each architecture. This is costly and often not available in CI environments but it's also rarely needed, as the first and second paths support building images for almost all relevant architectures.

Both the first and second ways can also be used to build Windows and Linux multi-arch images. Whenever possible, you should cross-build images for the target platform on your native build platform. This is the most efficient way to build multi-arch images. If you need to `RUN` commands within the build stage for the target platform because your scenario/app/language/framework doesn't support cross-building or you need to setup something that's not possible without running commands you can use machine emulation to emulate the target platform on your native build platform. Cross-building and natively building images with machine emulation on Windows and Linux will be shown in the next sections.

## BuildKit

When building on Linux [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) can be used to simplify the process for all paths mentioned. BuildKit is a toolkit for building container images in an efficient way. It's included in Docker and can be used via the `docker buildx` subcommand. With `buildx` you can add multiple local and remote builders. You can use your local Docker engine, a buildkit daemon running inside a container or in Kubernetes as builders. Let's add our own:

```bash
docker buildx create --name img-builder --use --driver docker-container --driver-opt image=moby/buildkit:v0.9.3
```

In the next sections we now investigate how creating multi-arch images with cross-building and machine emulation works for Windows and Linux with a simple [*Hello World* Go app](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/tree/main/windows-and-linux-example) and the following [Dockerfile](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/blob/main/windows-and-linux-example/Dockerfile) as an example:
```Dockerfile
ARG WINBASE=scratch
FROM --platform=$BUILDPLATFORM golang:alpine AS build
WORKDIR /src
COPY . .
RUN go get -d -v ./...
RUN if [ "$TARGETARCH" = "arm" ]; then export GOARM="${TARGETVARIANT//v}"; fi; \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o app -v ./... ; \
    chmod +x app

FROM ${WINBASE} AS windows
ENTRYPOINT [ "app.exe" ]
COPY --from=build /src/app app.exe

FROM scratch AS linux
ENTRYPOINT [ "/app" ]
COPY --from=build /src/app /app
```

Note that the example used shows how this would work for an application which can be cross-compiled to the target platform. Like I mentioned before, you could instead download/copy pre-compiled binaries for the target platform or set up other configs/scripts/libs/directories in the `build` stage (see Windows examples in [TL;DR](#tldr)). The following informations apply for all cases.


## Quick recap: Multi-arch Linux images

Creating multi-arch Linux images with Buildkit using cross-building and/or QEMU is widely used and [well described](https://docs.docker.com/desktop/multi-arch/#build-multi-arch-images-with-buildx). To highlight the differences to Windows I want to quickly recap the process anyway.

### Cross-building images

When inspecting the builder we created before we can see that only a few Linux platforms are supported:
```bash
docker buildx inspect --bootstrap
# ...
# Platforms: linux/amd64, linux/386
```

Note that the output for you can be different depending on your build platform. Also if you use Docker Desktop, [QEMU machine emulators are already installed](https://docs.docker.com/desktop/multi-arch/#multi-arch-support-on-docker-desktop) and more platforms are listed here.

The listed platforms only show on which target platforms you can execute commands, e.g. via `RUN` in your Dockerfile. If you don't need to `RUN` commands on your target platform (i.e. in the `linux` stage of the [Dockerfile above](#buildkit)) you can build our example Dockerfile for other platforms anyway:
```bash
docker buildx build --platform linux/amd64,linux/arm64,linux/riscv64,linux/ppc64le,linux/s390x,linux/386,linux/mips64le,linux/mips64,linux/arm/v7,linux/arm/v6 --push --pull --target linux -t lippertmarkus/test:1.0 .
```

<div class="center" markdown="1">
  <img class="lazy" alt="Multi-arch Linux image for different Linux architectures" data-src="/assets/posts/win-multiarch-img-lin/docker-hub-lin.png" />
</div>


### Using QEMU machine emulation

If you now try to run a command on the target platform in the `linux` stage of the Dockerfile e.g. by adding `RUN ["/app"]` at the end of the [example Dockerfile](#buildkit) you'll get an error:
```
> [linux 2/2] RUN ["/app"]:
#15 0.181 .buildkit_qemu_emulator: /app: Invalid ELF image for this architecture
```

If you need to run commands on the target platform e.g. because your scenario/app/language/framework doesn't support cross-building, you can install QEMU emulators for your target architecture on the build platform:
```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

When inspecting the builder again, we now see new plattforms supported:
```bash
docker buildx inspect --bootstrap
# ...
# Platforms: linux/amd64, linux/386, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/mips64le, linux/mips64, linux/arm/v7, linux/arm/v6
```

Running a command on the target architecture in the `linux` stage of the [example Dockerfile](#buildkit) during the build now also works:
```
#17 [linux 2/2] RUN ["/app"]
#17 0.150 Hello World
```

That's how it works for Linux multi-arch images. How does the process differ for Windows multi-arch container images?


## Multi-arch Windows images

To create multi-arch Windows images, I think you should - like for Linux - always try to cross-build Windows images on Linux whenever possible. 

Another option would be to use Hyper-V isolated containers to build the multi-arch images on Windows natively. As this isn't as efficient as cross-building you should only use it when absolutely necessary (if you need to `RUN` commands on the target platform during build). Using Hyper-V isolated container also has a few more drawbacks I will describe later in the according section. 

### Cross-building images for Windows on Linux

The same restrictions described for cross-building for Linux multi-arch images also apply to building Windows multi-arch images on Linux: If you don't need to run commands on Windows (i.e. in the `windows` stage of the [Dockerfile above](#buildkit)) you can build your Windows multi-arch image on Linux similarly to how you build Linux multi-arch images. 

For Windows instead of specifying multiple platforms you need to use different base images for each version of Windows. The base image in our example is passed via a build argument `WINBASE` and each image is pushed independently:

```bash
TARGETIMAGE="lippertmarkus/test:1.0"
BASE="mcr.microsoft.com/windows/nanoserver"
OSVERSIONS=("1809" "1903" "1909" "2004" "20H2" "ltsc2022")
MANIFESTLIST=""

for VERSION in ${OSVERSIONS[*]}
do 
    docker buildx build --platform windows/amd64 --push --pull --build-arg WINBASE=${BASE}:${VERSION} --target windows -t "$TARGETIMAGE-${VERSION}" .
    MANIFESTLIST+="${TARGETIMAGE}-${VERSION} "
done
```

To combine all images to a single manifest list we can use the `docker manifest` command. For Windows you also need to manually annotate the `os.version` so that users automatically get the correct version of the image depending on the Windows host OS version:
```bash
docker manifest rm $TARGETIMAGE > /dev/null 2>&1
docker manifest create $TARGETIMAGE $MANIFESTLIST

for VERSION in ${OSVERSIONS[*]}
do 
  docker manifest rm ${BASE}:${VERSION} > /dev/null 2>&1
  full_version=`docker manifest inspect ${BASE}:${VERSION} | grep "os.version" | head -n 1 | awk '{print $$2}' | sed 's@.*:@@' | sed 's/"//g'`  || true; 
  docker manifest annotate --os-version ${full_version} --os windows --arch amd64 ${TARGETIMAGE} "${TARGETIMAGE}-${VERSION}"
done

docker manifest push $TARGETIMAGE
```

The result on Docker Hub looks like this:
<div class="center" markdown="1">
  <img class="lazy" alt="Multi-arch Windows image for six different Windows versions" data-src="/assets/posts/win-multiarch-img-lin/docker-hub.png" />
</div>

More examples for cross-building are described in the [TL;DR section](#tldr) and [on GitHub](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/tree/main/windows-examples).


### Using Hyper-V machine emulation on Windows

First off: [You can't use QEMU on Linux to run Windows binaries](https://github.com/microsoft/Windows-Containers/issues/34#issuecomment-655291308) like you can do for other Linux architectures.

If you need to run commands in the target platform build stage for building multi-arch Windows images, you need to instead use Hyper-V isolation and get rid of the Linux build stage (may replace it with a Windows stage). Hyper-V isolation works different to the QEMU machine emulation on Linux which only emulates running single binaries. Hyper-V isolation instead runs the whole Windows container image in an optimized Hyper-V virtual machine and therefore emulates a machine with a different Windows version. This is known as  [Hyper-V isolated containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/hyperv-container#hyper-v-isolation).

Hyper-V isolation supports running Windows containers with Windows versions lower or equal to the container host and therefore also enables building Windows container images for different Windows versions. 

One example when you would use Hyper-V for building images could be running custom installers like for python:
```Dockerfile
ARG WINBASE
FROM ${WINBASE}
ADD https://www.python.org/ftp/python/3.11.0/python-3.11.0a2-amd64.exe python.exe
RUN ["python.exe", "/quiet"]
```

It's important to understand that there are not many cases where Hyper-V isolation is really needed. To enable cross-building for this specific case here you could try extracting files from the installer in a Linux build stage. Another way would be to build this image natively on Windows a single time as a single-arch image and use it in your cross-build to copy `C:\python` to the target Windows stage similarly to the example (c) in the [TL;DR section](#tldr). I describe some tips on how to avoid using Hyper-V isolation [later](#conclusion) in this post.

As [BuildKit doesn't work on Windows](https://docs.docker.com/develop/develop-images/build_enhancements/#limitations) you would need to use the default `docker build` command instead with Hyper-V isolation enabled to create the Windows container images:
```powershell
docker build --pull --isolation hyperv --build-arg WINBASE=${BASE}:${VERSION} -t "${TARGETIMAGE}-${VERSION}" .
docker push "${TARGETIMAGE}-${VERSION}"
```

You can also run that in a loop and create a manifest list like we did in the last section. 

Using Hyper-V isolated containers to create multi-arch Windows images however has a few drawbacks:

- Building multi-arch images natively on Windows with Hyper-V isolated containers is much slower than cross-building because the `RUN` commands need to be executed for every Windows version.
- Hyper-V isolation is not always available in CI environments, e.g. GitHub Actions and Azure Pipeline Hosted Agents don't support it.
- Hyper-V isolation requires nested virtualization which is only available for certain virtual machine sizes in public clouds like Azure.
- You must keep the container host up to date because you can only build images for [image versions lower or equal to the container host](https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility#windows-server-host-os-compatibility).
- Hyper-V isolation adds overhead as each container or `RUN`-step during image build is run in a separate VM.


Note that you could also ["cross-build for Windows on Windows"](https://github.com/lippertmarkus/cross-building-windows-and-linux-multi-arch-images/blob/main/windows-and-linux-example/Dockerfile.win) with Hyper-V isolation by using a `build` stage with a fixed Windows image version and copying the binary to images with different target Windows versions like we did on Linux. This would be almost as fast as on Linux as the build stage would be running only once. But if you only need to copy files to a target platform image anyway you should do it on Linux because of the drawbacks of Hyper-V isolation mentioned above.


## Combining Windows and Linux multi-arch images

To get a single manifest list with all Windows versions and Linux platforms we can combine our snippets from above and extend them with commands to get images from the Linux manifest list, append and annotate Windows images and overwrite the manifest list in the registry:

```bash
TARGETIMAGE="lippertmarkus/test:1.0"
BASE="mcr.microsoft.com/windows/nanoserver"
OSVERSIONS=("1809" "1903" "1909" "2004" "20H2" "ltsc2022")
MANIFESTLIST=""

# build for Linux
docker buildx build --platform linux/amd64,linux/arm64,linux/riscv64,linux/ppc64le,linux/s390x,linux/386,linux/mips64le,linux/mips64,linux/arm/v7,linux/arm/v6 --push --pull --target linux -t $TARGETIMAGE .

# build for Windows
for VERSION in ${OSVERSIONS[*]}
do 
    docker buildx build --platform windows/amd64 --push --pull --build-arg WINBASE=${BASE}:${VERSION} --target windows -t "${TARGETIMAGE}-${VERSION}" .
    MANIFESTLIST+="${TARGETIMAGE}-${VERSION} "
done

# Get images from Linux manifest list, append and annotate Windows images and overwrite in registry
docker manifest rm $TARGETIMAGE > /dev/null 2>&1
lin_images=$(docker manifest inspect $TARGETIMAGE | jq -r '.manifests[].digest')

docker manifest create $TARGETIMAGE $MANIFESTLIST ${lin_images//sha256:/${TARGETIMAGE%%:*}@sha256:}

for VERSION in ${OSVERSIONS[*]}
do 
  docker manifest rm ${BASE}:${VERSION} > /dev/null 2>&1
  full_version=`docker manifest inspect ${BASE}:${VERSION} | grep "os.version" | head -n 1 | awk '{print $$2}' | sed 's@.*:@@' | sed 's/"//g'`  || true; 
  docker manifest annotate --os-version ${full_version} --os windows --arch amd64 ${TARGETIMAGE} "${TARGETIMAGE}-${VERSION}"
done

docker manifest push $TARGETIMAGE
```

Now almost anyone should be able to use our application:

<div class="center" markdown="1">
  <img class="lazy" alt="Manifest list supporting various Windows versions and Linux platforms" data-src="/assets/posts/win-multiarch-img-lin/docker-hub-all.png" />
</div>


## Conclusion

It's recommendable to cross-build multi-arch images for Linux and Windows on Linux when possible. Using QEMU when building Linux multi-arch images to execute the `RUN` commands in target platform stages is slow but depending on the effort may acceptable. 

For Windows however using Hyper-V isolation to build multi-arch images comes with many drawbacks described above and isn't always possible depending on your infrastructure or CI system. Therefore if you want to provide multi-arch Windows images you should consider refactoring your Dockerfiles to support cross-building on Linux.

**Tips to avoid `RUN` commands in the target platform stages to enable/optimize cross-building:**
- For platforms/frameworks with support for cross-compiling use a build stage running on the build platform to build binaries for your target platform stage and copy them there. This is shown in example (a) in the [TL;DR section](#tldr).
- You don't always need to do the build within a build stage. If you already have an environment set up to generate binaries for different target platforms you can just `COPY` them to the target platform stage from the local file system.
- For images based on hosted pre-compiled binaries, use a build stage running on the build platform to download and extract them and copy them to the target platform stage. This is shown in example (b) in the [TL;DR section](#tldr).
- Installation scripts or installers often do nothing else than downloading some files. They often have parameters to set the platform for the files to download so you can run them in the build stage and just copy the needed paths to the target platform stage.
- Linux: There are cross-compilation helpers like [`tonistiigi/xx`](https://github.com/tonistiigi/xx) that help you set up the right environment for cross-compiling, installing dependencies etc. in your build stage running on the build platform.
- Linux: For minimal Linux images using `scratch` often doesn't work because it's missing CA certificates or non-root users. While you could copy them to a target platform stage yourself, you could also use [`distroless` images](https://github.com/GoogleContainerTools/distroless)
- Windows: If you use MSI installers which only extract files to a certain location, you can try using [`msitools`](https://wiki.gnome.org/msitools) to extract the files and copy them to the target platform stages.
- Windows: When you have no alternatives and need to run Windows programs, installers or things like [Chocolatey](https://chocolatey.org/) you can also natively build a single-arch image where you run those things once. In your cross-builds on Linux you can copy the resulting directories from that image to the Windows target stage. This also makes sure that your dependencies are locked to a known-working version. This is shown in the example (c) in the [TL;DR section](#tldr).


## Further reading
- Peri Thompson's [blog post about the same topic](https://perithompson.netlify.app/blog/creating-multiarch-containers/) as big inspiration for this blog post
- SIG Windows using cross-building for easily creating [flannel](https://github.com/kubernetes-sigs/sig-windows-tools/blob/master/kubeadm/flannel/Dockerfile) and [kube-proxy](https://github.com/kubernetes-sigs/sig-windows-tools/blob/master/kubeadm/kube-proxy/Dockerfile) Windows images on Linux
- [Issue for BuildKit Windows Support on GitHub](https://github.com/microsoft/Windows-Containers/issues/34)
- Google ko [supports building Go containers for Windows](https://github.com/google/ko/pull/374) by applying a tar with the binary to a base image layer
- crane support for adding tars to Windows base image [in progress](https://github.com/google/go-containerregistry/pull/1179)
