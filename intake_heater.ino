#include <OneWire.h>
#include <DallasTemperature.h>

#define ONE_WIRE_BUS 2
#define TEMPERATURE_PRECISION 9

#define HEATER_RELAY 4
#define HEATER_LIMIT 40.0

int heaterState = 0;

OneWire oneWire(ONE_WIRE_BUS);

DallasTemperature sensors(&oneWire);

DeviceAddress beforeSensor = { 0x28, 0xFF, 0xBE, 0x38, 0xA6, 0x16, 0x05, 0xAF };
DeviceAddress afterSensor = { 0x28, 0xFF, 0x18, 0x60, 0xA6, 0x16, 0x03, 0x19 };

void setup(void)
{
  pinMode(HEATER_RELAY, OUTPUT);
  digitalWrite(HEATER_RELAY, HIGH);
  
  // start serial port
  Serial.begin(9600);
  Serial.println("Dallas Temperature IC Control Library Demo");

  // Start up the library
  sensors.begin();

  // set the resolution to 9 bit per device
  sensors.setResolution(beforeSensor, TEMPERATURE_PRECISION);
  sensors.setResolution(afterSensor, TEMPERATURE_PRECISION);
}

void printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  Serial.print("Temp C: ");
  Serial.println(tempC);
}

void switchHeater(float afterTemp)
{
  if ((heaterState >= 0) && (afterTemp > -50.0) && (afterTemp < HEATER_LIMIT)) {
    digitalWrite(HEATER_RELAY, LOW);
    heaterState = 1;
  } else {
    digitalWrite(HEATER_RELAY, HIGH);
    heaterState = -1;
  }
  Serial.print("Heater state code: ");
  Serial.println(heaterState);
}

void loop(void)
{
  sensors.requestTemperatures();
  Serial.print("Before: "); 
  printTemperature(beforeSensor);
  Serial.print("After: ");
  printTemperature(afterSensor);
  switchHeater(sensors.getTempC(afterSensor));
  delay(10000);
}
