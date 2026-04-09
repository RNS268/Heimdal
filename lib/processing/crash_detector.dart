import '../models/sensor_data.dart';
import 'data_processor.dart';

/// Tunable thresholds for [CrashDetector] (tune on real rides / drop tests).
class CrashDetectorConfig {
  /// Impact: ‖a‖ above this (m/s²) counts as a spike (starting point ~2g).
  final double impactThresholdMps2;

  /// Stillness: see [stillnessUsesLinearMagnitude].
  final double stillnessThresholdMps2;

  /// How long stillness must hold after an impact window.
  final Duration stillnessRequiredDuration;

  /// Helmet tipped vs gravity (degrees).
  final double abnormalTiltDegrees;

  /// If true: stillness = `‖a‖ < stillnessThreshold` (linear / gravity-removed data).
  /// If false: stillness = `|‖a‖ − g| < stillnessThreshold` (raw IMU near 1g).
  final bool stillnessUsesLinearMagnitude;

  /// Drop stale impact state if no confirmation within this time.
  final Duration impactPipelineTimeout;

  const CrashDetectorConfig({
    this.impactThresholdMps2 = 20.0,
    this.stillnessThresholdMps2 = 1.5,
    this.stillnessRequiredDuration = const Duration(milliseconds: 2500),
    this.abnormalTiltDegrees = 60.0,
    this.stillnessUsesLinearMagnitude = false,
    this.impactPipelineTimeout = const Duration(seconds: 45),
  });
}

/// Layered crash pipeline: impact → sustained stillness → abnormal tilt.
///
/// Does not fire on impact alone (reduces pothole / shake false positives).
class CrashDetector {
  CrashDetector({CrashDetectorConfig? config})
      : _config = config ?? const CrashDetectorConfig();

  final CrashDetectorConfig _config;

  DateTime? _impactAt;
  DateTime? _stillnessSince;
  bool _latched = false;

  bool get isLatched => _latched;

  void reset() {
    _impactAt = null;
    _stillnessSince = null;
    _latched = false;
  }

  /// Returns **true once** when all layers pass; then [isLatched] until [reset].
  bool evaluate(
    SensorData data, {
    bool deviceCrashFlag = false,
    bool speedDropImpact = false,
  }) {
    if (_latched) return false;

    final total = DataProcessor.totalAccelerationMagnitude(data);
    final dev = DataProcessor.deviationFromGravity(data);
    final tilt = data.tiltDegreesFromVertical;

    final physicalImpact = total > _config.impactThresholdMps2;

    if (physicalImpact) {
      _impactAt = DateTime.now();
      _stillnessSince = null;
    } else if (deviceCrashFlag || speedDropImpact) {
      _impactAt ??= DateTime.now();
    }

    if (_impactAt == null) return false;

    final now = DateTime.now();
    if (now.difference(_impactAt!) > _config.impactPipelineTimeout) {
      reset();
      return false;
    }

    final still = _config.stillnessUsesLinearMagnitude
        ? total < _config.stillnessThresholdMps2
        : dev < _config.stillnessThresholdMps2;

    if (still) {
      _stillnessSince ??= now;
    } else {
      _stillnessSince = null;
    }

    if (_stillnessSince == null) return false;
    if (now.difference(_stillnessSince!) < _config.stillnessRequiredDuration) {
      return false;
    }

    if (tilt <= _config.abnormalTiltDegrees) return false;

    _latched = true;
    return true;
  }
}
