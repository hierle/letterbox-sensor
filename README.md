Letterbox sensor, sensing letters in your letterbox via IR diode pair, sending out status via LoRaWan/TTN.

This is basically a clone of the heise ct briefkasten sensor project 
https://www.heise.de/ratgeber/IoT-Netz-LoRaWAN-Briefkastensensor-mit-hoher-Reichweite-selber-bauen-4417179.html
https://github.com/jamct/radio-mailbox

Contents:
PCB:               kicad PCB files
calibrate:         calibration sketch to adjust the poti for letter distance
letterbox_sensor:  lora letterbox sensor sketch
misc:              payload decoder, sample http integration cgi

Changes:
- created SMD PCB
- switched MISO/MOSI lines of RFM95
- Attiny pin renumbering 0...10 -> 10-0
- sensor pin changed from 8 -> A2, otherwise no ADC reading
- basic temperature reading from RFM95
- added sensor raw value, voltage, temperature in lora package


Have fun!

