# IoT Open Lynx Edge App reading Aidon meter with Tibber pulse

The Tibber pulse is a nice looking, easy to install gadget for reading the MBUS
data from electrical meters. This has only been tested woth the RJ45 version
and with an Aidon meter.

The setup is simple.

## Setup your Edge Client to accept MQTT-connections

I use a Raspberry Pi Edge Client but a Docker one or any other should work just
as fine. The Edge Client needs to expose the MQTT interface so the Pulse can
access it.

## Configure the Pulse

Boot the Pulse by pluggin in the USB cable included in the package.

It will boot as a WLAN access point. Connect you computer to it.

I'm not sure all units have the same IP-address but mine could be reached at
http://10.133.70.1. The device have a very minimal web interface and are quite
easy to configure. You have to enter something in the update\_url at the bottom
or the data will not work. 

You will have to enter two MQTT topics. They probably should not be the same.
