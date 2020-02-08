---
title: "TODO"
image: "TODO"
bigimg: "TODO"
tags: [TODO]
---

see http://ww1.microchip.com/downloads/en/devicedoc/Atmel-7701_Automotive-Microcontrollers-ATtiny24-44-84_Datasheet.pdf#page=31&zoom=100,45,68

on:

base:
3.3V, 1MHZ

without mod: 1.24mA

- all output low: .723mA
- adc disable: .549
- power_all_disable: .509
- disalbe analog comparator: .438
- disable input buffer for adc pins: .438 - no real diff, datasheet states that only relevant when alalog signal is applied



todo:
brown-out disable -> already default mit hfuse = 0xDF
clock speed via fuse weiter lowern

------

sleep:

< 0.1µa

--- 
with nrf and button
- sleep: 0.2µa
- awake sending: 0.55ma at max (less in reality)

=> coin cell battery for lifetime :) https://www.geekstips.com/battery-life-calculator-sleep-mode/
even with 20 wakeups per hour and 1s duration per wake