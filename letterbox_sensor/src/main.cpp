#include <attiny.h>
#include "tinySPI.h"
#include "LoRaWAN.h"

//Change Keys in secconfig.h for your TTN application:
#include "secconfig.h"

ATTINY at =  ATTINY();

#include <Arduino.h>

//#define atsleep 16
#define atsleep 1800 // 30min

//ir-led of proximity sensor (invisible)
#define irled 3
// power in for diode in proximity sensor
#define irdiode 7
//adc pin (connect to output of sensor)
#define irsens A2
//
#define statusled 2
//
//#define rfmreset 9


// define a threshold for your mailbox.
//#define THRESHOLD 15
#define THRESHOLD 30

// init RFM95W
#define DIO0 0
#define NSS  1
RFM95 rfm(DIO0,NSS);

LoRaWAN lora = LoRaWAN(rfm);
unsigned int Frame_Counter_Tx = 0x0000;

unsigned int checkLetter();


void setup() {
  at.setSleeptime(atsleep);
  rfm.init();
  lora.setKeys(NwkSkey, AppSkey, DevAddr);
  pinMode(irled, OUTPUT);
  pinMode(statusled, OUTPUT);
  pinMode(irdiode, OUTPUT);
  //pinMode(rfmreset, OUTPUT);
  // blink once
  digitalWrite(statusled, HIGH);
  delay(10);
  digitalWrite(statusled, LOW);
}

void loop() {
  if (at.checkAction()) {
    //uint8_t Data_Length = 0x01;
    //uint8_t Data_Length = 0x06;
    uint8_t Data_Length = 0x07;
    uint8_t Data[Data_Length];
    unsigned int measure = 0;
    measure = checkLetter();

    if(measure > THRESHOLD){
      Data[0] = 0xFF; }
    else {
      Data[0] = 0x00;
    }
   //
   // bat
   unsigned int vol=at.getVoltage();
   Data[1] = (vol & 0xFF);
   Data[2] = ((vol >> 8) & 0xFF);
   // sensor
   Data[3] = ( measure & 0xFF);
   Data[4] = (( measure >> 8) & 0xFF);
   // thresh
   Data[5] = THRESHOLD;
   // temperature, not working yet
   Data[6] = rfm.RFM_Temp();

   // end
   //Data[6] = 0x00;

   //digitalWrite(statusled, HIGH);
   lora.Send_Data(Data, Data_Length, Frame_Counter_Tx);
   Frame_Counter_Tx++;
   //digitalWrite(statusled, LOW);

   //digitalWrite(statusled, HIGH);
   //delay(10);
   //digitalWrite(statusled, LOW);

  }
  //at.setSleeptime(32);
  at.setSleeptime(atsleep);
  at.gotoSleep();
}

//interrupt service routine. Incrementing sleep counter
ISR(WDT_vect)
{
  at.incrCycles();
}

// check ir sensor value
unsigned int checkLetter() {
  digitalWrite(irled,HIGH);
  digitalWrite(irdiode,HIGH);
  unsigned int measure = 0;
  delay(25);
  for(int i = 0 ; i <3 ; i++){
    delay(25);
    measure += analogRead(irsens);
  }
  digitalWrite(irled,LOW);
  digitalWrite(irdiode,LOW);
  measure = measure/3;

  return(measure);
}
