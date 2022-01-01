Enable-WindowsOptionalFeature -Online -FeatureName Containers
wsl --install
curl.exe -LO "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"
.\vc_redist.x64.exe /install /quiet /norestart
restart-computer

wsl --unregister ubuntu
curl.exe -LO "https://github.com/nullpo-head/wsl-distrod/releases/download/v0.1.4/distrod_wsl_launcher-x86_64.zip"
expand-archive distrod_wsl_launcher-x86_64.zip
.\distrod_wsl_launcher-x86_64\distrod_wsl_launcher-x86_64\distrod_wsl_launcher.exe
=======

sudo apt-get install -y gnupg

create ~/.wslconfig with
[wsl2]
swap=0

(may not needed) change hostname in /etc/wsl.conf
[network]
hostname = mywsl
generateHosts = false

and add to /etc/hosts
127.0.0.1 mywsl


sudo systemctl enable systemd-resolved
sudo mount --make-shared /sys
sudo mount --make-shared /



=============
Windows

modify  instlal-containerd.ps1 and remove feature check

adapt sandbox image in containerd config to
sandbox_image = "docker.io/lippertmarkus/pause:latest"
Restart-Service containerd

TODO 



=====

nach jedem windows restart WSL IP in hosts datei ändern
===
nach jedem WSL restart

lastIp=$(<lastIp.txt)
ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
cd /etc/kubernetes/manifests
sudo sed -i "s/$lastIp/$ip/g" *
echo $ip > ~/lastIp.txt

sudo mount --make-shared /sys
sudo mount --make-shared /










*****************************************
portforward

netsh interface portproxy add v4tov4 listenport=6443 listenaddress=127.0.0.1 connectport=6443 connectaddress=172.20.82.2
bind all to 127.0.0.1 in /etc/kubernetes/manifests