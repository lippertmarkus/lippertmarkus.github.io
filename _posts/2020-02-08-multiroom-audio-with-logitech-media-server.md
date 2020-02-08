---
title: "Multiroom Audio with Logitech Media Server"
image: /img/thumbnails/lms.png
bigimg: "/img/loudspeaker.jpg"
tags: [SmartHome, Raspberry Pi, Audio]
---

As consumer products for multiroom audio solutions are either expensive, limited in their functionality or sooner or later won't receive further updates, [like recently the legacy Sonos devices](https://blog.sonos.com/en/end-of-software-updates-for-legacy-products/), it's worth to have a look at more flexible solutions. 

**Logitech Media Server (LMS)** is a cross-platform [open source solution](https://github.com/Logitech/slimserver) for high quality audio streaming. It supports locally stored music as well as internet radio streams and is extendable via plugins to e.g. integrate streaming providers like Spotify, Deezer and many more. 

LMS is actively developed and has a big community. It can be controlled via web, mobile and desktop apps and connects to various players including Chromecast, AirPlay and UPNP/DLNA devices as well as software players on all operating systems. These software players also allow to create your own streaming devices like Wi-Fi speakers. 

I'll have a quick look at the concepts and then describe how to set up the server with a player and shortly show how to control the system.

## TL;DR

Go straight to the [software installation](#software).

## Introduction

LMS (formerly Squeezebox Server) was originally developed by Slim Devices and later acquired by Logitech which provided the solution as open source software. There were also hardware players (Squeezeboxes) which were used together with the Squeezebox Server. These hardware players are no longer sold, but their software is also open source so that the community could further maintain the server and player software. Thank's to that you're now able to easily set up your own server and build your own Squeezebox or just add a simple headless player to your multiroom audio solution.

Most of the information can be found in the [wiki](http://wiki.slimdevices.com) or the [forums](https://forums.slimdevices.com/). If you need more information, please have a look there. I'll just quickly introduce the most important concepts to get started quickly with setting up a simple headless player. 

## Architecture

The audio streaming system consists of a *server*, multiple *players* and *remotes* to control the system as shown in the following figure (adapted from [LoxWiki](https://www.loxwiki.eu/display/LOX/Logitech+Media+Server?preview=/1638614/1638612/LMS%20Setup.jpg)):

<div class="center" markdown="1">
  <img class="lazy" alt="Logitech media server architecture" data-src="/assets/posts/multiroom-audio-lms/lms-arch.png" />
</div>

- The **server** streams audio to various players and is able to synchronize players to enable multiroom audio. LMS as a server also allows you to use plugins, integrate with various other systems, set up alarms, organize your music and much more.  

- The **players** connect to the server via your local network and can be controlled by remotes via the server. There exist software and hardware players which just play the received audio stream from the server. A simple, popular and platform-independent headless player is Squezeelite. You find a ton of different player software, but most of them are using Squeezelite under the hood.

- The **remotes** are used to control the players. You can select the music to play or change the volume, add groups for synchronization and much more. By default, LMS provides a web interface acting as a remote. There are also apps like [Squeezer](https://play.google.com/store/apps/details?id=uk.org.ngo.squeezer&hl=de) for Android and [iPeng](https://apps.apple.com/de/app/ipeng/id767266886) for iOS. These use the CLI exposed by the server, which you can also use to control the system from other solutions like your smart home.

The three components can be separate or combined into one device. LMS for example is a server and a remote as it not just streams the audio to the players but like i mentioned also acts as a remote as it provides a web interface to control the players.

The [piCorePlayer project](https://www.picoreplayer.org/) for example offers ready-to-use images for the Raspberry Pi where you can choose which of the three components you want to combine. If you want a simple solution with additional web based management of your players, you can go with that. If you want to run other software on your Pi side-by-side, you would want to set up Squeezelite by yourself instead as piCorePlayer uses a trimmed down Linux. Next to the installation of Squeezelite we'll also have a look at the setup of the LMS and remotes.

## Setup

I want to set up a dedicated LMS server as well as some players which I can connect to already existing loudspeakers. You can also just use your laptop as a player, or even build your own wireless speaker with a Raspberry Pi, an amp and a passive speaker. I try to describe the setup as general as possible to be suitable for every scenario. 

### Hardware

- **Server**: Can be an already existing system, a Raspberry Pi, your NAS or any other Windows, Linux or Mac system.

- **Player**: If you just want to try out LMS quickly you can use your PC/Laptop as a player. For a standalone solution you would want to use a dedicated system which is connected to existing speakers or build yourself a Wi-Fi speaker. 

- **Remote**: You can use the web interface provided by LMS on any device or install the mobile apps which I introduced before on your phone.

I'm going to use my NAS for the server as well as the LMS web interface and my mobile phone as a remote. For the players I use two Raspberry Pi Zero W's as I already have those in my bedroom and livingroom next to my audio equipment. I used an [miniHDMI2VGA adapter](https://www.aliexpress.com/item/32604648728.html) with an audio output for around 2-3 € for the audio output from the Raspberry Pi. In my opinion, this already provides a decent audio quality. If you want to go further you could also use a USB soundcard or a [HiFiBerry shield](https://www.hifiberry.com/products/).

### Software

- **Server**: You can download LMS from the [official site](https://www.mysqueezebox.com/download) for any operating system, use a [docker image](https://hub.docker.com/r/larsks/logitech-media-server) or package for your NAS. I used the [package for my Synology NAS](https://www.synology.com/en-us/dsm/packages/SqueezeCenter). The installation is straightforward in all cases and after opening the web interface you'll be guided through a short setup of your music folders and end up here:  
<div class="center" markdown="1">
<img class="lazy" alt="Logitech Media Server web interface" data-src="/assets/posts/multiroom-audio-lms/lms-web-ui.png" width="70%" />
</div>

- **Player**: I would recommend [Squeezelite](https://sourceforge.net/projects/lmsclients/files/squeezelite/) as the most popular one. You can find other cross-plattform players [here](https://sourceforge.net/projects/lmsclients/files/).  
After downloading Squeezelite you can list available output devices and start it with different options, here are some of the most useful ones:

  ```bash
  squeezelite -?                      # list all parameters
  squeezelite -l                      # list available audio devices
  squeezelite                         # use default audio device and autodiscovery to find LMS
  squeezelite -s 10.3.3.1             # explicitely set LMS server IP
  squeezelite -n bedroom              # set name of the player
  squeezelite -o hw:CARD=ALSA,DEV=1   # use HDMI audio output on Raspberry Pi Zero
  ``` 

- **Remote**: With your player running you should see its name in the top right corner of the LMS web interface after refreshing the page. You're now able to select local music or a radio station on the left side and play it via your Squeezelite player. You can also use a mobile app like Squeezer for Android or iPeng on iOS to control your player.

That's it for the basic setup and usage. You should have a look at all the features and settings the LMS web interface provides. Go ahead and add multiple players to be able to group and sync them. Also try out some of the plugins, I e.g. use them to integrate my Chromcasts and other DLNA devices.

## There's more

- As I mentioned LMS provides a CLI which can be used e.g. to control your multiroom audio solution via your smart home. I use the openHAB [Squeezebox Binding](https://www.openhab.org/addons/bindings/squeezebox/) for that:
  <div class="center" markdown="1">
  <img class="lazy" alt="openHAB integration for Logitech Media Server" data-src="/assets/posts/multiroom-audio-lms/openhab-lms.jpg" width="35%" />
  </div>
  
  It also supports using your multiroom audio system as an audio sink to play sounds or make announcements in multiple or specific rooms of your house.

- I also use my Raspberry Pi's as bluetooth audio receivers together with Darkice and Icecast to create a private radio stream. This radio stream can be used within LMS to stream audio from my phone via bluetooth to to multiple rooms in the house.