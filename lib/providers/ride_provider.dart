import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RideState {
  final bool isRecording;
  final DateTime? startTime;
  final Duration totalDuration;

  RideState({
    required this.isRecording,
    this.startTime,
    this.totalDuration = Duration.zero,
  });

  RideState copyWith({
    bool? isRecording,
    DateTime? startTime,
    Duration? totalDuration,
  }) {
    return RideState(
      isRecording: isRecording ?? this.isRecording,
      startTime: startTime ?? this.startTime,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  RideNotifier() : super(RideState(isRecording: false));

  void startRide() {
    state = state.copyWith(
      isRecording: true,
      startTime: DateTime.now(),
    );
  }

  void stopRide() {
    if (state.startTime != null) {
      final session = DateTime.now().difference(state.startTime!);
      state = state.copyWith(
        isRecording: false,
        totalDuration: state.totalDuration + session,
        startTime: null,
      );
    } else {
      state = state.copyWith(isRecording: false);
    }
  }
}

final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier();
});

final rideDurationProvider = StreamProvider<Duration>((ref) {
  final ride = ref.watch(rideProvider);
  if (!ride.isRecording || ride.startTime == null) {
    return Stream.value(ride.totalDuration);
  }
  
  return Stream.periodic(const Duration(seconds: 1), (tick) {
    return ride.totalDuration + DateTime.now().difference(ride.startTime!);
  });
});
