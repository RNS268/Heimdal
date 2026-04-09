import 'dart:math';

import '../models/sensor_data.dart';

/// Physics helpers for IMU samples — keep UI and BLE parsing free of math.
abstract final class DataProcessor {
  /// Total acceleration magnitude sqrt(ax²+ay²+az²) (same units as [SensorData] components).
  static double totalAccelerationMagnitude(SensorData d) {
    return sqrt(d.ax * d.ax + d.ay * d.ay + d.az * d.az);
  }

  /// Tilt in degrees as specified for rider orientation: `atan2(ax, az)` in degrees.
  static double tiltAxAzDegrees(SensorData d) {
    return atan2(d.ax, d.az) * 180 / pi;
  }

  /// |‖a‖ − g| with default \(g\) in m/s² — small when the helmet is steady (gravity-dominated).
  static double deviationFromGravity(
    SensorData d, {
    double referenceGMps2 = 9.80665,
  }) {
    return (totalAccelerationMagnitude(d) - referenceGMps2).abs();
  }

  /// **IMU with gravity** (typical MPU6050 accel in m/s²): steady ≈ ‖a‖ ≈ 9.8 m/s².
  static String motionStatusGravityReferenced(SensorData d) {
    if (deviationFromGravity(d) < 0.8) return 'Idle';
    return 'Moving';
  }

  /// Use when firmware sends **linear** acceleration with gravity already removed (m/s²).
  static String motionStatusLinear(SensorData d) {
    return totalAccelerationMagnitude(d) < 0.5 ? 'Idle' : 'Moving';
  }
}
