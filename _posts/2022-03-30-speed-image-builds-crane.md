---
title: "Speed up your Windows container image builds with crane"
image: "/img/thumbnails/crane-win.png"
bigimg: "/img/speed.jpg"
tags: [Containers,Windows,Docker]
---

With Windows Server 2022 node pools not yet supported by managed Kubernetes offerings like [Azure Kubernetes Service](https://github.com/microsoft/Windows-Containers/issues/162) or [GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-cluster-windows#version_mapping), open [issues in containerd](https://github.com/containerd/containerd/issues/6508) and the long transition time it generally takes, not many currently benefit from the [announced down-level compatbility](https://techcommunity.microsoft.com/t5/containers/windows-server-2022-and-beyond-for-containers/ba-p/2712487) for Windows containers. This means that the need for building multi-arch Windows container images is still present for many people and with that the downsides of Windows container image sizes when compared to Linux.

Linux container images for Go or Rust applications can be based on Distroless base images which have a download size of less than 10 MB. If your Windows application supports it, the smallest `nanoserver` Windows base image is still around 100 MB and the `servercore` around 2.7 GB in download size. With the down-level compatibility of Windows containers not being reality yet this means an application needs to be built on a different base image for each Windows version, resulting in downloading those 100 MB or 2.7 GB up to 6 times.

In a [previous post]({% post_url 2021-11-30-win-multiarch-img-lin %}) I showed how building Windows container images can be automated on Linux with Buildkit. This makes it comfortable but still takes quite some time because Buildkit downloads another Windows base image for each target version.

But there's another option: You can also create Windows container images on Windows or Linux with a tool called `crane`, all without downloading any base images at all!

## TL;DR

If you don't need to execute Windows commands on the Windows image during image build you can use `crane` to push your application as a new layer and reference a base image as the parent layer without downloading it:

```powershell
# build Windows app once (can also be done within a container if you need reproducible build environments)
dotnet publish -c release -o out -r win10-x64 --self-contained true /p:PublishTrimmed=true /p:PublishReadyToRun=true /p:PublishSingleFile=true
tar -cvf app.tar --directory=out dotnet.exe

$targetManifest = "lippertmarkus/test-crane:1.0"
$baseImageTags = @("1809", "1909", "2004", "20H2", "ltsc2022")
$pushedImages = @()

foreach ($baseImageTag in $baseImageTags)
{
    # push our app layer, reference base image as parent layer without downloading it and set the entrypoint
    $pushedImages += (crane mutate --platform windows/amd64 --entrypoint=dotnet.exe --append app.tar mcr.microsoft.com/windows/nanoserver:$baseImageTag -t "$($targetManifest)-$($baseImageTag)")
}

# create manifest list containing all pushed images
docker manifest rm $targetManifest
docker manifest create $targetManifest $pushedImages
docker manifest push $targetManifest
```

Read on to learn more about how `crane` works.

## `crane` and Windows Container images

[`crane`](https://github.com/google/go-containerregistry/tree/main/cmd/crane) is a tool for interacting with remote images and registries. It can be used to inspect images but also to mutate images through adding files or changing their configuration like the entrypoint or the user.

Let's use it to look at how an image is stored in the registry:
```powershell
crane manifest lippertmarkus/test-crane:1.0-1909
```

```json
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
    "config": {
        "mediaType": "application/vnd.docker.container.image.v1+json",
        "size": 489,
        "digest": "sha256:dc96c8eb2d2c1822f8feed83f961bb2dc8c995c452cf0c168f352c6d78f12a43"
    },
    "layers": [
        {
            "mediaType": "application/vnd.docker.image.rootfs.foreign.diff.tar.gzip",
            "size": 102144333,
            "digest": "sha256:fe8c39bf0334000f0db1aed1c1eddb880d2af07f765f8ff0f91ace66c655cab9",
            "urls": [
                "https://mcr.microsoft.com/v2/windows/nanoserver/blobs/sha256:fe8c39bf0334000f0db1aed1c1eddb880d2af07f765f8ff0f91ace66c655cab9"
            ]
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 7601464,
            "digest": "sha256:7ed58b62fa1151c7f67bbf3dbbfd11a10835984267e1263fd6300ee2b15da918"
        }
    ]
}
```

The image is defined as a manifest. The manifest references a series of layers the image consists of. In the example we can see that `nanoserver` is used as a base image from the Microsoft container registry. There's another layer on top that in our case contains the application. Each layer only consists of added or changed files different to its parent layer. When targeting different Windows versions, only the base layer changes and the application layer usually stays the same. Each layer is just a compressed tar archive with a special directory layout containing the files that are different to the parent layer.

The digest referenced in the `config` property contains the configuration of the image. It holds some additional information like the layer history, the OS and architecture as well as settings like the entrypoint or the user:

```powershell
crane config lippertmarkus/test-crane:1.0-1909
```

```json
{
    "architecture": "amd64",
    "created": "2021-05-04T21:22:59.0761106Z",
    "history": [
        {
            "created": "2021-05-04T21:22:59.0761106Z",
            "created_by": "Apply image 1909-amd64"
        },
        {
            "created": "0001-01-01T00:00:00Z"
        }
    ],
    "os": "windows",
    "rootfs": {
        "type": "layers",
        "diff_ids": [
            "sha256:a855a0b30834b3ba20b3c87350b4ab2b2750ed99aa7da0e14599aeb7f29557e5",
            "sha256:3bdd68d60465b15b99355269fef14df94ef0229c57668a5e66361b0d48d41815"
        ]
    },
    "config": {
        "Entrypoint": [
            "dotnet.exe"
        ],
        "User": "ContainerUser"
    },
    "os.version": "10.0.18363.1556"
}
```

With this knowledge you should understand that there's no need to download the base image for each version [if you don't need to execute Windows commands]({% post_url 2021-11-30-win-multiarch-img-lin %}#conclusion) during the image build. Instead you can just create and push a new layer containing your app and reference different base images as parent layers without downloading them.

## Mutating images with crane

`crane` can mutate images by adding files and/or changing their configuration. Let's walk through an example for a .NET application.

We first build our Windows application and pack it into a tar archive which can be used as our application image layer:

```powershell
# build Windows app once (can also be done within a container if you need reproducible build environments)
dotnet publish -c release -o out -r win10-x64 --self-contained true /p:PublishTrimmed=true /p:PublishReadyToRun=true /p:PublishSingleFile=true
tar -cvf app.tar --directory=out dotnet.exe
```

As we want to run our application on a `nanoserver` base image we use `crane mutate` to *mutate* the `mcr.microsoft.com/windows/nanoserver:ltsc2022` image by adding our application layer and changing the entrypoint:
```powershell
crane mutate --platform windows/amd64 --entrypoint=dotnet.exe --append app.tar mcr.microsoft.com/windows/nanoserver:ltsc2022 -t "lippertmarkus/test-crane:1.0-ltsc2022"
```

`crane` adapts the directory layout of our application layer in `app.tar` to work for Windows container images and pushes our application layer to the registry. As we specified a new tag with `-t`, `crane` then creates a copy of the image manifest as well as the [image configuration](#crane-and-windows-container-images) from `mcr.microsoft.com/windows/nanoserver:ltsc2022`. The image configuration is adapted with the entrypoint we set and pushed to the registry as well.

Lastly our pushed application layer and image configuration is added to the [manifest](#crane-and-windows-container-images) copied before and that manifest is pushed to `lippertmarkus/test-crane:1.0-ltsc2022`.

This can easily be done for multiple base images by the script shown in the [TL;DR section](#tldr), which also creates a manifest list at the end referencing all images created before.


## Verifying our multi-arch Windows image

The manifest list created by the [script](#tldr) references all the image manifests we pushed before:

```powershell
crane config lippertmarkus/test-crane:1.0
```

```json
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      //...
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 738,
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.20348.587"
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 738,
         "digest": "sha256:e86489b07a160f9c48fbd20c8ae0f680288c162c0f376c8034ed7c314fbe64ea",
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.19042.1586"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 738,
         "digest": "sha256:fefae09d4b87f6d59547d7b0c8ebcea18fc8a4fb9311adcfa741fb97a274cec0",
         "platform": {
            "architecture": "amd64",
            "os": "windows",
            "os.version": "10.0.18363.1556"
         }
      }
   ]
}
```

Each manifest is annotated with the Windows version to allow the container runtime to pick the right image for the Windows container host.

Comparing the latter two image manifests we can see they only differ in the referenced base image and image configuration but share the same application layer with the .NET app in it:
```
crane manifest lippertmarkus/test-crane@sha256:fefae09d4b87f6d59547d7b0c8ebcea18fc8a4fb9311adcfa741fb97a274cec0
crane manifest lippertmarkus/test-crane@sha256:e86489b07a160f9c48fbd20c8ae0f680288c162c0f376c8034ed7c314fbe64ea
```

<div class="center" markdown="1">
  <img class="lazy" alt="Differences of the images in our manifest list" data-src="/assets/posts/speed-image-builds-crane/diff-manifests.png" />
</div>

That means that crane pushed the application layer just once when creating the first image and reused that application layer for the other images. When comparing that to the usual approach e.g. when using `docker build`, this is much faster as it doesn't need to download the base image for each version.

## Limitations

Running Windows command during the image build is not supported when using `crane`. I explained some tips to work around that in a [previous post]({% post_url 2021-11-30-win-multiarch-img-lin %}#conclusion).

Also `crane` currently has no mutation equivalent for `USER`, `WORKDIR`, `SHELL`, `EXPOSE`, `VOLUME` and `HEALTHCHECK` you may find in a Dockerfile. The last three are not used in Kubernetes, `USER` & `WORKDIR` can be set at deployment time and `SHELL` is rarely needed in my opinion. If you have the need to set one of those, you can also use a base image with defaults that work for you.

## There's more

- Look at [what else `crane` can do](https://github.com/google/go-containerregistry/blob/main/cmd/crane/recipes.md)
- Use the [`crane` GitHub Action](https://github.com/imjasonh/setup-crane) in your GitHub workflows
- Look at the [experimental support for rebasing images with `crane`](https://github.com/google/go-containerregistry/blob/main/cmd/crane/rebase.md)
- My efforts to support [pushing images by digest](https://github.com/google/go-containerregistry/pull/1323) and to [simplify building multi-arch images](https://github.com/google/go-containerregistry/pull/1324) with `crane`