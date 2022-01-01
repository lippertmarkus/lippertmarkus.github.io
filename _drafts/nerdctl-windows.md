
networking geht aktuell noch nicht

https://github.com/containerd/nerdctl/blob/master/hack/configure-windows-ci.ps1



```powershell
Enable-WindowsOptionalFeature -FeatureName Containers -Online -NoRestart

Restart-Computer

$netAdapterName = "Ethernet"  # see get-netadapter

function CalculateSubNet {
    param (
        [string]$gateway,
        [int]$prefixLength
    )
    $len = $prefixLength
    $parts = $gateway.Split('.')
    $result = @()
    for ($i = 0; $i -le 3; $i++) {
        if ($len -ge 8) {
            $mask = 255

        }
        elseif ($len -gt 0) {
            $mask = ((256 - 2 * (8 - $len)))
        }
        else {
            $mask = 0
        }
        $len -= 8
        $result += ([int]$parts[$i] -band $mask)
    }

    $subnetIp = [string]::Join('.', $result)
    $cidr = 32 - $prefixLength
    return "${subnetIp}/$cidr"
}


# install containerd
$Version="1.6.0-beta.3"
#$Version="1.5.7"
curl.exe -L https://github.com/containerd/containerd/releases/download/v$Version/containerd-$Version-windows-amd64.tar.gz -o containerd-windows-amd64.tar.gz
tar xvf containerd-windows-amd64.tar.gz
mkdir -force "$Env:ProgramFiles\containerd"
mv ./bin/* "$Env:ProgramFiles\containerd"
& $Env:ProgramFiles\containerd\containerd.exe config default | Out-File "$Env:ProgramFiles\containerd\config.toml" -Encoding ascii
& $Env:ProgramFiles\containerd\containerd.exe --register-service
Start-Service containerd

#configure cni
mkdir -force "$Env:ProgramFiles\containerd\cni\bin"
mkdir -force "$Env:ProgramFiles\containerd\cni\conf"
curl.exe -LO https://github.com/microsoft/windows-container-networking/releases/download/v0.2.0/windows-container-networking-cni-amd64-v0.2.0.zip
Expand-Archive windows-container-networking-cni-amd64-v0.2.0.zip -DestinationPath "$Env:ProgramFiles\containerd\cni\bin" -Force

curl.exe -LO https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1
ipmo ./hns.psm1

$gateway = (Get-NetIPAddress -InterfaceAlias $netAdapterName -AddressFamily IPv4).IPAddress
$prefixLength = (Get-NetIPAddress -InterfaceAlias $netAdapterName -AddressFamily IPv4).PrefixLength
$subnet = CalculateSubNet -gateway $gateway -prefixLength $prefixLength

New-HNSNetwork -Type Nat -Name "nat"
# TODO get usbnet and gateway via get-hsnnetwork

@"
{
    "cniVersion": "0.2.0",
    "name": "nat",
    "type": "nat",
    "master": "Ethernet",
    "ipam": {
        "subnet": "$subnet",
        "routes": [
            {
                "gateway": "$gateway"
            }
        ]
    },
    "capabilities": {
        "portMappings": true,
        "dns": true
    }
}
"@ | Set-Content "$Env:ProgramFiles\containerd\cni\conf\0-containerd-nat.conf" -Force

# TODO test with CTR: https://www.jamessturtevant.com/posts/Windows-Containers-on-Windows-10-without-Docker-using-Containerd/

curl.exe -o "nerdctl.tar.gz" -LO "https://github.com/lippertmarkus/nerdctl/releases/download/vtestwin/nerdctl-3b86328-windows-amd64.tar.gz"
tar -xvf nerdctl.tar.gz

.\nerdctl.exe run --rm -it mcr.microsoft.com/windows/nanoserver:ltsc2022-amd64 cmd

mcr.microsoft.com/windows/nanoserver:ltsc2022:                                    resolved       |++++++++++++++++++++++++++++++++++++++|
index-sha256:c093aac93e3771a85832fcf27d21dc5c12751091255a79be5a05d9bfb48c6a73:    done           |++++++++++++++++++++++++++++++++++++++|
manifest-sha256:62461017a50040ca9b91284b2b501f1c49718c5b9675469cb56bb23d15046000: done           |++++++++++++++++++++++++++++++++++++++|
config-sha256:8c7c323428d9fee03fda5b10d20ed8ff33587806c39156efb54973911a33f2f3:   done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:83b9a19f898e6e25b6ee7e787da89582a8528b2defb5682f45364d04b35a278d:    done           |++++++++++++++++++++++++++++++++++++++|
elapsed: 57.4s                                                                    total:  111.7  (1.9 MiB/s)


hello world

```