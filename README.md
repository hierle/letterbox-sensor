LoRaWan EU868MHz Letterbox Sensor, sensing letters in your letterbox via IR diode pair, sending out status via LoRaWan/TTN
based on Attiny84, RFM95W, HSDL9100, powered by a CR2032 battery.

![Lora letterbox sensor](https://github.com/hierle/letterbox-sensor/blob/master/misc/letterbox-sensor.jpg?raw=true)

This is basically a clone of the heise ct briefkasten sensor project<br> 
https://www.heise.de/ratgeber/IoT-Netz-LoRaWAN-Briefkastensensor-mit-hoher-Reichweite-selber-bauen-4417179.html<br>
https://github.com/jamct/radio-mailbox

Contents:
- PCB:               kicad PCB files
- calibrate:         calibration sketch to adjust the poti for letter distance
- letterbox_sensor:  lora letterbox sensor sketch
- misc:              payload decoder, sample http integration cgi

Compiled with platformio, hex flashed to attiny with ArduinoISP

Changes:
- created SMD PCB
- onboard 868MHz PCB antenna after TI document http://www.ti.com/lit/an/swra227e/swra227e.pdf
- switched MISO/MOSI lines of RFM95
- Attiny pin renumbering 0...10 -> 10-0
- sensor pin naming changed from 8 -> A2, otherwise no ADC reading
- added basic temperature reading from RFM95
- added sensor raw value, voltage, temperature in lora package


Have fun!
