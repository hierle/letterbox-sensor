#include <Arduino.h>

//ir-led of proximity sensor (invisible)
//#define irled 7
//
#define irled 3
//
// power in for diode in proximity sensor
//#define irdiode 3
#define irdiode 7
//
//#define irdiode 8
//
//adc pin (connect to output of sensor)
//#define irsens 2
//#define irsens 8
#define irsens A2
//
//#define irsens 7
//
// a simple status LED
//#define statusled 8
#define statusled 2

// define a threshold for your mailbox.
//#define THRESHOLD 15
#define THRESHOLD 15


bool checkLetter();

void setup()
{
  pinMode(irled, OUTPUT);
  pinMode(irdiode, OUTPUT);
  pinMode(statusled, OUTPUT);
  //pinMode(irsens, INPUT);
  digitalWrite(statusled, HIGH);
  delay(500);
  digitalWrite(statusled, LOW);
  delay(500);

  //digitalWrite(irled, HIGH);

}

void loop()
{
  if(checkLetter() == true ){
    digitalWrite(statusled, HIGH);
  }else{
    digitalWrite(statusled, LOW);
  }
  //delay(1000);
  delay(100);


}


bool checkLetter(){
  digitalWrite(irled,HIGH);
  digitalWrite(irdiode,HIGH);
  //delay(100);
  unsigned int measure = 0;
  for(int i = 0 ; i <3 ; i++){
    delay(15);
    measure += analogRead(irsens);
  }
  digitalWrite(irled,LOW);
  digitalWrite(irdiode,LOW);

  measure = measure/3;

  //blink(measure);

  if(measure > THRESHOLD){
    return true;
  }else{
    return false;
  }
}
