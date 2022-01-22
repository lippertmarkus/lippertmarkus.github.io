---
title: "Directly running Windows containers with containerd from the command line"
image: "/img/thumbnails/win-containerd.png"
bigimg: "/img/engine.jpg"
tags: [Containers, Docker, Kubernetes, Windows] 
---

Did you ever wonder how Kubernetes or Docker is using containerd under the hood to run your Windows containers? Let's skip those abstractions and see how you can use containerd directly to run Windows containers with the `ctr` and the `crictl` CLI. We look on how to set up containerd, the Container Networking Interface and NAT networking on Windows. 

I will also present you the installer I created to automate all that. Why an installer you may ask yourself? While `ctr` and `crictl` are mainly used for debugging container runtimes there eventually will be other more user friendly solutions in the future like [`nerdctl`](https://github.com/containerd/nerdctl/) using containerd directly for running Windows containers locally. As a promising alternative to a full-blown Docker Desktop installation [there should be an easy way](https://github.com/microsoft/Windows-Containers/issues/186#issuecomment-989896985) to install containerd on Windows nodes. 

## TL;DR

I created an installer to help with the set up of containerd on Windows as well as the configuration and networking. After the installation you can use `ctr` and `crictl` to run Windows containers directly via containerd. Here's the quickstart:

```powershell
# Download and run the containerd installer (may needs a restart afterwards)
curl.exe -LO "https://github.com/lippertmarkus/containerd-installer/releases/download/v0.0.3/containerd-installer.exe"
.\containerd-installer.exe

# ctr comes with containerd, we additionally install crictl
curl.exe -o crictl.tgz -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.23.0/crictl-v1.23.0-windows-amd64.tar.gz"
tar -xvf crictl.tgz -C "C:\Program Files\containerd"

# Add ctr and crictl to your path
[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\Program Files\containerd", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

# Pull and run a container with ctr (may use a different tag depending on your host version)
ctr i pull mcr.microsoft.com/windows/nanoserver:1809
ctr run --cni -rm mcr.microsoft.com/windows/nanoserver:1809 test curl.exe https://example.org

# .. and with crictl (see below for pod.json and container.json content)
$env:CONTAINER_RUNTIME_ENDPOINT="npipe:////./pipe/containerd-containerd"
crictl pull mcr.microsoft.com/windows/nanoserver:1809
$POD_ID=(crictl runp .\pod.json)
$CONTAINER_ID=(crictl create $POD_ID .\container.json .\pod.json)
crictl start $CONTAINER_ID
crictl exec $CONTAINER_ID curl.exe https://example.org
```

Read on for the details on what exactly the installer does for you, how the networking is working behind the scenes and what `ctr` and `crictl` can do!

## Details

Before looking into how we can run containers with `ctr` and `crictl` we first need to set those CLIs up along with containerd and networking.

### Setting up containerd, networking and our CLIs

I created the [containerd installer](https://github.com/lippertmarkus/containerd-installer) to simplify the containerd setup for you. Let's see what the installer does in the background:

1. Checks for admin privileges and enables the required Windows features (`Containers`, `Microsoft-Hyper-V`, `Microsoft-Hyper-V-Management-PowerShell`) for running containers. Like the `Enable-WindowsOptionalFeature` PowerShell Cmdlet it uses the [DISM API](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism/dism-api-reference?view=windows-11) for that which works for both Windows Server and Windows Client systems. I used the [Glazier](https://github.com/google/glazier) library for talking to the DISM API and also [helped making that communication more reliable](https://github.com/google/glazier/pull/460).

1. Downloads and extracts [containerd](https://github.com/containerd/containerd/) and creates a default `config.toml` via running `containerd config default`.

1. Downloads and extracts the Container Networking Interface (CNI) [plugins for Windows](https://github.com/microsoft/windows-container-networking) and sets them up in the CNI binary path specified in containerd's `config.toml` (the default is `C:\Program Files\containerd\cni\bin`). We will use the included `nat` plugin to enable basic networking for our containers. A configuration for this NAT plugin is created in a later step.

1. Retrieves an existing NAT network or creates a new one via the Host Networking Service (HNS). Containers will get an IP assigned from this network and will be able to access the internet. For the installer I used the [`hcsshim`](https://github.com/microsoft/hcsshim/) to get or create the network. You could also use the `Get-HnsNetwork` PowerShell Cmdlet to look for an existing network:
    ```powershell
    PS > Get-HnsNetwork | select name, type, subnets

    Name           Type Subnets
    ----           ---- -------
    nat            nat  {@{AdditionalParams=; AddressPrefix=172.29.240.0/20; Flags=0; GatewayAddress=172.29.240.1; ...
    ```
    A new NAT network can be created with `New-HnsNetwork -Name nat -Type nat` with the PowerShell Cmdlet included in the [`hns` PowerShell module](https://github.com/microsoft/SDN/blob/master/Kubernetes/windows/hns.psm1#L148).

1. With the NAT network of the last step, the installer creates a configuration `0-containerd-nat.conf` for the CNI plugin in the CNI config path specified in containerd's `config.toml` (the default is `C:\Program Files\containerd\cni\conf`). The CNI configuration looks like this with the subnet and the gateway address from the last step:
    ```json
    {
        "cniVersion": "0.2.0",
        "name": "nat",
        "type": "nat",
        "master": "Ethernet",
        "ipam": {
            "subnet": "172.29.240.0/20",
            "routes": [
                {
                    "gateway": "172.29.240.1"
                }
            ]
        },
        "capabilities": {
            "portMappings": true,
            "dns": true
        }
    }
    ```
    With that configuration and the NAT plugin installed, containerd now knows how to set up the networking for our containers

1. `ctr`, a CLI for testing containerd functions is shipped with containerd. It is currently using some hard-coded paths for the CNI configuration and plugins that differ from the one in the `config.toml`. The installer therefore also creates symlinks for `/etc/cni/net.d` and `/opt/cni/bin` to link to the CNI plugin and configuration paths mentioned above. Manually this could be achieved with `mklink /D`.

1. Registers containerd as a service via `containerd --register-service` and starts it via the Service Manager. For the latter I also used [Glazier](https://github.com/google/glazier) for the installer, which has a [helper function](https://github.com/google/glazier/blob/master/go/helpers/helpers.go#L367-L380) for connecting to the Service Manager and starting a specified service.

With that we are now having containerd running. While `ctr` already comes with it, we additionally install `crictl`:
```powershell
curl.exe -o crictl.tgz -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.23.0/crictl-v1.23.0-windows-amd64.tar.gz"
tar -xvf crictl.tgz -C "C:\Program Files\containerd"
```

To execute commands with `ctr` and `crictl` we also make them available in our path:

```powershell
[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\Program Files\containerd", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
```

Now let's see how we can run containers with those CLIs.

### Running and inspecting containers and networking with `ctr`

`ctr` is a debugging tool specific for containerd and ships with it. It has some basic commands for managing images and containers. Let's try them out by first pulling an image and running and attaching to a Windows container:

```powershell
# may use a different tag depending on your host version
ctr i pull mcr.microsoft.com/windows/nanoserver:1809
ctr run --cni -rm -t mcr.microsoft.com/windows/nanoserver:1809 test cmd
```

Within the container we can verify that the HNS network we created before is used and we got an IP from the subnet we set up above. Also the internet access is working:
```
C:\> ipconfig

Windows IP Configuration

Ethernet adapter vEthernet (default-test_nat):
   ...
   IPv4 Address. . . . . . . . . . . : 172.29.248.143
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . : 172.29.240.1


C:\> ping -n 1 1.1.1.1

Pinging 1.1.1.1 with 32 bytes of data:
Reply from 1.1.1.1: bytes=32 time=1ms TTL=56
...
```

Outside the container we can see that our created container is running via the containerd shim:
```
PS C:\> hcsdiag list
test
    Windows Server Container,   Running,   , containerd-shim-runhcs-v1.exe
```

A new HNS endpoint has been created for this container matching the network we saw inside the container:
```powershell
PS C:\> Get-HnsEndpoint | select name, virtualnetworkname, type, ipaddress

Name              VirtualNetworkName  Type  IPAddress
----              ------------------  ----  ---------
default-test_nat  nat                 nat   172.29.248.143
```

Note that networking only works for Windows Containers with `ctr` in containerd v1.6.0-rc.1 or newer. Before that version, `ctr` had no CNI support for Windows containers but with some help I was able to [contribute](https://github.com/containerd/containerd/pull/6304) to make it working for Windows Containers as well.

Next to running containers you can also manage images, namespaces and a lot more with `ctr`. Check out the help for `ctr` for a list of commands. Let's see how it works for `crictl`.

### Running containers with `crictl`

`crictl` is a CLI for debugging container runtimes compatible with the Container Runtime Interface (CRI) and can also be used with other runtimes than containerd. It works similarly like `ctr` but like Kubernetes it uses pods as abstractions for one or more containers. Running containers with it is a bit more complicated as we first need to define how our pod and our container should look like with the following two files:

`pod.json`:
```json
{
  "metadata": {
    "name": "mycont-sandbox",
    "namespace": "default",
    "uid": "hdishd83djaidwnduwk28basb"
  }
}
```

`container.json`:
```json
{
  "metadata": {
      "name": "mycont"
  },
  "image":{
      "image": "mcr.microsoft.com/windows/nanoserver:1809"
  },
  "command": ["cmd", "/c", "ping -t 127.0.0.1"]
}
```

With that we can now pull the image and run our container as well:
```powershell
$env:CONTAINER_RUNTIME_ENDPOINT="npipe:////./pipe/containerd-containerd"
# may use a different tag depending on your host version
crictl pull mcr.microsoft.com/windows/nanoserver:1809
$POD_ID=(crictl runp .\pod.json)
$CONTAINER_ID=(crictl create $POD_ID .\container.json .\pod.json)
crictl start $CONTAINER_ID
```

Again we can verify that our NAT network is used:
```
PS C:\> crictl exec $CONTAINER_ID ipconfig

Windows IP Configuration

Ethernet adapter vEthernet (d9e45f656c2114fc51dc61653ffd3731c17d4070edb30117841c1da1774e0a18_nat):
   ...
   IPv4 Address. . . . . . . . . . . : 172.29.249.47
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . : 172.29.240.1


PS C:\> crictl exec $CONTAINER_ID ping -n 1 1.1.1.1

Pinging 1.1.1.1 with 32 bytes of data:
Reply from 1.1.1.1: bytes=32 time=1ms TTL=56
...
```

Like before, running `Get-HnsEndpoint` would show a single endpoint for our container. With `hcsdiag` we however see that we now have two containers running, one for the pod and one for the container:
```
PS C:\> hcsdiag list
918820bba16d6d710c2cade0fe6f9f0b73eeb1efd81177fb058ee8741a80ef2a
    Windows Server Container,   Running,   , containerd-shim-runhcs-v1.exe

d9e45f656c2114fc51dc61653ffd3731c17d4070edb30117841c1da1774e0a18
    Windows Server Container,   Running,   , containerd-shim-runhcs-v1.exe
```

Apart from simply pulling images and running containers `crictl` can do a lot more. Check out the [Kubernetes documentation](https://kubernetes.io/docs/tasks/debug-application-cluster/crictl/) covering various use cases and also providing a mapping from docker CLI commands to `crictl` commands.


## There's more

Setting up a container runtime like containerd along with networking and using CLIs like `ctr` and `crictl` helps to understand some of the lower-level concepts of Windows containers and pods.

As those CLIs are meant for debugging and testing, they are surely not comparable to the usability you are used to with CLIs like Docker. But with Windows container support getting better in the future for other CLIs like [`nerdctl`](https://github.com/containerd/nerdctl/), it is always a good idea to know how you can set things up to use them. `nerdctl` has a Docker-compatible interface and already can pull Windows containers images, run Windows containers and exec into them. But it's still in very early days as [networking](https://github.com/containerd/nerdctl/issues/559) as well as [many other features](https://github.com/containerd/nerdctl#command-reference) are not implemented for Windows yet.

Using the installer is not only handy to automate the setup needed for understanding the lower-level concepts and using CLIs like `nerdctl` in the future but also when you want to for example prepare your Windows Kubernetes nodes yourself for the learning experience. Maybe my installer also [helps Microsoft as a starting point](https://github.com/microsoft/Windows-Containers/issues/186#issuecomment-990126055) to provide an official installer for containerd.