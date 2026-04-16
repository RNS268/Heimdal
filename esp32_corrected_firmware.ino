/*************************************************
   SMART HELMET FINAL PRODUCT FIRMWARE - CORRECTED
*************************************************/

#include <Arduino.h>
#include <Wire.h>
#include <TinyGPSPlus.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <NimBLEDevice.h>
#include <NimBLEServer.h>
#include <NimBLEUtils.h>
// For BLE TX power enums on ESP32 core
#include <esp_bt.h>
#include <driver/gpio.h>

/* ================= PIN DEFINITIONS ================= */

//LED Lights
#define LED_LEFT   32
#define LED_RIGHT  33
#define LED_BRAKE  27
// Set false during bring-up on ESP32-S3 to isolate GPIO/pin conflicts.
#define ENABLE_HELMET_LEDS false

// GPS
#define GPS_RX      16
#define GPS_TX      17
#define GPS_BAUD    9600

// MPU I2C
// ESP32-S3 note:
// Avoid GPIO19/20 for sensor I2C on many S3 boards (USB D-/D+), it can cause instability/resets.
// Use board-safe I2C pins; update these to match your physical wiring.
#define I2C_SDA     8
#define I2C_SCL     9

/* ================= CRASH PARAMETERS ================= */

#define IMPACT_THRESHOLD        7.0
#define SPEED_DROP_THRESHOLD    10.0

/* ================= BLE UUID ================= */

#define SERVICE_UUID  "12345678-1234-1234-1234-1234567890ab"
#define STATUS_UUID   "44444444-4444-4444-4444-444444444444"

/* ===================================================== */

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
Adafruit_MPU6050 mpu;

/* ================= BLE ================= */

BLECharacteristic *statusChar;
NimBLEServer *pServer; // <-- Global server for status checking
bool deviceConnected = false;
volatile uint32_t lastConnectMs = 0;

class MyServerCallbacks: public NimBLEServerCallbacks {
public: // <-- CRITICAL FIX: Make public
  void onConnect(NimBLEServer* pServer) { 
    deviceConnected = true; 
    lastConnectMs = millis();
    Serial.println(">>> BLE Client Connected! <<<");
  }
  void onConnect(NimBLEServer* pServer, ble_gap_conn_desc* desc) {
    deviceConnected = true;
    lastConnectMs = millis();
    Serial.println(">>> BLE Client Connected (GAP)! <<<");
  }
  void onDisconnect(NimBLEServer* pServer) { 
    deviceConnected = false; 
    Serial.println(">>> BLE Client Disconnected <<<");
    NimBLEDevice::getAdvertising()->start();
  }
};

class MyCharacteristicCallbacks: public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
      String cmd = String(value.c_str());
      Serial.print("BLE CMD RECEIVED: "); Serial.println(cmd);
      
      if (cmd.startsWith("I:L")) {
        motion.indicator = IND_LEFT;
      } else if (cmd.startsWith("I:R")) {
        motion.indicator = IND_RIGHT;
      } else if (cmd.startsWith("I:NONE")) {
        motion.indicator = IND_NONE;
      } else if (cmd.startsWith("B:1")) {
        motion.brake = true;
      } else if (cmd.startsWith("B:0")) {
        motion.brake = false;
      }
    }
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

/* =====================================================
                        TASKS
===================================================== */

static bool initOutputPinSafe(int pin, const char* label) {
  if (pin < 0) {
    Serial.print("[GPIO] Skipping "); Serial.print(label); Serial.println(" (pin < 0)");
    return false;
  }
  if (!GPIO_IS_VALID_OUTPUT_GPIO((gpio_num_t)pin)) {
    Serial.print("[GPIO] Invalid output pin for "); Serial.print(label);
    Serial.print(": "); Serial.println(pin);
    return false;
  }
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
  Serial.print("[GPIO] OK "); Serial.print(label); Serial.print(" -> GPIO"); Serial.println(pin);
  return true;
}

