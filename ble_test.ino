/*
  BLE Test Sketch for ESP32
  Simple advertising of a service to verify Bluetooth hardware and discoverability.
*/

#include <NimBLEDevice.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "44444444-4444-4444-4444-444444444444"

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Starting BLE Test...");

  NimBLEDevice::init("BLE_TEST_DEVICE");
  
  // Power setup - ensure enough signal
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  NimBLEServer *pServer = NimBLEDevice::createServer();
  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  
  NimBLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         NIMBLE_PROPERTY::READ |
                                         NIMBLE_PROPERTY::WRITE |
                                         NIMBLE_PROPERTY::NOTIFY
                                       );

  pCharacteristic->setValue("Hello World");
  pService->start();

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
  
  // Create advertisement data
  NimBLEAdvertisementData advData;
  advData.setFlags(0x06); // General Discoverable | BR/EDR Not Supported
  advData.setCompleteServices(NimBLEUUID(SERVICE_UUID));
  pAdvertising->setAdvertisementData(advData);

  // Create scan response data (contains the name)
  NimBLEAdvertisementData scanData;
  scanData.setName("BLE_TEST_DEVICE");
  pAdvertising->setScanResponseData(scanData);

  pAdvertising->start();
  
  Serial.println("Advertising started as 'BLE_TEST_DEVICE'");
  Serial.print("Service UUID: "); Serial.println(SERVICE_UUID);
}

void loop() {
  Serial.println("Still advertising...");
  delay(5000);
}
