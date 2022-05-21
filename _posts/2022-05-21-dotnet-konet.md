---
title: "Deploy your .NET apps faster with konet"
image: "/img/thumbnails/konet.png"
bigimg: "/img/flight-cloud.jpg"
tags: [Containers,DevOps,Programming,Windows,Kubernetes,.NET]
---

With containers being mainstream nowadays it's important to reduce the time from development to deployment. Writing and maintaining Dockerfiles is time consuming and developers not necessarily have an understanding of Docker or know all best practices for minimal, secure and optimized container images.

Not only for development but also for CI/CD you want an easy, lightweight and fast process, best without a dependency on container runtimes like Docker.

There's already some effort in this area with tools like [Jib](https://github.com/GoogleContainerTools/jib) for Java or [`ko`](https://github.com/google/ko) for Go. To extend this effort to .NET, I would like to present **`konet`** to you!


## TL;DR

`konet` is an easy to use and fast container image builder for .NET applications. It creates binaries for different platforms and architectures by running `dotnet build` and pushes only those binaries as new layers to a container image registry with a reference to a .NET base image - all without pulling base images, writing Dockerfiles or installing container runtimes.

[`konet`](https://github.com/lippertmarkus/konet) is distributed as a [.NET tool](https://aka.ms/global-tools). With .NET [set up](https://dotnet.microsoft.com/en-us/download) you easily install and use it:

```bash
# install konet
dotnet tool install --global konet

# create a new app
dotnet new console -n myconsoleapp
cd myconsoleapp/

# build and push multi platform image for app 
# limit target platforms by adding e.g. "-p linux/amd64,windows/amd64:1809" 
konet build -t lippertmarkus/test-console:1.0
```

## How `konet` works

`konet` builds container images and pushes them to a container registry without writing Dockerfiles and without installing container runtimes. You can find the [source code on GitHub](https://github.com/lippertmarkus/konet). The major steps during the build are as follows:

1. Run `dotnet build` locally for every target platform specified
1. Pack the resulting binaries into a tarball and push ot as a new layer to the container registry
1. Create a new image manifest at the container registry referencing the right official .NET runtime image as a base as well as our new layer we just pushed
1. Create a manifest list referencing all pushed images

To build and push a .NET container image with `konet` just run
```
konet build -t lippertmarkus/test-console:1.0 -p linux/amd64,windows/amd64:1809
```

The resulting image is specified in `-t` and `-p` refers to the [target platforms](https://github.com/lippertmarkus/konet#target-platforms) we want to include in our image.

`konet` uses `mcr.microsoft.com/dotnet/runtime-deps` as a base image for Linux platforms and `mcr.microsoft.com/windows/nanoserver` for Windows platforms. With those base images and self-contained and trimmed binaries created with `dotnet build` the resulting images are minimal.

Recognizable by its name, `konet` is strongly inspired by `ko`. `konet` is using [`crane`](https://lippertmarkus.com/2022/03/30/speed-image-builds-crane/) under the hood which builds on the [same libary](https://github.com/google/go-containerregistry) as `ko`.

## Comparison with Docker

`konet` not only saves time by not having you write and maintain Dockerfiles or run Docker but also gives you performance benefits when building and pushing container images. Below is a performance comparison for building and pushing a .NET Hello World console application on Linux and on Windows:

<div class="center" markdown="1">
  <img class="lazy" alt="Diagram: Build & push .NET Linux container image on Linux" data-src="/assets/posts/dotnet-konet/build-linux.png" />
</div>

<div class="center" markdown="1">
  <img class="lazy" alt="Diagram: Build & push .NET Winodws container image on Windows" data-src="/assets/posts/dotnet-konet/build-windows.png" />
</div>

In these diagrams, "Cold" means that there was nothing cached, i.e. no base images, no build cache, no .NET build objects and no images in the container registry. "Warm" represents a scenario where the image has already been build and pushed before, so re-building after a change in the source code can use existing base images, build cache, .NET build objects and layer blobs in the container registry.

Both on Linux and Windows `konet` is faster compared to a traditional process with Docker. The reasons for that are as follows:
- Docker packs the source code into a tarball and sends it to the Docker Engine for building.
- Docker pulls the .NET SDK and the .NET runtime container image. 
- Docker creates a container to run the `dotnet build` command and creates a snapshot afterwards which adds additional overhead.

`konet` doesn't have these shortcomings. It builds the image using the local .NET SDK, without the need of pulling a .NET SDK image. When pushing the image, it only references the .NET runtime image as the base image without pulling it before. Only a tarball containing the binaries is uploaded to the container registry.

## Conclusion

Running applications in containers greatly simplifies deployment, but to get there container images need to be created first. 

Using container runtimes for building images works for almost any language ecosystem but comes with the costs of lengthening the development lifecycle through the build process itself but also through maintaining Dockerfiles and the container runtime. Solutions like [Buildpacks](https://buildpacks.io/) at least get rid of the Dockerfile but still have the container runtime overhead.

By having the knowledge about the language ecosystem specifics, tools like [Jib](https://github.com/GoogleContainerTools/jib) or [`ko`](https://github.com/google/ko) can bring container image building to the next level.

Loving the idea behind those tools I created [`konet`](https://github.com/lippertmarkus/konet) for bringing the same benefits to the .NET ecosystem. Compared to `ko` and Jib, `konet` is still in an early stage with only a small subset of features. But depending on the interest in the .NET community, I would be happy to see it evolving further, also with contributions from the community!
