---
title: "Own Smart Home: Firmware"
image: /img/thumbnails/smart-home-fw.jpg
bigimg: /img/smart-home-fw-cfg-code.jpg
tags: [Programming,MQTT,Electronics,ESP8266,IoT]
---

This is the third blog post about my smart home project. We'll have a closer look at the firmware. Consider reading the previous posts about this project:

1. [Hardware]({% post_url 2017-04-08-own-smart-home-hardware %})
2. [Architecture]({% post_url 2017-04-16-own-smart-home-architecture %})

I'm using an ESP8266 (ESP-12E) for controlling my devices. The ESP is a WiFi-powered microcontroller.

As I mentioned in the [last post]({% post_url 2017-04-16-own-smart-home-architecture %}): I'm using [PlatformIO](http://platformio.org/) as a base for the firmware. It integrates well with many IDEs, has support for Continuous Integration and provides all toolchains, uploaders and frameworks for numerous boards.

# Functions

To control the [hardware]({% post_url 2017-04-08-own-smart-home-hardware %}), our firmware needs following functions:

- Control Infrared LED (TV & sound system)
- Control 433MHz-Transmitter (wireless sockets)
- Continuous monitoring of GPIO pin states (motion & window sensors)
- Continuously reading temperature & humidity from DHT11 sensor

Further, I wanted some more features:

- Central configuration
- Configuration via MQTT
- Functions available via MQTT
- Over-The-Air (OTA) firmware updates via WiFi

# Implementation

The setup for all functions described above can be done in the [central config file](https://github.com/lippertmarkus/esp8266-managed/blob/master/src/config.cpp). Here you can specify a HTTP-URL for the OTA-updates, the WiFi connection, the MQTT server as well as the GPIO pins of the used sensors and topics the sensor functions will be subscribing/publishing to.

Heart of the firmware is the [MQTT client library 'pubsubclient'](https://github.com/knolleary/pubsubclient/). Every function of the firmware can be controlled via MQTT. It took me quite a long time deciding on a client library and I'm even not quite sure yet. The developer did a really great work and developed a great interface, but I miss the support for QoS 1 and 2 MQTT messages for ensuring that e.g. messages about motion detection are verifiable sent to the MQTT broker. Anyway, for now I stayed with it.

The [OTA-update function](http://esp8266.github.io/Arduino/versions/2.0.0/doc/ota_updates/ota_updates.html#http-server) is provided by the default Arduino Core framework for the ESP8266. The update will be triggered by publishing the string 'update' to a special system topic. The firmware is then downloading the newest firmware from the server specified in the configuration file, updates and restarts itself. The system base topic also provides health information about the ESP. I didn't implement automatic updates because I wanted control on whether and when my ESPs are updating.

The function for controlling the 433MHz-transmitter is subscribing to a topic `wireless_socket/#`. The `#` means that the subscriber also gets messages from all subtopics. E.g. I can publish `ON` to the topic `wireless_socket/00000/10101` which will then switch on the wireless socket with the group-code `00000` and the device-code `10101`. The codes represent the state of the DIP-switch at the back of the wireless socket.

For controlling infrared devices, we subscribe to e.g. `ir/#`. We then specify the infrared protocol in the topic and publish the data. I would for example publish `400501FE` to the topic `ir/nec` for switching my sound system on via infrared through the NEC-protocol. I used the [IRremoteESP8266 library](https://github.com/markszabo/IRremoteESP8266) for achieving this, which also provides some example code to receive and decode infrared signals from remotes.

The function for reading the temperature is rather boring: I used the [SimpleDHT library](https://github.com/winlinvip/SimpleDHT) to read the data from the DHT11 and publishing it to a topic based on the publish cycle specified in the config file. The MQTT messages are tagged as retained to always provide new subscribers the latest data without having them to wait until the next publish. 

The motion and windows sensors are directly connected to GPIO pins. The state of the pins are continuously read and compared with the previous one. A change of the state is immediately published to a specified MQTT topic.

# Installing firmware

Even with OTA support we need a way to install firmware the traditional way if we flash it for the first time or we accidently break our OTA function.

As shown in the [schematic]({% post_url 2017-04-08-own-smart-home-hardware %}), I connected the Tx and Rx pins with the data pins of the microUSB connector. That way, I can easily hook up my FTDI via microUSB to program it:

{: .center}
![Uploader](/assets/posts/own-smart-home-firmware/uploader.jpg){:width="45%"}

# Final Thoughts

MQTT is a really great protocol for developing Internet-of-Things applications like this. The developed firmware for my ESP provides a good base for my smart home and can be easily modified or extended to fit different needs.
Making all functions for controlling my devices available via MQTT gives me a good interface to develop own clients or using software like OpenHAB introduced in my [last post]({% post_url 2017-04-16-own-smart-home-architecture %}).

For now, all configuration is set through the config file. Later on, I want to be able to change this configuration also through MQTT. I also want to create a UI to manage the configuration of multiple ESPs and monitoring them.

You can find the source code on my [GitHub](https://github.com/lippertmarkus/esp8266-managed).
