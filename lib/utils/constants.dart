/// BLE communication constants - Synced with ESP32 Firmware
abstract final class Constants {
  // ============================================================================
  // BLE Configuration (from ESP32 firmware)
  // ============================================================================
  static const String helmetDeviceName = 'Helmet';
  static const String helmetServiceUuid =
      '12345678-1234-1234-1234-1234567890ab';
  static const String helmetCharacteristicUuid =
      '44444444-4444-4444-4444-444444444444';

  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectMaxDelay = Duration(seconds: 30);
  static const Duration bleNotificationInterval = Duration(milliseconds: 500);

  static const int maxReconnectAttempts = 5;
  static const int maxRawPacketBuffer = 50;
  static const int bleMtu = 517;

  // ============================================================================
  // Crash Detection Parameters (from ESP32 firmware)
  // ============================================================================
  static const double impactThreshold = 7.0; // g-force
  static const double speedDropThreshold = 10.0; // km/h
  static const double tiltCrashAngle = 60.0; // degrees
  static const int crashConfirmTimeMs = 100;

  // ============================================================================
  // Indicator Thresholds (from ESP32 motion logic)
  // ============================================================================
  static const double leftTurnThreshold = -15.0; // roll angle degrees
  static const double rightTurnThreshold = 15.0; // roll angle degrees
  static const double brakeThreshold = 35.0; // pitch angle degrees
  static const int blinkIntervalMs = 500; // LED blink rate

  // ============================================================================
  // Speed Detection
  // ============================================================================
  static const double suddenDecelerationThreshold = 30.0;
  static const double movingSpeedThreshold = 2.0;

  // ============================================================================
  // MPU6050 Sensor Calibration (±2g accel, ±250°/s gyro)
  // ============================================================================
  static const double mpu6050AccelLsbPerG = 16384.0;
  static const double mpu6050GyroLsbPerDegPerS = 131.0;

  // ============================================================================
  // Gravity Reference (for angle calculations)
  // ============================================================================
  static const double earthGravity = 9.81; // m/s²

  // ============================================================================
  // RTOS Task Configuration (for reference/testing)
  // ============================================================================
  static const int gpsTaskPriority = 1;
  static const int motionTaskPriority = 2; // Higher priority
  static const int bleTaskPriority = 1;
  static const int taskStackSize = 4096;
  static const int gpsTaskIntervalMs = 100;
  static const int motionTaskIntervalMs = 50;
  static const int bleTaskIntervalMs = 500;
}
