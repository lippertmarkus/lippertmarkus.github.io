- Windows Server 2022

```
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider
Restart-Computer -Force


Install-Module -Name BcContainerHelper -Scope AllUsers


New-Item -Path c:\programdata\bccontainerhelper -ItemType Directory | Out-Null
New-Item -Path C:\programdata\bccontainerhelper\Extensions -ItemType Directory | Out-Null
New-Item -Path c:\bcartifacts.cache -ItemType Directory | Out-Null
Add-MpPreference -ExclusionPath c:\programdata\bccontainerhelper
Add-MpPreference -ExclusionPath c:\bcartifacts.cache
```

TODO mount
"C:\Program Files\WindowsPowerShell\Modules\BcContainerHelper"

docker run --rm -it -v "C:\Program Files\WindowsPowerShell\Modules\BcContainerHelper:C:\Program Files\WindowsPowerShell\Modules\BcContainerHelper" -v "c:\programdata\bccontainerhelper:c:\programdata\bccontainerhelper" -v "c:\bcartifacts.cache:c:\bcartifacts.cache" -v "\\.\pipe\docker_engine:\\.\pipe\docker_engine" mcr.microsoft.com/windows/servercore:ltsc2022 powershell

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install -y docker-cli 7zip.install;

New-BcImage -artifactUrl (Get-BCArtifactUrl -type OnPrem -version 19.2 -country de) -imageName mybcimg

(in docker-agent also docker-cli and bcch installed, mounts c:\programdata\bccontainerhelper	c:\programdata\bccontainerhelper AND f:\bcartifacts.cache	c:\bcartifacts.cache AND \\.\pipe\docker_engine)

in build-agent (https://github.com/cosmoconsult/azdevops-build-agent-image/blob/master/Dockerfile.bcagent, mounts docker-engine and fileshare):
```
choco install -y docker-cli 7zip.install;
# needed?
Install-Module 'bccontainerhelper' -MinimumVersion $env:BCCHVERSION -MaximumVersion $env:BCCHVERSION -Force; 
```