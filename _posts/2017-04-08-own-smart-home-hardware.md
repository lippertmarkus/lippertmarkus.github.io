---
title: "Own Smart Home: Hardware"
image: "/img/thumbnails/smart-home-hw.jpg"
bigimg: "/img/smart-home-hw-pcb.jpg"
tags: [Electronics,SmartHome,IoT,ESP8266]
---

As a software developer, I'm also very interested in electronics and the programming of microcontrollers. Of course I also had a look into the current hype of home automation.

What I found was rather disappointing. No real architecture standards, every manufacturer is doing its own thing. Different devices are not really working together - that's not what the "Internet Of Things" should look like to me. Apart from that, I found the devices on the market are way to expensive for what they actually do.

To save some money while having more flexibility, I decided to start automating some of my electronic devices on my own. As I played around with the WiFi-powered ESP8266 shortly before, I used this chip as a base for my own smart things.

As I was looking around my room, I set the following goals for my project:

- Control TV and sound system
- Switch very cheap wireless sockets (lamps and other devices)
- Motion detection
- Temperature and humidity sensors
- Determine window/door states

All the devices should be controlled by an ESP in my room, which is connected to my WiFi network. I also wanted a centralized configuration for all (in future added) ESPs and Over-The-Air firmware updates via WiFi and an own update server.

As a little motivation, the parts list:

|---------------------------------------+------------------|
| Part                                  |          Price $ |
|:--------------------------------------|-----------------:|
| [ESP8266 ESP-12F](https://de.aliexpress.com/item/2015-New-version-1PCS-ESP-12F-ESP-12E-upgrade-ESP8266-remote-serial-Port-WIFI-wireless-module/32643052680.html?spm=2114.13010608.0.0.OhXPw2)                       |         1x $1.75 |
| [DHT11](https://de.aliexpress.com/item/Free-Shipping-1x-DHT11-DHT-11-Digital-Temperature-and-Humidity-Temperature-sensor-for-Arduino-Hot/32243034419.html?spm=2114.13010608.0.0.wHWh79) (temperature & humidity)        |         1x $1.26 |
| [433MHz Transmitter](https://de.aliexpress.com/item/RF-wireless-receiver-module-transmitter-module-board-for-arduino-super-regeneration-315-433MHZ-DC5V-ASK-OOK/1620400987.html?spm=2114.13010608.0.0.diau83) (wireless sockets) |         1x $0.62 |
| [433MHz Antenna](https://de.aliexpress.com/item/Free-Shipping-10pcs-lot-433mhz-Copper-Spring-Antenna/32447827044.html?spm=2114.13010608.0.0.wHWh79) (or build yourself)    |         1x $0.20 |
| [microUSB Connector](https://de.aliexpress.com/item/10pcs-MICRO-USB-to-DIP-Adapter-5pin-Female-Connector-B-Type-PCB-Converter/32720363831.html?spm=2114.13010608.0.0.wHWh79)                    |         1x $0.11 |
| [Motion Sensor](https://de.aliexpress.com/item/Free-Shipping-HC-SR501-Adjust-Infrared-IR-Pyroelectric-Infrared-PIR-module-Motion-Sensor-Detector-Module-We/32519303005.html?spm=2114.13010608.0.0.OhXPw2)                         |         1x $0.78 |
| [Pushbutton](https://de.aliexpress.com/item/50pcs-lot-6x6x6MM-4PIN-G91-Tactile-Tact-Push-Button-Micro-Switch-Direct-Self-Reset-DIP-Top/32668577698.html?spm=2114.13010608.0.0.OhXPw2)                            |         1x $0.01 |
| [Magnetic Contact](https://de.aliexpress.com/item/Free-Shipping-5-pcs-MC-38-MC38-Wired-Door-Window-Sensor-Magnetic-Switch-Home-Alarm-System/32255881055.html?spm=2114.13010608.0.0.OhXPw2) (windows/doors, ..)  |         1x $0.60 |
| [IR LED](https://de.aliexpress.com/item/100pcs-5mm-Infrared-IR-LED-Light-Emitting-Diode-Lamp-940nm-5-mm-Transparent-Water-Clear-Lens/32371513701.html?spm=2114.13010608.0.0.wHWh79) (for TV, sound system, ..)     |         1x $0.05 |
| 1k Resistors                          |         3x $0.01 |
| [Wireless Socket](https://www.pollin.de/p/funksteckdosen-set-mit-3-steckdosen-550666) (433 MHz)             |         1x $5.00 |
|=======================================+==================|
| **Total**                             |        **$9.41** |
|---------------------------------------+------------------|

You may already have laying around some of the parts or can salvage them from old stuff. I ordered most of them from [AliExpress](https://www.aliexpress.com/), where I also got the prices of the parts list from. For programming the ESP you also need an [FTDI](https://de.aliexpress.com/item/Free-Shipping-1pcs-FT232RL-FTDI-USB-3-3V-5-5V-to-TTL-Serial-Adapter-Module/32481520135.html?spm=2114.13010608.0.0.wHWh79) for less than $2.

After some breadboard prototyping I layed out a schematic in [EasyEDA](https://easyeda.com/) and created my first PCB ever (don't blame me for using autorouter). You can find the layout and the PCB [here](https://easyeda.com/markus9656/ESP_Managed-83b3b148fb944862be8a27f48f32800a). If you wonder why I'm running my ESP with 5V instead of the recommended 3.3V: My ESPs were much more stable while running them with 5V and there are definitely much more things that can be improved in my schematic.

<div class="center" markdown="1">
<img class="lazy" alt="Schematic" data-src="/assets/posts/own-smart-home-hardware/Schematic.png" width="45%" />
<img class="lazy" alt="PCB" data-src="/assets/posts/own-smart-home-hardware/PCB.png" width="45%" />
</div>

Although the holes are too close to the edges of the PCB and the resistor underneath the pushbutton is a bit too close to the microUSB port, the PCB came out pretty well for my first try. I ordered 5 pieces of the PCB at [Elecrow](https://www.elecrow.com/pcb-manufacturing.html) for less than $10. After soldering, I also created a little box for my project and printed it out with a 3D-printer of a friend.

<div class="center" markdown="1">
<img class="lazy" alt="PCB front" data-src="/assets/posts/own-smart-home-hardware/pcb-front.jpg" width="45%" />
<img class="lazy" alt="PCB back" data-src="/assets/posts/own-smart-home-hardware/pcb-back.jpg" width="45%" />
</div>

<div class="center" markdown="1">
<img class="lazy" alt="Box front" data-src="/assets/posts/own-smart-home-hardware/box-front.jpg" width="45%" />
<img class="lazy" alt="Box back" data-src="/assets/posts/own-smart-home-hardware/box-back.jpg" width="45%" />
</div>

As running costs are also very interesting: The hardware used about 0,41W in my measurements. This results in around 1 € per year with average costs of 0.28 €/kWh for electricity in Germany.

The firmware itself is using [MQTT](http://mqtt.org/) for communication. This allows easy and lightweight interfacing with various clients. You can find the source code on my [GitHub](https://github.com/lippertmarkus/esp8266-managed) (excuse my bad C/C++ skills). In my overall solution I communicate with the ESPs via [OpenHAB 2](https://www.openhab.org/).

More details on the source code as well as the overall architecture of the project and OpenHAB will follow in future posts.
