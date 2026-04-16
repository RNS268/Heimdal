/*************************************************
   SMART HELMET FINAL PRODUCT FIRMWARE - CORRECTED
*************************************************/

#include <Arduino.h>
#include <Wire.h>
#include <TinyGPS++.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "AudioTools.h"
#include "BluetoothA2DPSink.h"

/* ================= PIN DEFINITIONS ================= */

//LED Lights
#define LED_LEFT   32
#define LED_RIGHT  33
#define LED_BRAKE  27

// GPS
#define GPS_RX      16
#define GPS_TX      17
#define GPS_BAUD    9600

// I2S (MAX98357A)
#define I2S_BCLK    26
#define I2S_LRC     25
#define I2S_DIN     22

// MPU I2C
#define I2C_SDA     21
#define I2C_SCL     19

/* ================= CRASH PARAMETERS ================= */

#define IMPACT_THRESHOLD        7.0
#define SPEED_DROP_THRESHOLD    10.0
#define TILT_CRASH_ANGLE        60
#define CRASH_CONFIRM_TIME      100

/* ================= BLE UUID ================= */

#define SERVICE_UUID  "12345678-1234-1234-1234-1234567890ab"
#define STATUS_UUID   "44444444-4444-4444-4444-444444444444"

/* ===================================================== */

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
Adafruit_MPU6050 mpu;

/* ================= AUDIO ================= */

I2SStream i2s;
BluetoothA2DPSink a2dp_sink(i2s);

/* ================= BLE ================= */

BLECharacteristic *statusChar;
bool deviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { 
    deviceConnected = true; 
    Serial.println("BLE Client Connected");
  }
  void onDisconnect(BLEServer* pServer) { 
    deviceConnected = false; 
    Serial.println("BLE Client Disconnected");
  }
};

/* ================= DATA STRUCTURES ================= */

typedef enum {
    IND_NONE,
    IND_LEFT,
    IND_RIGHT
} IndicatorState;

typedef enum {
    CRASH_IDLE,
    CRASH_POSSIBLE,
    CRASH_CONFIRMED
} CrashState;

struct GPSData {
  double lat;
  double lng;
  double speed;
  double altitude;
  int satellites;
};

struct MotionData {
    float ax;
    float ay;
    float az;
    float gx;
    float gy;
    float gz;
    float pitch;
    float roll;
    float gForce;
    bool brake;
    IndicatorState indicator;
    CrashState crashState;
};

GPSData currentGPS;
MotionData motion;

//LED indicators blink
static bool blinkState = false;
static unsigned long lastBlink = 0;



/* ================= RTOS ================= */

SemaphoreHandle_t gpsMutex;
SemaphoreHandle_t motionMutex;

//String for DEVS
String dev_info;



/* =====================================================
                        TASKS
===================================================== */

void gpsTask(void *parameter) {
  while (true) {
    while (gpsSerial.available()) {
      gps.encode(gpsSerial.read());
    }

    if (gps.location.isUpdated()) {
    //  if (xSemaphoreTake(gpsMutex, 10)) {
        currentGPS.lat = gps.location.lat();
        currentGPS.lng = gps.location.lng();
        Serial.println(gps.location.lat());
        Serial.println(gps.location.lng());
        currentGPS.speed = gps.speed.kmph();
        currentGPS.altitude = gps.altitude.meters();
        currentGPS.satellites = gps.satellites.value();
       // xSemaphoreGive(gpsMutex);
      //}
    }
    vTaskDelay(100 / portTICK_PERIOD_MS);
  }
}

void motionTask(void *parameter) {

  static float lastSpeed = 0;
  static unsigned long crashTimer = 0;

  while (true) {

    sensors_event_t a, g, temp;
    mpu.getEvent(&a, &g, &temp);

    float ax = a.acceleration.x;
    float ay = a.acceleration.y;
    float az = a.acceleration.z;

    float gx = g.gyro.x;
    float gy = g.gyro.y;
    float gz = g.gyro.z;

    // Debug sensor output every 2 seconds
    static unsigned long lastDebug = 0;
    if (millis() - lastDebug > 2000) {
      Serial.printf("MPU6050 - Accel: %.2f, %.2f, %.2f | Gyro: %.2f, %.2f, %.2f\n", ax, ay, az, gx, gy, gz);
      lastDebug = millis();
    }

    float pitch = atan2(ax, sqrt(ay*ay + az*az)) * 180 / PI;
    float roll  = atan2(ay, sqrt(ax*ax + az*az)) * 180 / PI;

    float mag = sqrt(ax*ax + ay*ay + az*az);
    float impact = fabs(mag - 9.81);

    double speedNow = 0;
    if (xSemaphoreTake(gpsMutex, 10)) {
      speedNow = currentGPS.speed;
      xSemaphoreGive(gpsMutex);
    }

    IndicatorState ind = IND_NONE;
   // if (speedNow > 10) {
      if (roll > 15){
        ind = IND_RIGHT;
      }
      else if (roll < -15){
        ind = IND_LEFT;
        }
   // }


    bool brake = (pitch < 35);
    if(millis() - lastBlink > 500){
    blinkState = !blinkState;
    lastBlink = millis();
}


if(!blinkState){digitalWrite(LED_RIGHT, LOW);digitalWrite(LED_LEFT, LOW);}
if(motion.indicator == IND_LEFT && blinkState){digitalWrite(LED_LEFT, HIGH);digitalWrite(LED_RIGHT, LOW);}
else if(motion.indicator == IND_RIGHT && blinkState){digitalWrite(LED_RIGHT, HIGH);digitalWrite(LED_LEFT, LOW);}


if(motion.brake)digitalWrite(LED_BRAKE, HIGH);
else digitalWrite(LED_BRAKE, LOW);

CrashState crashState = CRASH_IDLE;

bool highImpact = impact > IMPACT_THRESHOLD;
bool suddenStop = (lastSpeed - speedNow) > SPEED_DROP_THRESHOLD;
///bool abnormalTilt = abs(pitch) > TILT_CRASH_ANGLE || abs(roll) > TILT_CRASH_ANGLE;

lastSpeed = speedNow;

if (highImpact) {
  /*if (crashTimer == 0) crashTimer = millis();
  if (millis() - crashTimer > CRASH_CONFIRM_TIME)
    crashState = CRASH_CONFIRMED;
  else
    crashState = CRASH_POSSIBLE;
} else {
  crashTimer = 0;*/
  crashState = CRASH_CONFIRMED;
}

if (xSemaphoreTake(motionMutex, portMAX_DELAY)) {
  motion.ax = ax;
  motion.ay = ay;
  motion.az = az;
  motion.gx = gx;
  motion.gy = gy;
  motion.gz = gz;
  motion.pitch = pitch;
  motion.roll = roll;
  motion.gForce = impact;
  motion.brake = brake;
  motion.indicator = ind;
  motion.crashState = crashState;
  xSemaphoreGive(motionMutex);
}
// FIXED: Remove the broken dev_info assignment from motionTask
// dev_info is now built correctly in bleTask
vTaskDelay(50 / portTICK_PERIOD_MS);
  }
}

