import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../models/helmet_data.dart';
import '../models/sensor_data.dart';
import '../processing/data_processor.dart';

/// Sensor fusion state for advanced telemetry
class SensorFusionState {
  final double currentSpeed;
  final double lastSpeed;
  final bool isBraking;
  final bool isCollision;
  final double impactForce;
  final DateTime systemTime;
  final List<String> logs;

  const SensorFusionState({
    this.currentSpeed = 0.0,
    this.lastSpeed = 0.0,
    this.isBraking = false,
    this.isCollision = false,
    this.impactForce = 0.0,
    required this.systemTime,
    this.logs = const [],
  });

  SensorFusionState copyWith({
    double? currentSpeed,
    double? lastSpeed,
    bool? isBraking,
    bool? isCollision,
    double? impactForce,
    DateTime? systemTime,
    List<String>? logs,
  }) {
    return SensorFusionState(
      currentSpeed: currentSpeed ?? this.currentSpeed,
      lastSpeed: lastSpeed ?? this.lastSpeed,
      isBraking: isBraking ?? this.isBraking,
      isCollision: isCollision ?? this.isCollision,
      impactForce: impactForce ?? this.impactForce,
      systemTime: systemTime ?? this.systemTime,
      logs: logs ?? this.logs,
    );
  }

  String get formattedTime {
    return "${systemTime.hour.toString().padLeft(2, '0')}:${systemTime.minute.toString().padLeft(2, '0')}:${systemTime.second.toString().padLeft(2, '0')}";
  }
}

/// Service to compute intelligent sensor data locally
class SensorFusionService extends StateNotifier<SensorFusionState> {
  final Ref ref;
  Timer? _clockTimer;

  SensorFusionService(this.ref)
    : super(SensorFusionState(systemTime: DateTime.now(), logs: const [])) {
    _init();
  }

  void _init() {
    // 1. Update clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(systemTime: DateTime.now());
    });

    // 2. Listen to BLE data for sensor fusion
    ref.listen(helmetDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        _processSensorData(next.value!);
      }
    });
  }

  void _processSensorData(HelmetDataModel data) {
    final now = DateTime.now();
    final currentSpeed = data.speed;
    final lastSpeed = state.currentSpeed;

    // A. BRAKE LOGIC
    bool calculatedBrake = (lastSpeed - currentSpeed) > 10.0;

    // B. COLLISION LOGIC
    final mag = DataProcessor.totalAccelerationMagnitude(
      SensorData(ax: data.ax, ay: data.ay, az: data.az),
    );
    final impact = (mag - 9.81).abs();

    final suddenStop = (lastSpeed - currentSpeed) > 10.0;
    final isCollision = impact > 7.0 && suddenStop;

    // C. LOGGING
    final logTimestamp =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final logEntry =
        "[$logTimestamp] AX:${data.ax.toStringAsFixed(2)} AY:${data.ay.toStringAsFixed(2)} AZ:${data.az.toStringAsFixed(2)} MAG:${(mag - 9.81).abs().toStringAsFixed(2)}";

    final newLogs = [logEntry, ...state.logs];
    if (newLogs.length > 15) newLogs.removeLast();

    state = state.copyWith(
      lastSpeed: lastSpeed,
      currentSpeed: currentSpeed,
      isBraking: calculatedBrake,
      isCollision: isCollision,
      impactForce: impact,
      logs: newLogs,
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}

/// Provider for sensor fusion logic
final sensorFusionProvider =
    StateNotifierProvider<SensorFusionService, SensorFusionState>((ref) {
      return SensorFusionService(ref);
    });
