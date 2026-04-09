import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sensor_data.dart';
import '../processing/crash_detector.dart';

/// Orchestrates layered IMU crash detection + emergency countdown state.
class CrashDetectionService {
  /// Cancel window before SOS is considered confirmed (matches [CrashScreen] UI).
  static const Duration confirmationDelay = Duration(seconds: 10);

  final _crashController = StreamController<bool>.broadcast();
  Timer? _confirmationTimer;
  bool _isCrashConfirmed = false;
  bool _alertDispatched = false;

  final CrashDetector _detector = CrashDetector();

  Stream<bool> get crashStream => _crashController.stream;
  bool get isCrashConfirmed => _isCrashConfirmed;

  /// Layered IMU crash detection + optional BLE speed / device flag as **impact** cues only.
  void checkCrash({
    required bool crashFlag,
    required double currentSpeed,
    required double previousSpeed,
    required double ax,
    required double ay,
    required double az,
  }) {
    final sensor = SensorData(ax: ax, ay: ay, az: az);
    final speedDropImpact =
        (previousSpeed - currentSpeed) > 30 && previousSpeed > 10;

    if (_detector.evaluate(
          sensor,
          deviceCrashFlag: crashFlag,
          speedDropImpact: speedDropImpact,
        )) {
      _triggerCrashDetected();
    }
  }

  void _triggerCrashDetected() {
    if (_alertDispatched) return;

    _alertDispatched = true;
    _crashController.add(true);
    _startConfirmationTimer();
  }

  void _startConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(confirmationDelay, () {
      _isCrashConfirmed = true;
    });
  }

  void cancelCrashAlert() {
    _confirmationTimer?.cancel();
    _isCrashConfirmed = false;
    _alertDispatched = false;
    _detector.reset();
    _crashController.add(false);
  }

  void confirmCrash() {
    _isCrashConfirmed = true;
  }

  void reset() {
    _confirmationTimer?.cancel();
    _isCrashConfirmed = false;
    _alertDispatched = false;
    _detector.reset();
    _crashController.add(false);
  }

  void dispose() {
    _confirmationTimer?.cancel();
    _crashController.close();
  }
}

final crashDetectionServiceProvider = Provider<CrashDetectionService>((ref) {
  final service = CrashDetectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final crashDetectedProvider = StateProvider<bool>((ref) => false);

final previousSpeedProvider = StateProvider<double>((ref) => 0.0);