void gpsTask(void *parameter) {
  while (true) {
    while (gpsSerial.available()) {
      gps.encode(gpsSerial.read());
    }

    if (gps.location.isUpdated()) {
      currentGPS.lat = gps.location.lat();
      currentGPS.lng = gps.location.lng();
      currentGPS.speed = gps.speed.kmph();
      currentGPS.altitude = gps.altitude.meters();
      currentGPS.satellites = gps.satellites.value();
    }
    vTaskDelay(100 / portTICK_PERIOD_MS);
  }
}

void motionTask(void *parameter) {

  static float lastSpeed = 0;

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
    if (roll > 15) {
      ind = IND_RIGHT;
    } else if (roll < -15) {
      ind = IND_LEFT;
    }


    bool brake = (pitch < 35);
    if(millis() - lastBlink > 500){
    blinkState = !blinkState;
    lastBlink = millis();
}


if (ENABLE_HELMET_LEDS) {
  if (!blinkState) {
    digitalWrite(LED_RIGHT, LOW);
    digitalWrite(LED_LEFT, LOW);
  }
  if (motion.indicator == IND_LEFT && blinkState) {
    digitalWrite(LED_LEFT, HIGH);
    digitalWrite(LED_RIGHT, LOW);
  } else if (motion.indicator == IND_RIGHT && blinkState) {
    digitalWrite(LED_RIGHT, HIGH);
    digitalWrite(LED_LEFT, LOW);
  }
}


if (ENABLE_HELMET_LEDS) {
  if (motion.brake) {
    digitalWrite(LED_BRAKE, HIGH);
  } else {
    digitalWrite(LED_BRAKE, LOW);
  }
}

CrashState crashState = CRASH_IDLE;

bool highImpact = impact > IMPACT_THRESHOLD;
bool suddenStop = (lastSpeed - speedNow) > SPEED_DROP_THRESHOLD;

lastSpeed = speedNow;

if (highImpact) {
  crashState = CRASH_CONFIRMED;
} else if (suddenStop) {
  crashState = CRASH_POSSIBLE;
}

    if (xSemaphoreTake(motionMutex, pdMS_TO_TICKS(100))) {
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

      // Send BLE data directly if ANYONE is connected (bypass callback bugs)
      if (pServer != NULL && pServer->getConnectedCount() > 0 && statusChar != NULL) {
        String indStr = (ind == IND_LEFT) ? "L" : (ind == IND_RIGHT ? "R" : "NONE");
        String crashStr = (crashState == CRASH_CONFIRMED) ? "ACCT" : "NO";
        
        String status = "SP:" + String(currentGPS.speed) +
                       ",I:" + indStr +
                       ",B:" + String(motion.brake ? 1 : 0) +
                       ",C:" + crashStr +
                       ",LAT:" + String(currentGPS.lat) +
                       ",LOG:" + String(currentGPS.lng) +
                       ",AX:" + String(ax) +
                       ",AY:" + String(ay) +
                       ",AZ:" + String(az) +
                       "\n";
        
        statusChar->setValue(status.c_str());
        statusChar->notify();
        
        // Print every 10th packet to serial to avoid flooding but show life
        static int bleCounter = 0;
        if (bleCounter++ % 10 == 0) {
          Serial.print("BLE DATA LIVE -> "); Serial.println(status);
        }
      }
      
      xSemaphoreGive(motionMutex);
    } else {
      Serial.println("⚠️ MotionTask: Failed to get mutex");
    }
    vTaskDelay(pdMS_TO_TICKS(100)); // Send data 10 times per second
  }
}

// REDUNDANT TASK REMOVED - LOGIC MOVED TO loop()


/* =====================================================
                        SETUP
===================================================== */

