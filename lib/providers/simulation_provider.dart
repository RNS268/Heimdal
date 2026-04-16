import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/helmet_data.dart';

// ─────────────────────────────────────────────
// Simulation State
// ─────────────────────────────────────────────
class SimulationState {
  final bool isRunning;
  final double speed;           // km/h
  final IndicatorState indicator;
  final bool isBraking;
  final bool isCrash;
  final double ax, ay, az;     // m/s²
  final double gx, gy, gz;     // rad/s
  final double latitude;
  final double longitude;
  final double heading;         // degrees
  final double leanAngle;       // degrees
  final int heartRate;           // bpm
  final double battery;          // 0..1
  final double temperature;      // °C
  final double altitude;         // metres
  final String scenario;

  const SimulationState({
    this.isRunning = false,
    this.speed = 0,
    this.indicator = IndicatorState.none,
    this.isBraking = false,
    this.isCrash = false,
    this.ax = 0,
    this.ay = 0,
    this.az = 9.81,
    this.gx = 0,
    this.gy = 0,
    this.gz = 0,
    this.latitude = 17.3850,
    this.longitude = 78.4867,
    this.heading = 0,
    this.leanAngle = 0,
    this.heartRate = 72,
    this.battery = 0.87,
    this.temperature = 32.4,
    this.altitude = 542,
    this.scenario = 'Urban Commute',
  });

  SimulationState copyWith({
    bool? isRunning,
    double? speed,
    IndicatorState? indicator,
    bool? isBraking,
    bool? isCrash,
    double? ax,
    double? ay,
    double? az,
    double? gx,
    double? gy,
    double? gz,
    double? latitude,
    double? longitude,
    double? heading,
    double? leanAngle,
    int? heartRate,
    double? battery,
    double? temperature,
    double? altitude,
    String? scenario,
  }) {
    return SimulationState(
      isRunning: isRunning ?? this.isRunning,
      speed: speed ?? this.speed,
      indicator: indicator ?? this.indicator,
      isBraking: isBraking ?? this.isBraking,
      isCrash: isCrash ?? this.isCrash,
      ax: ax ?? this.ax,
      ay: ay ?? this.ay,
      az: az ?? this.az,
      gx: gx ?? this.gx,
      gy: gy ?? this.gy,
      gz: gz ?? this.gz,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      leanAngle: leanAngle ?? this.leanAngle,
      heartRate: heartRate ?? this.heartRate,
      battery: battery ?? this.battery,
      temperature: temperature ?? this.temperature,
      altitude: altitude ?? this.altitude,
      scenario: scenario ?? this.scenario,
    );
  }

  HelmetDataModel toHelmetData() => HelmetDataModel(
        speed: speed,
        indicator: indicator,
        brake: isBraking,
        crash: isCrash,
        latitude: latitude,
        longitude: longitude,
        blink: BlinkState.off,
        ax: ax,
        ay: ay,
        az: az,
        rawDevData: 'SIM',
        timestamp: DateTime.now(),
      );
}

// ─────────────────────────────────────────────
// Simulation Engine
// ─────────────────────────────────────────────
class SimulationNotifier extends StateNotifier<SimulationState> {
  SimulationNotifier() : super(const SimulationState());

  Timer? _timer;
  final math.Random _rng = math.Random();

  // Route waypoints (road-snapped offsets ~1km radius around start)
  // These are relative lat/lng deltas that trace a roughly square urban block loop
  static const List<List<double>> _routeDeltasLatLng = [
    [0.0000,  0.0000],
    [0.0020,  0.0000],
    [0.0040,  0.0010],
    [0.0060,  0.0030],
    [0.0070,  0.0060],
    [0.0065,  0.0090],
    [0.0050,  0.0110],
    [0.0030,  0.0115],
    [0.0010,  0.0110],
    [-0.0010, 0.0095],
    [-0.0020, 0.0070],
    [-0.0015, 0.0045],
    [0.0000,  0.0020],
    [0.0000,  0.0000],
  ];

