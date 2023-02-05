---
title: "Getting started with built-in container support in .NET 7"
image: "/img/thumbnails/dotnet-container.png"
bigimg: "/img/dotnet7-christmas.jpg"
tags: [Containers,DevOps,Programming,Windows,Kubernetes,.NET]
---

Earlier this year [I wrote]({% post_url 2022-05-21-dotnet-konet %}) about the importance of reducing the time from development to deployment and how CI/CD processes can benefit from an lightweight and fast process that doesn't depend on container runtimes like Docker or maintenance of Dockerfiles. I introduced `konet` to achieve exactly that in the .NET world and just three months later it turned out that the .NET team at Microsoft had [a very similar idea](https://devblogs.microsoft.com/dotnet/announcing-builtin-container-support-for-the-dotnet-sdk/) (and they even refered to `konet`!).

## TL;DR

The recently released .NET 7 SDK has [built-in support for creating container images](https://devblogs.microsoft.com/dotnet/announcing-builtin-container-support-for-the-dotnet-sdk/) without writing Dockerfiles. It is available via an additional package and a separate Publish Profile:

```bash
dotnet new webapi -n mywebapi
cd mywebapi/
dotnet add package Microsoft.NET.Build.Containers
dotnet publish -p:PublishProfile=DefaultContainer

docker run --rm mywebapi:1.0.0
```

Currently the support is limited to creating Linux x64 container images but support for other operating systems and architectures is [in progress](https://github.com/dotnet/sdk-container-builds/issues/91).

If you specify a remote container registry as a target it even works without having Docker installed and without downloading base images, but more on that later.

## Prerequisites

To use the functionality you need the .NET 7 SDK that you can install as follows:
```bash
# Linux
sudo apt-get update && sudo apt-get install -y dotnet-sdk-7.0

# Windows
winget install Microsoft.DotNet.SDK.7
```

You can create an example .NET 7 project with `dotnet new webapi -n mywebapi && cd mywebapi/` or use an existing one. 

## How the built-in container support works

Currently the functionality is distributed via a separate package that you need to install to your project. This `Microsoft.NET.Build.Containers` package infers some information for the target container image like the base image and it's version as well as the target container registry and repository.

After installing it you can create the container image by specifying `DefaultContainer` as the publish profile.
```bash
dotnet add package Microsoft.NET.Build.Containers

# you need to add "-r linux-x64" if you're on a different OS or arch
dotnet publish -p:PublishProfile=DefaultContainer
```

In the background the binaries created by the publish command are packed into a tarball to create a new image layer with a reference to a base image. By default this creates an image based on either `mcr.microsoft.com/dotnet/aspnet` for ASP.NET Core apps or `mcr.microsoft.com/dotnet/runtime` for others. The resulting image is named like the assembly (e.g. `mywebapi:1.0.0`) and is imported into the local Docker daemon.

Docker is no hard dependency, you can also publish directly to remote registries without downloading base images or having Docker installed by specifying the registry (and optionally the image name) during the publish with two additional properties:
```bash
dotnet publish -p:PublishProfile=DefaultContainer -p:ContainerRegistry=myregistry.io -p:ContainerImageName=lippertmarkus/mywebapi
```

With that the binary tarball layer is pushed directly to the registry and the according manifest and tag are created. This is great for CI/CD scenarios with limited access to container runtimes and the need for fast builds.

To make the images even smaller you can publish your apps as self-contained packages by adding the following properties:

```bash
dotnet publish -p:PublishProfile=DefaultContainer -p:PublishSingleFile=true -p:SelfContained=true -p:PublishReadyToRun=true 
```

Through those parameters the image creation will automatically use the smaller `mcr.microsoft.com/dotnet/runtime-deps` image as a base. You can of course also add all those parameters to the `*.csproj` file inside the `Project.PropertyGroup` tag so that you don't need to always specify them.

## Limitations

Like mentioned before, currently the functionality is limited to creating Linux x64 images. Support for other OSs and architectures is in progress. 

Currently also not all container registries are supported. Docker Hub and the GitHub Package Registry are currently not working. Please consult the [docs](https://github.com/dotnet/sdk-container-builds/blob/main/docs/RegistryAuthentication.md) for more information on the supported registries and the authentication.

With all the performance benefits of this approach, it also comes with the downside that you're not able to execute `RUN` commands during container image builds. You can work around that by running commands outside of the build and include resulting artifacts into your project or for static dependencies just create your own base image with a Dockerfile once and use that image by setting the `ContainerBaseImage` property.

## There's more

You can also customize the tag, working directory, ports, labels, environment variables, entrypoint and arguments of your image by [setting the according properties](https://github.com/dotnet/sdk-container-builds/blob/main/docs/ContainerCustomization.md).

Read more on the built-in container support in .NET 7 here:
- [.NET 7 announcement](https://devblogs.microsoft.com/dotnet/announcing-dotnet-7/#built-in-container-support)
- [Container support announcement](https://devblogs.microsoft.com/dotnet/announcing-builtin-container-support-for-the-dotnet-sdk/)
- [GitHub Repository for issues and upcoming features](https://github.com/dotnet/sdk-container-builds)
