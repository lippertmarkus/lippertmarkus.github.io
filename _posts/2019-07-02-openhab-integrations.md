---
title: "Integrating openHAB with Alexa, Google Home, Apple HomeKit and Cortana"
image: /img/thumbnails/alexa.jpg
bigimg: /img/google-home.jpg
tags: [openHAB, Alexa, Google Home, Apple HomeKit, Cortana, Google Assistant]
---

I already quickly introduced [openHAB](https://www.openhab.org/) in [a previous post]({% post_url 2017-04-16-own-smart-home-architecture %}) and over the past years it evolved a lot. Next to the support for a lot of smart devices it also enables the integration with various assistants, making your Smart Home even more convenient and fun.

As I use various devices with different assistants on them at home, I also looked at the available on- and offline integrations which I want to introduce in this post. The online integration of these assistants via the openHAB Cloud Connector is much simpler in my opinion but I'll also talk about the offline-only integration.

## openHAB Cloud Connector

The openHAB Cloud Connector allows remote access to a local openHAB installation without exposing ports to the Internet. It also enables push notifications on Android and iOS devices through the openHAB apps. Services like [IFTTT](https://ifttt.com/), Google Assistant or the Alexa Skills can integrate with the openHAB Cloud via OAuth2 like shown in the next sections.

openHAB Cloud is [open-source](https://github.com/openhab/openhab-cloud) and can be self-hosted. Another way is to use the instance [myopenHAB.org](http://www.myopenhab.org/) hosted by the [openHAB Foundation](http://www.openhabfoundation.org/) which is free of charge.

After registering in the openHAB Cloud instance and locally installing the Cloud Connector via _Add-ons > Misc_ in the Paper UI, it can be configured in _Configuration > Services > IO_ to allow remote access and push notifications as well as to use for example `https://myopenhab.org/` as the openHAB Cloud instance. You then need to enter the locally generated UUID and secret into your openHAB Cloud account as described in the [documentation](https://www.openhab.org/addons/integrations/openhabcloud/).

## Amazon Alexa

After setting up openHAB Cloud you can easily connect your openHAB installation via the [openHAB Skill](https://www.amazon.de//dp/B01MTY7Z5L). Just activate the skill via the website or the Alexa app, log in with your openHAB Cloud account and click _Allow_. If your items are configured correctly like explained in the [documentation](https://www.openhab.org/docs/ecosystem/alexa/) you can control your devices with your voice via the Alexa App or the Amazon Echo.

<div class="center" markdown="1">
<img class="lazy" alt="Alexa Setup" data-src="/assets/posts/openhab-integrations/alexa-setup.gif" height="500px" />
</div>

If you don't want to use openHAB Cloud you can also set up the [Hue Emulation Service](https://www.openhab.org/addons/integrations/hueemulation/). It emulates a HUE bridge which can be used by Amazon Echo or Google Home devices in your local network. It can also be installed and configured via the Paper UI. Amazon Echo expects the bridge to run on port 80 which means you need to use this as the port for your openHAB installation, create a port forward or install a reverse proxy. Also consider, that some Echo devices only support the discovery of first-generation HUE bridges which can be achieved with the `temporarilyEmulateV1bridge` setting. Detailed information about the configuration of the HUE Emulation Service as well as the items can be found [here](https://www.openhab.org/addons/integrations/hueemulation/).

## Google Home and Google Assistant

The Google Home and Google Assistant integration also works like the Alexa integration. In the Google Home app you add a new item and click on _Existing item_ to add the openHAB service and log into your openHAB Cloud account. You can then control your smart devices with your voice with the Google Assistant on your Smartphone or via the Google Home device.

<div class="center" markdown="1">
<img class="lazy" alt="Google Assistant Setup" data-src="/assets/posts/openhab-integrations/google-home-setup.gif" height="500px" />
<img class="lazy" alt="Google Assistant Example" data-src="/assets/posts/openhab-integrations/google-home-cmd.gif" height="500px" />
</div>

Information about the configuration of the your openHAB items as well as a step-by-step is again available in the [documentation](https://www.openhab.org/docs/ecosystem/google-assistant/). Make sure to get your item configuration right as the openHAB service else won't connect via openHAB cloud.

Again for offline integration you have the option to use the Hue Emulation Service described in the last section. Google Home also needs the emulated HUE bridge to run on port 80.

## Apple HomeKit

The Apple HomeKit integration only works locally for now. After installing the HomeKit integration via the Paper UI you need need to configure a PIN and the network interface to use. Within the Apple Home app you can manually search for the bridge via _Add > Add Device > Code is missing_ and add the devices after entering the PIN. Those smart devices can be controlled within the Home app or with Siri.

<div class="center" markdown="1">
<img class="lazy" alt="HomeKit Setup" data-src="/assets/posts/openhab-integrations/homekit-setup.gif" height="500px" />
<img class="lazy" alt="Siri Example" data-src="/assets/posts/openhab-integrations/siri-cmd.gif" height="500px" />
</div>

Again, make sure to [configure](https://www.openhab.org/addons/integrations/homekit/) your openHAB items accordingly to allow the discovery and control of your appliances.

## Microsoft Cortana

There is no official integration for Microsoft Cortana yet, but you can use the [Cortana integration of IFTTT](https://ifttt.com/cortana) in combination with openHAB Cloud to control your devices based on specific phrases.

A user of the community also developed a [Cortana skill for HABot](https://community.openhab.org/t/cortana-skill-for-habot-testers-needed-and-maintainer-input-requested/60332) which seems to be still in test but not actively maintained.

## Conclusion

There are various integrations for openHAB which are really useful to control all the smart devices with your voice or via different apps. The setup of them is mostly straightforward. Next to the introduced integrations openHAB can also integrate with the [Azure IoT Hub](https://www.openhab.org/addons/integrations/azureiothub/) and other services.

There is also [a binding](https://www.openhab.org/addons/bindings/amazonechocontrol/) to control the Amazon Echo to play music, set alarms or to set the volume. With this binding you can also use your Echo devices as an audio sink to enable the text-to-speech output from openHAB. The same can be achieved with Google Home devices via the [Chromecast binding](https://www.openhab.org/addons/bindings/chromecast/). 

This way you can notify about events via natural language through these devices. I'll have a look at this in a future post.
