---
title: "Getting started with Windows HostProcess Containers in Kubernetes"
image: "/img/thumbnails/k8s-win-key.png"
bigimg: "/img/lock.jpg"
tags: [Containers,Kubernetes,Windows]
---

Kubernetes v1.22+ together with containerd v1.6+ [introduced HostProcess containers](https://kubernetes.io/blog/2021/08/16/windows-hostprocess-containers/) for Windows nodes as an alpha feature. Like priviledged Linux containers this allows for many management scenarios like driver, networking and storage provisioning where host access is required. Running proxy tools like [`wins`](https://github.com/rancher/wins/) or [`csi-proxy`](https://github.com/kubernetes-csi/csi-proxy) on the host is now no longer needed. 

I'll describe how you can set up a cluster with HostProcess container support by yourself before going into the technical aspects. If you don't want to try it out yourself, feel free to directly jump to the [introduction of HostProcess containers](#intro-to-windows-hostprocess-containers).

## Setting up a cluster with HostProcess Container support

I created a [`Vagrantfile`](https://github.com/lippertmarkus/vagrant-k8s-win-hostprocess) for deploying a two-node cluster with a Linux controlplane and a Windows Server 2022 worker node with Windows HostProcess containers enabled. [Calico](https://www.tigera.io/project-calico/) is used for networking. The Container Network Interface (CNI) configuration, Calico itself and `kube-proxy` are deployed via [HostProcess pods](https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/hostprocess) to the Windows nodes, which makes the setup very simple.

Have a look at the [repository](https://github.com/lippertmarkus/vagrant-k8s-win-hostprocess) for a detailed description on how to set up the cluster with Vagrant. To summarize, you need to:
1. Make sure Vagrant and Hyper-V are installed and you have created a virtual external switch connected to your main network with DHCP.
1. Verify that the `podSubnet` and `serviceSubnet` within [`setup-scripts/kubeadm-config.yml`](https://github.com/lippertmarkus/vagrant-k8s-win-hostprocess/blob/main/setup-scripts/kubeadm-config.yml) do not overlap with your main network or set those as well as `clusterDNS` accordingly.
1. Run `vagrant up` to create the cluster and select your virtual external switch and enter your admin user credentials while provisioning.
1. After provisioning execute `$env:KUBECONFIG=(Get-Item .\share\kubeconfig).FullName` to access your newly created cluster and wait for everything to settle.

Alternatively you could also use the [Kubernetes Cluster API](https://cluster-api.sigs.k8s.io/) with the recently added [Cluster Template](https://github.com/kubernetes-sigs/cluster-api-provider-azure/blob/main/templates/cluster-template-machinepool-windows-containerd.yaml) to create a cluster with Windows nodes, containerd and HostProcess Container support on Azure. If you go that route, make sure to manually deploy the addons for [Calico and kube-proxy on Windows](https://github.com/kubernetes-sigs/cluster-api-provider-azure/tree/main/templates/addons/windows/calico) after provisioning.

## Intro to Windows HostProcess Containers

Windows HostProcess Containers run directly on the host and have neither filesystem nor networking or process isolation. They are sharing the host's filesystem, process and networking space. Under the hood HostProcess containers are using Windows Job Objects instead of the server silos used by normal Windows containers. See [this diagram](https://kubernetes.io/blog/2021/08/16/windows-hostprocess-containers/#how-does-it-work) for an overview of the overall architecture differences. Because of this architecture there are further special considerations when it comes to running HostProcess containers:

- The version of the base image does not need to match the host OS version because HostProcess containers directly use the host's kernel.
- Currently there's no TTY support when exec into HostProcess containers
- HostProcess pods currently can only consist of HostProcess containers. Standard Windows Server containers are not supported in the same pod. 
- Resource limits for disk, memory or CPU count work the same as for normal containers.
- Mounting named pipes is not supported. They can instead be accessed directly via their path on the host.

The Pod spec for a HostProcess containers needs a few configurations to be set. A minimal example would look like:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test
spec:
  containers:
  - name: test
    image: mcr.microsoft.com/windows/servercore:ltsc2022
    command: [powershell, -command]
    args: [Get-ChildItem, C:\]
  securityContext:
    windowsOptions:
      hostProcess: true
      runAsUserName: "NT AUTHORITY\\SYSTEM"
  hostNetwork: true
  nodeSelector:
    "kubernetes.io/os": windows
```

Note that you can run the Pod as `SYSTEM`, `Local Service` or `Network Service` user depending on which [degree of privileges you need](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/#choosing-a-user-account). 

Now let's have a look at a few things which are different to normal pods.

## Experimenting with Windows HostProcess Containers

First of all you can spot that the pod is using the host's filesystem at it's root:
```powershell
# args: [Get-ChildItem, C:\]

...
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         11/4/2021   7:31 PM                C
d-----         11/3/2021   6:32 PM                CalicoWindows
d-----         10/5/2021   2:17 PM                chef
d-----         11/3/2021   6:28 PM                etc
d-----         11/3/2021   6:28 PM                k
...
```

However, each HostProcess pod still gets its own volume with the image content as a clean workspace. The path to this volume gets set in `$CONTAINER_SANDBOX_MOUNT_POINT`. There you'll find the directory structure you're used to:
```powershell
# args: [Get-ChildItem, $env:CONTAINER_SANDBOX_MOUNT_POINT]

   Directory: C:\C\d6a326de490853457f55c05f10a9c4f7ccbb88c6356c7480c896589e1afe78bc

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         11/4/2021   7:36 PM                dev
d-r---         10/7/2021   6:35 PM                Program Files
d-----         10/7/2021  11:23 AM                Program Files (x86)
d-r---         10/7/2021  11:40 AM                Users
d-----         11/4/2021   7:36 PM                var
d-----         10/7/2021  11:40 AM                Windows
-a----          5/8/2021  10:26 AM           5510 License.txt
```

Because of that, there are no special considerations when creating images for HostProcess containers. Volumes you may specified in the Pod spec are also mounted relative to the `$CONTAINER_SANDBOX_MOUNT_POINT`. The service account tokens can be found within `$CONTAINER_SANDBOX_MOUNT_POINT\var\run\secrets\kubernetes.io\serviceaccount\`.

Due to the shared networking space the Pod obviously also uses the IP address of the host and every service running inside your HostProcess pod would be reachable via this IP:

```powershell
# args: [ipconfig]

Ethernet adapter vEthernet (Ethernet):
...
   IPv4 Address. . . . . . . . . . . : 10.1.0.137
```

The shared host networking space also means that cluster DNS is not working for HostProcess containers:
```powershell
# args: [curl.exe, http://my-nginx]

...
Could not resolve host: my-nginx
```

Lastly you can also tell that HostProcess containers share the process space with the host by looking at the process list:
```powershell
# args: [Get-Process]

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    278      17    30008      41572       5.13   9128   0 calico-node
...
```

That's basically it. If you want to have a look at Calico, Flannel or `kube-proxy` as real-world examples for HostProcess pods, you'll find them in the [HostProcess examples of SIG Windows](https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/hostprocess).

## Conclusion and Future

Running Windows HostProcess pods is not much different from running normal Windows pods. The behaviour of HostProcess Containers is mostly like you would expect when sharing the host's filesystem, process and networking space. 

Nevertheless Windows HostProcess pods will greatly simplify management and administration of your mixed Kubernetes Clusters. Please keep in mind that HostProcess Containers are still in alpha and may change in the future. With Kubernetes v1.23 HostProcess Containers will move to beta. [Things planned](https://github.com/marosset/enhancements/blob/5586e1fbb9c484ce897889864bfde466fe458c28/keps/sig-windows/1981-windows-privileged-container-support/README.md#design-details) for beta or GA include:
- Support for running as any user that's available on the host
- Filesystem layout may change again to present the filesystem similar to normal Windows pods to easier access files in the container filesystem from Scripts or client libraries
- Support for mounting Unix domain sockets
- Running Container Storage Interface (CSI)-proxy as a daemon set
- Support for TTY when exec into a container

**Update 05/02/2023:**
- Please consider the [current Kubernetes docs](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/) about HostProcess containers
- There's now also a [minimal base image](https://github.com/microsoft/windows-host-process-containers-base-image#overview) specifically designed for HostProcess containers.