  int _waypointIdx = 0;
  double _waypointT = 0.0;        // 0..1 progress between waypoints

  // Physics state
  double _targetSpeed = 0;
  double _currentSpeed = 0;
  double _heading = 45.0;
  int _phase = 0;                 // ride scenario phase counter
  int _tick = 0;
  IndicatorState _indicator = IndicatorState.none;
  int _indicatorTicks = 0;
  int _ticksElapsed = 0;
  bool _crashTriggered = false;

  // Origin
  double _originLat = 17.3850;
  double _originLng = 78.4867;

  // Heart rate drift
  double _hrBase = 72;

  void start({double? lat, double? lng}) {
    if (lat != null) _originLat = lat;
    if (lng != null) _originLng = lng;

    state = state.copyWith(
      isRunning: true,
      latitude: _originLat,
      longitude: _originLng,
    );
    _ticksElapsed = 0;
    _crashTriggered = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), _tick200ms);
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, speed: 0);
  }

  void toggle() {
    if (state.isRunning) {
      stop();
    } else {
      start();
    }
  }

  // Manual indicator control
  void setIndicatorLeft() {
    state = state.copyWith(indicator: IndicatorState.left);
  }

  void setIndicatorRight() {
    state = state.copyWith(indicator: IndicatorState.right);
  }

  void setIndicatorOff() {
    state = state.copyWith(indicator: IndicatorState.none);
  }

  void toggleBrake() {
    state = state.copyWith(isBraking: !state.isBraking);
  }

  // ── Called every 200ms ──────────────────────
  void _tick200ms(Timer _) {
    _tick++;
    _ticksElapsed++;

    // ── TRIGGER CRASH AT 30 SECONDS (150 ticks) ──
    if (_ticksElapsed >= 150 && !_crashTriggered) {
      _crashTriggered = true;
      state = state.copyWith(isCrash: true, speed: 0);
      return;
    }
    if (_crashTriggered) return;

    // ── Scenario phases (each ~10s = 50 ticks) ─
    if (_tick % 50 == 0) {
      _phase = (_phase + 1) % 8;
    }

    // ── Target speed per phase ──────────────────
    final scenarioTargets = [30.0, 55.0, 72.0, 45.0, 0.0, 20.0, 60.0, 35.0];
    _targetSpeed = scenarioTargets[_phase];

    // ── Smooth acceleration / braking ──────────
    final diff = _targetSpeed - _currentSpeed;
    final isBraking = diff < -5;
    if (diff > 0) {
      _currentSpeed = math.min(_currentSpeed + 1.2, _targetSpeed);
    } else {
      _currentSpeed = math.max(_currentSpeed - 2.5, _targetSpeed);
    }
    _currentSpeed = _currentSpeed.clamp(0, 120);

    // ── Indicators: toggle every 20s near turns ─
    _indicatorTicks++;
    if (_indicatorTicks % 100 == 0) {
      _indicator = _rng.nextBool() ? IndicatorState.left : IndicatorState.right;
    } else if (_indicatorTicks % 100 > 15) {
      _indicator = IndicatorState.none;
    }

    // ── Heading drift (simulate bends) ──────────
    final headingDelta = math.sin(_tick * 0.04) * 1.5;
    _heading = (_heading + headingDelta) % 360;

    // ── Lean angle (bank during turns) ──────────
    final leanAngle = math.sin(_tick * 0.04) * 18 + _rng.nextDouble() * 2 - 1;

    // ── IMU simulation ──────────────────────────
    final cosH = math.cos(_heading * math.pi / 180);
    final baseAx = (_currentSpeed > 0 ? 0.3 * cosH : 0) + (_rng.nextDouble() - 0.5) * 0.15;
    final baseAy = leanAngle * 0.12 + (_rng.nextDouble() - 0.5) * 0.10;
    final baseAz = math.sqrt(math.max(0, 9.81 * 9.81 - baseAx * baseAx - baseAy * baseAy));
    final gxVal = headingDelta * 0.02 + (_rng.nextDouble() - 0.5) * 0.005;
    final gyVal = (isBraking ? -0.3 : 0.05) + (_rng.nextDouble() - 0.5) * 0.01;
    final gzVal = headingDelta * 0.05 + (_rng.nextDouble() - 0.5) * 0.02;

    // ── GPS movement along route ─────────────────
    _advanceGPS();

    // ── Heart rate drift with exercise effect ───
    final exerciseHr = _currentSpeed > 50 ? 95 : (_currentSpeed > 20 ? 82 : 72);
    _hrBase += (exerciseHr - _hrBase) * 0.02 + (_rng.nextDouble() - 0.5) * 0.5;
    final hr = _hrBase.round().clamp(55, 120);

    // ── Battery slow drain ──────────────────────
    final battery = (state.battery - 0.000005).clamp(0.1, 1.0);

    // ── Temperature oscillation ─────────────────
    final temp = 32.4 + math.sin(_tick * 0.005) * 1.5 + (_rng.nextDouble() - 0.5) * 0.2;

    state = state.copyWith(
      speed: _currentSpeed,
      indicator: _indicator,
      isBraking: isBraking,
      isCrash: _crashTriggered,
      ax: baseAx,
      ay: baseAy,
      az: baseAz,
      gx: gxVal,
      gy: gyVal,
      gz: gzVal,
      heading: _heading,
      leanAngle: leanAngle,
      heartRate: hr,
      battery: battery,
      temperature: temp,
    );
  }

  void _advanceGPS() {
    final speedMs = _currentSpeed / 3.6; // km/h → m/s
    if (speedMs < 0.5) return;           // stationary

    // Degrees per second (approx 111,000m per degree lat)
    final metersPerTick = speedMs * 0.2;
    const degPerMeterLat = 1.0 / 111000.0;
    final degPerMeterLng = 1.0 / (111000.0 * math.cos(_originLat * math.pi / 180));

    // Move toward next waypoint
    final nextIdx = (_waypointIdx + 1) % _routeDeltasLatLng.length;
    final fromDelta = _routeDeltasLatLng[_waypointIdx];
    final toDelta = _routeDeltasLatLng[nextIdx];

    final fromLat = _originLat + fromDelta[0];
    final fromLng = _originLng + fromDelta[1];
    final toLat = _originLat + toDelta[0];
    final toLng = _originLng + toDelta[1];

    // Distance to next waypoint
    final segDistMeters = math.sqrt(
      math.pow((toLat - fromLat) / degPerMeterLat, 2) +
          math.pow((toLng - fromLng) / degPerMeterLng, 2),
    );

    if (segDistMeters < 1) {
      _waypointIdx = nextIdx;
      _waypointT = 0;
      return;
    }

    final tStep = metersPerTick / segDistMeters;
    _waypointT += tStep;

    if (_waypointT >= 1.0) {
      _waypointT -= 1.0;
      _waypointIdx = nextIdx;
    }

    final t = _waypointT.clamp(0.0, 1.0);
    final lat = fromLat + (toLat - fromLat) * t;
    final lng = fromLng + (toLng - fromLng) * t;

    // Tiny road noise
    const noise = 0.000003;
    state = state.copyWith(
      latitude: lat + (_rng.nextDouble() - 0.5) * noise,
      longitude: lng + (_rng.nextDouble() - 0.5) * noise,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────
final simulationProvider =
    StateNotifierProvider<SimulationNotifier, SimulationState>((ref) {
  return SimulationNotifier();
});

/// Exposes simulation data as a helmet-data stream so screens can optionally
/// use it instead of BLE data.
final simulatedHelmetDataProvider = StreamProvider<HelmetDataModel>((ref) {
  final ctrl = StreamController<HelmetDataModel>.broadcast();
  Timer? t;
  t = Timer.periodic(const Duration(milliseconds: 200), (_) {
    final sim = ref.read(simulationProvider);
    if (sim.isRunning) {
      ctrl.add(sim.toHelmetData());
    }
  });
  ref.onDispose(() {
    t?.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});