void setup() {
  // NOTE:
  // Full task-WDT deinit can destabilize some ESP32-S3 Arduino core builds.
  // Keep WDT active and keep setup progressing with short delays instead.

  Serial.begin(115200);
  delay(500); // Let serial settle
  Serial.println("=== SMART HELMET BOOT ===");
  Serial.println("[BOOT] 1/7: Serial OK");

  /* ===== I2C + MPU6050 ===== */
  Wire.begin(I2C_SDA, I2C_SCL);
  Serial.println("Wire initialized");
  Serial.println("[BOOT] 2/7: I2C OK");

  bool mpuOk = false;
  if (mpu.begin()) {
    Serial.println("MPU6050 OK at 0x68");
    mpuOk = true;
  } else if (mpu.begin(0x69, &Wire)) {
    Serial.println("MPU6050 OK at 0x69");
    mpuOk = true;
  }
  
  if (!mpuOk) {
    Serial.println("⚠️ MPU6050 FAILED — check wiring. Continuing for debug...");
  } else {
    mpu.setAccelerometerRange(MPU6050_RANGE_2_G);
    mpu.setGyroRange(MPU6050_RANGE_250_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    Serial.println("MPU6050 configured");
  }
  Serial.println("[BOOT] 2/7: Sensors Check Finished");
  delay(20);

  /* ===== LEDs ===== */
  if (ENABLE_HELMET_LEDS) {
    initOutputPinSafe(LED_LEFT, "LED_LEFT");
    initOutputPinSafe(LED_RIGHT, "LED_RIGHT");
    initOutputPinSafe(LED_BRAKE, "LED_BRAKE");
  } else {
    Serial.println("[GPIO] LED outputs disabled for bring-up");
  }
  Serial.println("LEDs initialized");
  Serial.println("[BOOT] 4/7: LEDs OK");
  delay(20);

  /* ===== GPS ===== */
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println("GPS serial initialized");
  Serial.println("[BOOT] 5/7: GPS UART OK");
  delay(20);

  /* ===== BLE ===== */
  Serial.println("BLE init...");
  NimBLEDevice::init("HelmetSensor");
  Serial.println("NimBLEDevice::init done");
  Serial.println("[BOOT] 6/7: BLE stack OK");

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  Serial.println("Server created");

  // Allow automatic MTU negotiation instead of forcing 185
  Serial.println("MTU auto-negotiation enabled");

  // Robustness: increase TX power to improve connection reliability
  // (helps when scan works but connect fails/drops due to weak link)
  #if defined(ESP_BLE_PWR_TYPE_ADV)
    NimBLEDevice::setPower(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_ADV);
    NimBLEDevice::setPower(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_SCAN);
    NimBLEDevice::setPower(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_CONN);
  #else
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);
  #endif
  Serial.println("BLE TX power set");

  NimBLEService *service = pServer->createService(SERVICE_UUID);
  statusChar = service->createCharacteristic(STATUS_UUID,
                 NIMBLE_PROPERTY::READ | 
                 NIMBLE_PROPERTY::NOTIFY | 
                 NIMBLE_PROPERTY::WRITE |
                 NIMBLE_PROPERTY::WRITE_NR);
  statusChar->setCallbacks(new MyCharacteristicCallbacks());
  service->start();
  Serial.println("Service started");

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  
  // Create advertisement data
  NimBLEAdvertisementData advData;
  advData.setFlags(0x06); // General Discoverable | BR/EDR Not Supported
  
  // Shortened name "Helmet" (6 bytes) + UUID (16 bytes) + Flags (3 bytes) fits in 31-byte limit
  advData.setName("Helmet");
  advData.setCompleteServices(NimBLEUUID(SERVICE_UUID));
  pAdvertising->setAdvertisementData(advData);

  // Still keep it in scan response as a backup
  NimBLEAdvertisementData scanData;
  scanData.setName("Helmet");
  pAdvertising->setScanResponseData(scanData);

  pAdvertising->start();
  Serial.println("BLE advertising as 'Helmet'");
  Serial.print("BLE Service UUID: "); Serial.println(SERVICE_UUID);
  Serial.print("BLE Char UUID: "); Serial.println(STATUS_UUID);
  Serial.println("[BOOT] 7/7: Advertising started");

  /* ===== MUTEX ===== */
  gpsMutex = xSemaphoreCreateMutex();
  motionMutex = xSemaphoreCreateMutex();
  Serial.println("Mutexes created");

  xTaskCreatePinnedToCore(gpsTask, "GPSTask", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(motionTask, "MotionTask", 4096, NULL, 2, NULL, 1);
  Serial.println("=== SYSTEM READY ===");
}

void loop() {
  // Loop is now mostly empty, logic moved to motionTask for reliability
  delay(1000);
}