---
title: "Building Windows images with Docker running in a HostProcess container on containerd on Kubernetes"
image: "/img/thumbnails/k8s-dockercont-win.png"
bigimg: "/img/containers.jpg"
tags: [Containers,Windows,Docker,Kubernetes,Azure]
---

As announced earlier this year, [dockershim will be removed](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/dockershim-deprecation-and-aks/ba-p/3055902) with the upcoming Kubernetes 1.24 release. On AKS, Windows node pools already use containerd as the default runtime for Kubernetes v1.23 and above.

The removal of the dockershim absolutely makes sense as explained in detail [on the Kubernetes blog](https://kubernetes.io/blog/2022/02/17/dockershim-faq/). While you could continue using Docker as a container runtime via the CRI, many Cloud Providers will switch to containerd for Windows nodes and won't support Docker anymore. For most use cases this shouldn't be a problem as long as you don't use the Docker socket.

But if you want to build Windows container images without limitations, the only option at the moment is to use Docker as the [BuildKit support is not ready yet](https://github.com/microsoft/Windows-Containers/issues/34). So if we still want to use Docker to build Windows images on Kubernetes although the cluster is using containerd as the container runtime we need to get creative with HostProcess containers.

## TL;DR

Whenever you can, I recommend to switch to other options for building Windows container images in a cluster like running [BuildKit on a Linux node]({% post_url 2021-11-30-win-multiarch-img-lin %}) or [using crane]({% post_url 2022-03-30-speed-image-builds-crane %}) on a Windows or Linux node. Those other options are more secure, but have a few limitations, e.g. you can't use build-time commands like `RUN` instructions. I explained some tips to work around that in a [previous post]({% post_url 2021-11-30-win-multiarch-img-lin %}#conclusion).

If you can't work around those limitations you can run the Docker Daemon in a [HostProcess container]({% post_url 2021-11-05-k8s-win22-hostprocess %}) next to the containerd runtime. On every node which runs that HostProcess container you can run Pods mounting the Docker socket like you're used to and use it to e.g. build Windows container images:

1. **Run the Docker Daemon as HostProcess container via a DaemonSet**
    ```yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: dockerd
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: dockerd
      template:
        metadata:
          labels:
            app: dockerd
        spec:
          containers:
          - name: dockerd
            image: lippertmarkus/docker:v20.10.14-1809
          securityContext:
            windowsOptions:
              hostProcess: true
              runAsUserName: "NT AUTHORITY\\SYSTEM"
          hostNetwork: true
          nodeSelector:
            kubernetes.io/os: windows
            # limit where to run this HostProcess container to reduce the attack surface, e.g. limit to one node pool
            agentpool: win1
    ```

2. **Build a Windows container image with Docker via the mounted Docker socket**
    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: docker-build-example
    spec:
      template:
        spec:
          containers:
          - name: docker
            image: lippertmarkus/docker:v20.10.14-1809
            command: ["cmd", "/c"]
            args: ["(echo FROM mcr.microsoft.com/windows/nanoserver:1809 & echo RUN echo helloworld ) | docker build -t test -"]
            volumeMounts:
            - mountPath: \\.\pipe\docker_engine
              name: dockersock
          securityContext:
            windowsOptions:
              runAsUserName: "ContainerAdministrator"
          restartPolicy: Never
          volumes:
          - name: dockersock
            hostPath:
              path: \\.\pipe\docker_engine
              type: null
          nodeSelector:
            # needs to be identical to the DaemonSet
            kubernetes.io/os: windows
            agentpool: win1
      backoffLimit: 2
    ```

3. **Check that it worked**
    ```
    > kubectl logs job/docker-build-example

    Sending build context to Docker daemon  2.048kB
    Step 1/2 : FROM mcr.microsoft.com/windows/nanoserver:1809
    1809: Pulling from windows/nanoserver
    6fc97003d8b7: Already exists
    Digest: sha256:62a8d022600141cd93d7e74cb190de58c9ad273ca238424028af88ad46495ca7
    Status: Downloaded newer image for mcr.microsoft.com/windows/nanoserver:1809
    ---> ebef5512683b
    Step 2/2 : RUN echo helloworld
    ---> Running in fa8af9246ee0
    helloworld
    Removing intermediate container fa8af9246ee0
    ---> e67a08395738
    Successfully built e67a08395738
    Successfully tagged test:latest
    ```

Read on to get more details.

## Options for building (Windows) container images

Here's an brief overview on the tools often used to build container images along with their limitations:

| Image Builder    | Can create Windows images | Runs on           | Limitations                                  |
|------------------|---------------------------|-------------------|----------------------------------------------|
| Buildah          | ❌                        | Linux only        |                                              |
| Kaniko           | ❌                        | Linux only        |                                              |
| img              | ❌                        | Linux only        | unmaintained, mainly just a CLI for BuildKit |
| BuildKit         | ✔️                        | Linux only        | no `RUN` instructions                        |
| crane            | ✔️                        | Linux and Windows | no build-time commands                       |
| Docker           | ✔️                        | Linux and Windows | unsecure when running in-cluster             |


While there are quite a few options for building Linux container images, the only option for building Windows images without limitations currently is Docker. In my [FOSDEM talk early 2022](https://www.youtube.com/watch?v=xsUYyiaTmZk) and in previous posts I showed that it's sometimes preferable to e.g. use [BuildKit]({% post_url 2021-11-30-win-multiarch-img-lin %}) on Linux or [crane]({% post_url 2022-03-30-speed-image-builds-crane %}) to increase the speed when building (multiarch) Windows images as long as the limitations are not a problem for you. I also gave some [tips]({% post_url 2021-11-30-win-multiarch-img-lin %}#conclusion) to work around those limitations.

If you can't live with those limitations and don't want to wait [until BuildKit supports building Windows images](https://github.com/microsoft/Windows-Containers/issues/34) there's another option. Now with [HostProcess containers]({% post_url 2021-11-05-k8s-win22-hostprocess %}) graduating to Beta with Kubernetes 1.23 using Docker as a third, but more unsecure option got easier. Also before HostProcess containers you could just run the Docker daemon next to containerd, but using HostProcess containers is of course way more elegant than adapting VM images or permanently installing Docker on the host.


## Running the Docker daemon in a HostProcess container

Like explained in a [previous post]({% post_url 2021-11-05-k8s-win22-hostprocess %}) HostProcess containers allow to run applications and access files on the container host. This is not only useful for provisioning things like drivers, networking or storage but also for running other privileged processes that need to be executed on the host. 

To run a HostProcess container you need to set the `securityContext` and `hostNetwork` properties accordingly. This way we can run the Docker daemon as a DaemonSet:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dockerd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dockerd
  template:
    metadata:
      labels:
        app: dockerd
    spec:
      containers:
      - name: dockerd
        image: lippertmarkus/docker:v20.10.14-1809
      securityContext:
        windowsOptions:
          hostProcess: true
          runAsUserName: "NT AUTHORITY\\SYSTEM"
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: windows
        # limit where to run this HostProcess container to reduce the attack surface, e.g. limit to one node pool
        agentpool: win1
```

I recommend limiting where this container runs with the `nodeSelector`, as Windows HostProcess containers can be a security risk if they are abused - similar to privileged containers on Linux. 


## Using the Docker socket from another Pod

As the Docker daemon now runs on all nodes selected by the `nodeSelector` we can schedule Pods to mount and use the exposed Docker socket.

One usage example is to use the socket for building Windows container images. We can again use the same image but this time use the Docker CLI for building an Windows image instead of running the daemon. As we mounted the socket via the volumes, the Docker CLI can connect to the daemon running on the host and execute the build process we specified:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: docker-build-example
spec:
  template:
    spec:
      containers:
      - name: docker
        image: lippertmarkus/docker:v20.10.14-1809
        command: ["cmd", "/c"]
        args: ["(echo FROM mcr.microsoft.com/windows/nanoserver:1809 & echo RUN echo helloworld ) | docker build -t test -"]
        volumeMounts:
        - mountPath: \\.\pipe\docker_engine
          name: dockersock
      securityContext:
        windowsOptions:
          runAsUserName: "ContainerAdministrator"
      restartPolicy: Never
      volumes:
      - name: dockersock
        hostPath:
          path: \\.\pipe\docker_engine
          type: null
      nodeSelector:
        # needs to be identical to the DaemonSet
        kubernetes.io/os: windows
        agentpool: win1
  backoffLimit: 2
```

The logs show that the Docker CLI was able to connect to the daemon and build the image successfully:
```
> kubectl logs job/docker-build-example

Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM mcr.microsoft.com/windows/nanoserver:1809
1809: Pulling from windows/nanoserver
6fc97003d8b7: Already exists
Digest: sha256:62a8d022600141cd93d7e74cb190de58c9ad273ca238424028af88ad46495ca7
Status: Downloaded newer image for mcr.microsoft.com/windows/nanoserver:1809
---> ebef5512683b
Step 2/2 : RUN echo helloworld
---> Running in fa8af9246ee0
helloworld
Removing intermediate container fa8af9246ee0
---> e67a08395738
Successfully built e67a08395738
Successfully tagged test:latest
```

In a real scenario you would likely mount registry credentials as well and use a script to not only build but also push the built image to a registry.


## Conclusion

There are many reasons why you may want to build your Windows container images on Kubernetes instead of going through the tedious process of setting up and managing separate build VMs or even autoscale them.

Running the Docker daemon next to another container runtime can be an option for achieving that if using Buildkit on Linux or crane isn't viable for building your application on Kubernetes.
