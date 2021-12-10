---
title: "Running Windows and Linux containers without Docker Desktop"
image: "/img/thumbnails/win-lin-docker.png"
bigimg: "/img/ship.jpg"
tags: [Containers,Docker,DevOps,Windows]
---

You certainly already heard about the [licensing changes for Docker Desktop](https://www.docker.com/blog/updating-product-subscriptions/). I think spending some money for that is perfectly fine regarding the value Docker Desktop is providing to you. Those licensing changes however only apply to Docker Desktop. If you don't need all the GUI and plumbing stuff like me and doing everything via `docker run` and `docker compose` anyway, you may don't even need Docker Desktop but can directly run the Docker Daemon and use the CLIs. It's surprisingly easy!

## Windows Containers

Docker provides the standalone Windows binaries for the Docker Daemon as well as the Docker CLI. Those are a bit hidden and not easy to find. You can just download them, put them in your `PATH`, register the Docker Daemon as a service, start it and run your Windows containers like you're used to. For that you need to execute the following PowerShell commands as admin:
```powershell
curl.exe -o docker.zip -LO https://download.docker.com/win/static/stable/x86_64/docker-20.10.8.zip 
Expand-Archive docker.zip -DestinationPath C:\
[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\docker", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
dockerd --register-service
Start-Service docker
docker run hello-world
```

Docker then greets you with *Hello from Docker!*. Now on to the Linux containers.

## Linux Containers

For Linux containers you can install the Docker Daemon in WSL2. Installing WSL is explained [here](https://docs.microsoft.com/en-us/windows/wsl/install) or you can use an already existing Ubuntu distribution. Before you can install Docker you need to [enable systemd with a little hack](https://forum.snapcraft.io/t/running-snaps-on-wsl2-insiders-only-for-now/13033) (**Update** I also had success enabling systemd with [distrod](https://github.com/nullpo-head/wsl-distrod) which seems like a less hacky solution).):
```bash
sudo apt-get update
sudo apt install -yqq fontconfig daemonize
sudo vi /etc/profile.d/00-wsl2-systemd.sh
```

Add the following to the file to start systemd on startup:
```bash
SYSTEMD_PID=$(ps -efw | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')
 
if [ -z "$SYSTEMD_PID" ]; then
   sudo /usr/bin/daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
   SYSTEMD_PID=$(ps -efw | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')
fi
 
if [ -n "$SYSTEMD_PID" ] && [ "$SYSTEMD_PID" != "1" ]; then
    exec sudo /usr/bin/nsenter -t $SYSTEMD_PID -a su - $LOGNAME
fi
```

Now exit and re-enter WSL to have systemd available and install Docker normally like explained [in the docs](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository). Here are the commands: 

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo docker run hello-world
# Hello from Docker!

# Automatically start on startup
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

Now you're ready to run Linux containers as well. As a next step we also would like to run them simultaneously.

## Easily run Windows and Linux containers simultaneously

If you don't want to switch between Windows and WSL when running Windows or Linux containers, you can just expose the Docker Daemon in WSL2 and create a context for it.

In WSL2 change the service config to additionally expose the Docker Daemon on localhost:
```bash
sudo cp /lib/systemd/system/docker.service /etc/systemd/system/
sudo sed -i 's/\ -H\ fd:\/\//\ -H\ fd:\/\/\ -H\ tcp:\/\/127.0.0.1:2375/g' /etc/systemd/system/docker.service
sudo systemctl daemon-reload
sudo systemctl restart docker.service
```

On Windows create a new context for the WSL host via PowerShell:
```powershell
docker context create lin --docker host=tcp://127.0.0.1:2375
```

Now you can easily run Windows and Linux containers simultaneously without switching like in Docker Desktop:
```powershell
> docker ps
CONTAINER ID   IMAGE                                       COMMAND               CREATED         STATUS        PORTS     NAMES
edb2101c52ed   mcr.microsoft.com/windows/nanoserver:1809   "ping -t localhost"   2 seconds ago   Up 1 second             wincontainer

> docker -c lin ps
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS     NAMES
94e165427f9c   nginx     "/docker-entrypoint.…"   4 seconds ago   Up 3 seconds   80/tcp    lincontainer  
```

## Conclusion

You may not even need Docker Desktop if you're a poweruser not using the GUI. Docker Desktop does a lot of plumbing in the background for you but running it by yourself isn't hard either. And sometimes it's also fun to have a bit more insight on what's going on behind the scenes.
