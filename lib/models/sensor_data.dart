import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../utils/constants.dart';

/// IMU sample: acceleration + gyro (gyro zero when not present in payload).
///
/// **Units:** Acceleration in **m/s²** when parsed from MPU6050 or SI CSV.
/// Gyro from MPU int16 is converted to **rad/s**; CSV/JSON values are used as-is.
class SensorData {
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;

  const SensorData({
    required this.ax,
    required this.ay,
    required this.az,
    this.gx = 0,
    this.gy = 0,
    this.gz = 0,
  });

  /// CSV: `"0.12,0.45,9.81"` or six values for accel + gyro.
  factory SensorData.parseCsv(String data) {
    final parts = data
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 3) {
      throw FormatException('CSV needs at least 3 numbers, got ${parts.length}');
    }
    final nums = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v == null) {
        throw FormatException('Not a number: $p');
      }
      nums.add(v);
    }
    return SensorData(
      ax: nums[0],
      ay: nums[1],
      az: nums[2],
      gx: nums.length >= 6 ? nums[3] : 0,
      gy: nums.length >= 6 ? nums[4] : 0,
      gz: nums.length >= 6 ? nums[5] : 0,
    );
  }

  /// JSON object with keys `ax`,`ay`,`az` and optional `gx`,`gy`,`gz` (case-insensitive).
  static SensorData? tryParseJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final m = <String, dynamic>{};
      for (final e in decoded.entries) {
        m[e.key.toString().toLowerCase()] = e.value;
      }
      double? numOf(String k) {
        final v = m[k];
        if (v is num) return v.toDouble();
        return null;
      }

      final ax = numOf('ax');
      final ay = numOf('ay');
      final az = numOf('az');
      if (ax == null || ay == null || az == null) return null;

      return SensorData(
        ax: ax,
        ay: ay,
        az: az,
        gx: numOf('gx') ?? 0,
        gy: numOf('gy') ?? 0,
        gz: numOf('gz') ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// One line of text: JSON object, or comma-separated numbers (not the `SP:…` helmet protocol).
  static SensorData? tryParseTelemetryLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;

    if (t.contains('SP:') || t.contains('AX:') || t.contains('I:') || t.contains('LAT:')) {
      return null;
    }

    if (t.startsWith('{')) {
      return tryParseJson(t);
    }

    if (t.contains(',')) {
      try {
        return SensorData.parseCsv(t);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Simple uint8 triplet (legacy bring-up).
  factory SensorData.fromUint8Triplet(List<int> data) {
    if (data.length < 3) {
      throw ArgumentError('Need at least 3 bytes, got ${data.length}');
    }
    return SensorData(
      ax: data[0].toDouble(),
      ay: data[1].toDouble(),
      az: data[2].toDouble(),
    );
  }

  /// Three little-endian float32 values (12 bytes) — accel only.
  factory SensorData.fromFloat32Le(List<int> data) {
    if (data.length < 12) {
      throw ArgumentError('Need 12 bytes for float32×3, got ${data.length}');
    }
    final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 12)));
    return SensorData(
      ax: bd.getFloat32(0, Endian.little),
      ay: bd.getFloat32(4, Endian.little),
      az: bd.getFloat32(8, Endian.little),
    );
  }

  /// Six little-endian float32 values (24 bytes) — accel + gyro (firmware-defined gyro units).
  factory SensorData.fromFloat32LeSix(List<int> data) {
    if (data.length < 24) {
      throw ArgumentError('Need 24 bytes for float32×6, got ${data.length}');
    }
    final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 24)));
    return SensorData(
      ax: bd.getFloat32(0, Endian.little),
      ay: bd.getFloat32(4, Endian.little),
      az: bd.getFloat32(8, Endian.little),
      gx: bd.getFloat32(12, Endian.little),
      gy: bd.getFloat32(16, Endian.little),
      gz: bd.getFloat32(20, Endian.little),
    );
  }

  /// MPU6050-style packed int16: **accel** then **gyro** (12 bytes).
  /// Accel → m/s²; gyro LSB → rad/s via ±250°/s scale.
  factory SensorData.fromMpu6050AccelGyroInt16Le(List<int> data) {
    if (data.length < 12) {
      throw ArgumentError('Need 12 bytes for MPU int16×6, got ${data.length}');
    }
    final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 12)));
    const accelScale = 9.80665 / Constants.mpu6050AccelLsbPerG;
    const gxRad = pi / (180.0 * Constants.mpu6050GyroLsbPerDegPerS);

    return SensorData(
      ax: bd.getInt16(0, Endian.little) * accelScale,
      ay: bd.getInt16(2, Endian.little) * accelScale,
      az: bd.getInt16(4, Endian.little) * accelScale,
      gx: bd.getInt16(6, Endian.little) * gxRad,
      gy: bd.getInt16(8, Endian.little) * gxRad,
      gz: bd.getInt16(10, Endian.little) * gxRad,
    );
  }

  /// Six bytes: MPU6050 accel int16 only (±2g → m/s²).
  factory SensorData.fromMpu6050AccelOnlyInt16Le(List<int> data) {
    if (data.length < 6) {
      throw ArgumentError('Need 6 bytes for int16×3, got ${data.length}');
    }
    final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 6)));
    const scale = 9.80665 / Constants.mpu6050AccelLsbPerG;
    return SensorData(
      ax: bd.getInt16(0, Endian.little) * scale,
      ay: bd.getInt16(2, Endian.little) * scale,
      az: bd.getInt16(4, Endian.little) * scale,
    );
  }

  /// Generic int16 triplet with custom scale (legacy).
  factory SensorData.fromInt16Le(List<int> data, {double scale = 1.0 / 4096.0 * 9.80665}) {
    if (data.length < 6) {
      throw ArgumentError('Need 6 bytes for int16×3, got ${data.length}');
    }
    final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 6)));
    return SensorData(
      ax: bd.getInt16(0, Endian.little) * scale,
      ay: bd.getInt16(2, Endian.little) * scale,
      az: bd.getInt16(4, Endian.little) * scale,
    );
  }

  /// Best-effort binary parse: float32×6, float32×3, MPU 12-byte, int16×3, uint8×3.
  static SensorData? tryParse(List<int> data) {
    if (data.isEmpty) return null;

    if (data.length >= 24) {
      try {
        final s = SensorData.fromFloat32LeSix(data);
        if (_plausibleAccel(SensorData(ax: s.ax, ay: s.ay, az: s.az))) return s;
      } catch (_) {}
    }

    if (data.length >= 12) {
      try {
        final s = SensorData.fromFloat32Le(data);
        if (_plausibleAccel(s)) return s;
      } catch (_) {}

      try {
        final s = SensorData.fromMpu6050AccelGyroInt16Le(data);
        if (_plausibleAccel(SensorData(ax: s.ax, ay: s.ay, az: s.az))) return s;
      } catch (_) {}
    }

    if (data.length >= 6 && data.length < 12) {
      try {
        final s = SensorData.fromMpu6050AccelOnlyInt16Le(data);
        if (_plausibleAccel(s)) return s;
      } catch (_) {}

      try {
        final s = SensorData.fromInt16Le(data);
        if (_plausibleAccel(s)) return s;
      } catch (_) {}
    }

    if (data.length >= 3) {
      try {
        return SensorData.fromUint8Triplet(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _plausibleAccel(SensorData s) {
    const maxG = 200.0;
    return s.ax.isFinite &&
        s.ay.isFinite &&
        s.az.isFinite &&
        s.ax.abs() < maxG &&
        s.ay.abs() < maxG &&
        s.az.abs() < maxG;
  }

  /// Tilt from vertical (degrees): angle between [a] and world Z when |a| ≈ g.
  double get tiltDegreesFromVertical {
    final g = sqrt(ax * ax + ay * ay + az * az);
    if (g < 1e-6) return 0;
    final cosT = (az / g).clamp(-1.0, 1.0);
    return acos(cosT) * 180 / pi;
  }

  double get rollDegrees => atan2(ay, az) * 180 / pi;

  double get pitchDegrees => atan2(-ax, sqrt(ay * ay + az * az)) * 180 / pi;
}
