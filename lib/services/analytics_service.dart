import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../models/helmet_data.dart';

/// Analytics state model
class AnalyticsState {
  final Duration elapsedTime;
  final double totalDistance;
  final double averageSpeed;
  final int packetCount;
  final double sumSpeed;

  const AnalyticsState({
    this.elapsedTime = Duration.zero,
    this.totalDistance = 0.0,
    this.averageSpeed = 0.0,
    this.packetCount = 0,
    this.sumSpeed = 0.0,
  });

  AnalyticsState copyWith({
    Duration? elapsedTime,
    double? totalDistance,
    double? averageSpeed,
    int? packetCount,
    double? sumSpeed,
  }) {
    return AnalyticsState(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      totalDistance: totalDistance ?? this.totalDistance,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      packetCount: packetCount ?? this.packetCount,
      sumSpeed: sumSpeed ?? this.sumSpeed,
    );
  }

  String get formattedTime {
    final minutes = elapsedTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsedTime.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Service to handle live analytics calculations
class AnalyticsService extends StateNotifier<AnalyticsState> {
  final Ref ref;
  Timer? _analysisTimer;
  DateTime? _startTime;
  DateTime? _lastPacketTime;

  AnalyticsService(this.ref) : super(const AnalyticsState()) {
    _init();
  }

  void _init() {
    // Listen to helmet data
    ref.listen(helmetDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        _processData(next.value!);
      }
    });

    // Listen to connection state to start/stop timer
    ref.listen(bleConnectionStateProvider, (previous, next) {
      if (next.value == BleConnectionState.ready ||
          next.value == BleConnectionState.connected) {
        _startTimer();
      } else if (next.value == BleConnectionState.disconnected) {
        _stopTimer();
        reset(); // Reset analytics on disconnect
      }
    });
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        state = state.copyWith(
          elapsedTime: DateTime.now().difference(_startTime!),
        );
      }
    });
  }

  void _stopTimer() {
    _analysisTimer?.cancel();
  }

  void _processData(HelmetDataModel data) {
    _lastPacketTime ??= DateTime.now();
    final now = DateTime.now();
    final deltaTimeHours = now.difference(_lastPacketTime!).inMilliseconds / 3600000.0;
    
    // Update distance: distance += (speed km/h * time hours)
    final newDistance = state.totalDistance + (data.speed * deltaTimeHours);
    
    // Update average speed
    final newSumSpeed = state.sumSpeed + data.speed;
    final newPacketCount = state.packetCount + 1;
    final newAvgSpeed = newSumSpeed / newPacketCount;

    state = state.copyWith(
      totalDistance: newDistance,
      sumSpeed: newSumSpeed,
      packetCount: newPacketCount,
      averageSpeed: newAvgSpeed,
    );

    _lastPacketTime = now;
  }

  void reset() {
    _startTime = null;
    _lastPacketTime = null;
    state = const AnalyticsState();
  }
}

/// Provider for analytics service
final analyticsProvider = StateNotifierProvider<AnalyticsService, AnalyticsState>((ref) {
  return AnalyticsService(ref);
});
