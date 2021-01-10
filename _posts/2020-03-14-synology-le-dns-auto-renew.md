---
title: "Automatically renew Let's Encrypt certificates on Synology NAS using DNS-01 challenge"
image: "img/thumbnails/lock-icon.png"
bigimg: "/img/synology-nas.jpg"
tags: [Synology,Programming]
---

Let's Encrypt offers free certificates for securing your website with TLS. It uses the ACME protocol to fully automate the certification process. There are many [different clients](https://letsencrypt.org/docs/client-options/) supporting the ACME protocol and also Synology provides a client to automatically issue and renew Let's Encrypt certificates via DSM for your NAS.

Currently DSM only supports the HTTP-01 challenge type, where a file is placed on your web server and is retrieved by Let's Encrypt for verification. Like the [documentation](https://letsencrypt.org/docs/challenge-types/) describes, this challenge type has a few drawbacks. If your NAS is not connected to the Internet, you have multiple web servers, you don't want to/can't open port 80 or you want to use wildcard certificates, you would need to use the DNS-01 challenge instead. With the DNS-01 challenge you create a TXT DNS record for your domain for the verification process. 

While DSM doesn't natively support DNS-01, it can be automated too if your DNS provider provides an API. DSM makes it a bit tricky as our certificate is placed in multiple directories for multiple different applications. Instead of trying to identify all those locations, the described way uses the DSM web API, which handles all of that automatically. 
 
## TL;DR

Go straight to the [usage](#usage).

## Details

While there exist many ACME clients for DNS-01 validation, [`acme.sh`](https://github.com/acmesh-official/acme.sh) is a very popular one without external dependencies and therefore perfect for the use on your Synology NAS. Renewing your certificate using the [DNS-01 challenge](https://letsencrypt.org/docs/challenge-types/) can only be automated if your DNS provider offers API access. You can check the list of supported DNS providers in the [`acme.sh` wiki](https://github.com/acmesh-official/acme.sh/wiki/dnsapi).

While researching I found [a wiki entry (old way, don't use it!)](https://github.com/acmesh-official/acme.sh/wiki/Synology-NAS-Guide/865933612054fd68960a18f889b40ef16a80af1f#configuring-certificate-renewal) describing the manual renewal and replacement of all copies of the certificate of all apps. I worked on an improved [python script (another old way, don't use it!)](https://github.com/lippertmarkus/synology-le-dns-auto-renew) as a replacement and was already finished when I found that a few days before [tresni](https://github.com/tresni) created a [deployment hook for Synology DSM](https://github.com/acmesh-official/acme.sh/pull/2369), which provides an even more elegant solution!

It uses the DSM web API for importing the certificate. This way you don't need to manually find all the directories with copies of your certificate as DSM handles everything for you, including restarting applications when needed.

As I'm using two-factor authentication on my NAS and didn't want to disable it to use the deployment hook I created a [pull request](https://github.com/acmesh-official/acme.sh/pull/2782), which adds support for it.

## Usage

While you could use any administration user, I suggest you create a new one via `Control Panel ➡ User ➡ Create`. Use a strong password, add the user to the `administrators` group and deny access to all shared folders and applications. I'm using `mycertadmin` in the following.

### One-time setup

Temporarily enable SSH via `Control Panel ➡ Terminal & SNMP ➡ Enable SSH service`. Login via SSH with your newly created admin user.

Next we download `acme.sh` to `/usr/local/share/acme.sh/`:
```bash
wget -O /tmp/acme.sh.zip https://github.com/acmesh-official/acme.sh/archive/master.zip
sudo 7z x -o/usr/local/share /tmp/acme.sh.zip
sudo mv /usr/local/share/acme.sh-master/ /usr/local/share/acme.sh
sudo chown -R mycertadmin /usr/local/share/acme.sh/  # use your newly created admin user
```

The first issuance and deployment is done manually. `acme.sh` stores all your settings and credentials, so that the renewal can happen automatically in the future. Have a look in the [`acme.sh` wiki](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) to find out the parameters you need to set for your DNS provider:
```bash
cd /usr/local/share/acme.sh
# set environment variables for your DNS provider and your used DNS API
./acme.sh --issue -d "*.example.com" --dns dns_cf --home $PWD

# set deployment options, see https://github.com/acmesh-official/acme.sh/wiki/deployhooks#20-deploy-the-cert-into-synology-dsm
#export SYNO_Scheme="http"  # Can be set to HTTPS, defaults to HTTP
#export SYNO_Host="localhost"  # Specify if not using on localhost
#export SYNO_Port="5000"  # Port of DSM WebUI, defaults to 5000 for HTTP and 5001 for HTTPS
export SYNO_Username="mycertadmin"
export SYNO_Password="MyPassw0rd!"
export SYNO_Certificate="mydesc"  # description text shown in Control Panel ➡ Security ➡ Certificate
export SYNO_Create=1  # create certificate if it doesn't exist
#export SYNO_DID=aSdF...  # device id to skip two-factor-authentication, see bonus section below for an explanation
./acme.sh -d "*.example.com" --deploy --deploy-hook synology_dsm --home $PWD
```

If everything was successful, you should now see your certificate in DSM under `Control Panel ➡ Security ➡ Certificate` and can configure it to be used by your applications. Your settings are stored by `acme.sh` so the renewal can be automated in the next step.

### Setup a recurring task for renewal

Although `acme.sh` can set up a cronjob for you automatically, you shouldn't use it with your Synology NAS as the DSM security advisor will give you a critical warning. Instead, we'll use the built-in task scheduler:

1. `Control Panel ➡ Task Scheduler`
2. `Create ➡ Scheduled Task ➡ User-defined script`
3. Fill out the necessary information:
    - General: Give the task a name and choose your newly created admin user
    - Schedule: e.g. monthly at 4:00 am
    - Task Settings: maybe set up an email notification and use one of the following scripts:

```bash
# Renew single certificate
/usr/local/share/acme.sh/acme.sh --renew -d "*.example.com" --home /usr/local/share/acme.sh

# Renew all certificates issued via acme.sh
/usr/local/share/acme.sh/acme.sh --cron --home /usr/local/share/acme.sh
```

This recurring task automatically renews your certificate and deploys it to your Synology NAS using the stored settings of the previous step.

### Bonus: Deploy with enabled two-factor authentication

Like mentioned before, I'm using two-factor authentication on my NAS and didn't want to disable it to use the deployment hook. I created a [pull request](https://github.com/acmesh-official/acme.sh/pull/2782), which adds support for supplying a known device ID while authenticating, so that DSM doesn't ask for an OTP code.

To use the device ID you can follow these steps:
1. Open DSM inside an incognito tab and login with your newly created admin user.
2. If you haven't set up two-factor authentication for the new admin user yet, do it now and start over from step 1. If you already did, continue with the next step.
3. DSM asks you for the OTP code. Enter it and make sure to check "Save this device".
4. After login (or the "You are not allowed to use this service" message if you restricted the access like I did) click on the lock icon left to the URL and choose "Cookies".
5. Search for the `did` cookie, copy it's content and set the `SYNO_DID` environment variable accordingly.

Now you can proceed with the deployment like shown above in the one-time setup.