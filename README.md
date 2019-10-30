# LoRaWan EU868MHz Letterbox Sensor
sensing letters in your letterbox via IR diode pair, sending out status via LoRaWan/TTN
based on Attiny84, RFM95W, HSDL9100, powered by a CR2032 battery.

![Lora letterbox sensor](https://github.com/hierle/letterbox-sensor/blob/master/misc/letterbox-sensor.png?raw=true)

This is basically a clone of the heise ct briefkasten sensor project<br> 
https://www.heise.de/ratgeber/IoT-Netz-LoRaWAN-Briefkastensensor-mit-hoher-Reichweite-selber-bauen-4417179.html<br>
https://github.com/jamct/radio-mailbox

Contents:
- ./PCB/ :               kicad PCB files
- ./calibrate/ :         calibration sketch to adjust the poti for letter distance
- ./letterbox_sensor/ :  lora letterbox sensor sketch
- ./misc/ :              payload decoder, sample http integration cgi

Compiled with platformio, hex flashed to attiny with ArduinoISP

Changes:
- created SMD PCB
- onboard 868MHz PCB antenna after TI document http://www.ti.com/lit/an/swra227e/swra227e.pdf
- switched MISO/MOSI lines of RFM95
- Attiny pin renumbering 0...10 -> 10...0
- sensor pin naming changed from 8 -> A2, otherwise no ADC reading
- added basic temperature reading from RFM95
- added sensor raw value, voltage, temperature in lora package

BOM (digikey.de):

|Part number        |  Description            |
|-------------------|-------------------------|
|ATTINY84A-SSUR     |  IC MCU 8BIT 14SOIC     |
|HSDL-9100-021      |  PROXIMITY SENSOR       |
|RFM95W-868S2       |  RF TXRX MODULE         |
|3314G-1-105E       |  TRIMMER 1M OHM         |
|BU2032SM-FH-GTR    |  CR2032 COIN CELL HOLDER|
|HLE-103-02-L-DV    |  CONN RCPT 6POS         |
|AA3528LSECKT/J4    |  LED ORANGE             |
|CRGCQ1206F33R      |  33R 1206               |
|CRGCQ1206F220R     |  220R 1206              |
|LQG18HN1N8S00D     |  IND 1.8NH 0603         |
|GRM1885C1H2R7CA01D |  CAP 2.7PF 0603         |


Have fun!