void bleTask(void *parameter) {
  Serial.println("Ble transmit");
  while (true) {
    if (deviceConnected) {
      if (xSemaphoreTake(motionMutex, portMAX_DELAY)) {

        String indStr = "NONE";
        if (motion.indicator == IND_LEFT) indStr = "L";
        if (motion.indicator == IND_RIGHT) indStr = "R";

        String crashStr = "NO";
        if (motion.crashState == CRASH_CONFIRMED) crashStr = "ACCT";

        // FIXED: Build DEV info correctly using motion struct data (accel + gyro)
        String dev_info = "AX:" + String(motion.ax) +
                         ",AY:" + String(motion.ay) +
                         ",AZ:" + String(motion.az) +
                         ",GX:" + String(motion.gx) +
                         ",GY:" + String(motion.gy) +
                         ",GZ:" + String(motion.gz) +
                         ",P:" + String(motion.pitch) +
                         ",R:" + String(motion.roll);

        // FIXED: Build complete status packet with newline termination
        String status = "SP:" + String(currentGPS.speed) +
                       ",I:" + indStr +
                       ",B:" + String(motion.brake ? 1 : 0) +
                       ",C:" + crashStr +
                       ",LAT:" + String(currentGPS.lat) +
                       ",LOG:" + String(currentGPS.lng) +
                       ",CLK:" + String(blinkState ? 1 : 0) +
                       ",DEV:" + dev_info +
                       "\n";  // <-- CRITICAL: Add newline for app parsing

        statusChar->setValue(status.c_str());
        statusChar->notify();

        // Debug output
        Serial.print("BLE Sent: ");
        Serial.println(status);

        xSemaphoreGive(motionMutex);
      }
    }
    vTaskDelay(500 / portTICK_PERIOD_MS);
  }
}

/* =====================================================
                        SETUP
===================================================== */

void setup() {

  Serial.begin(115200);

  Wire.begin(I2C_SDA, I2C_SCL);

  if (!mpu.begin()) {
    Serial.println("MPU6050 Failed!");
    while (1);
  }
  Serial.println("MPU6050 initialized successfully");
  //LED Indicators
  pinMode(LED_LEFT, OUTPUT);
  pinMode(LED_RIGHT, OUTPUT);
  pinMode(LED_BRAKE, OUTPUT);

  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);

  /* ===== AUDIO ===== */
  auto cfg = i2s.defaultConfig();
  cfg.pin_bck = I2S_BCLK;
  cfg.pin_ws = I2S_LRC;
  cfg.pin_data = I2S_DIN;
  i2s.begin(cfg);

  a2dp_sink.set_volume(25);

  //delay(500);
  /* ===== BLE ===== */
  BLEDevice::init("HelmetSensor");
  BLEDevice::setMTU(185);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new MyServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  statusChar = service->createCharacteristic(
      STATUS_UUID,
      BLECharacteristic::PROPERTY_NOTIFY);
  statusChar->addDescriptor(new BLE2902());

  service->start();
  server->getAdvertising()->start();

  /* ===== MUTEX ===== */
  gpsMutex = xSemaphoreCreateMutex();
  motionMutex = xSemaphoreCreateMutex();

  /* ===== TASKS ===== */
  xTaskCreatePinnedToCore(gpsTask, "GPSTask", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(motionTask, "MotionTask", 4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(bleTask, "BLETask", 4096, NULL, 1, NULL, 1);
  a2dp_sink.start("Helmet-Audio");
  Serial.println("SMART HELMET SYSTEM READY");
}

void loop() {}