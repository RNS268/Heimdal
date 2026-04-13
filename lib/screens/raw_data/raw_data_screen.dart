import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/ble_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../models/sensor_data.dart';
import '../../processing/data_processor.dart';
import '../../services/settings_service.dart';

class RawDataScreen extends ConsumerStatefulWidget {
  const RawDataScreen({super.key});

  @override
  ConsumerState<RawDataScreen> createState() => _RawDataScreenState();
}

class _RawDataScreenState extends ConsumerState<RawDataScreen> {
  @override
  Widget build(BuildContext context) {
    final helmetData = ref.watch(helmetDataStreamProvider);
    final data = helmetData.valueOrNull;
    final sensorAsync = ref.watch(sensorDataStreamProvider);
    final rawAsync = ref.watch(rawBleDataProvider);
    final bleState = ref.watch(bleConnectionStateProvider);
    final settings = ref.watch(settingsProvider);
    final sim = ref.watch(simulationProvider);
    final sensor = sensorAsync.valueOrNull;

    // Effective sensor data: prefer simulation when active
    final SensorData? accel = sim.isRunning
        ? SensorData(
            ax: sim.ax, ay: sim.ay, az: sim.az,
            gx: sim.gx, gy: sim.gy, gz: sim.gz,
          )
        : (sensor ??
            (data != null
                ? SensorData(ax: data.ax, ay: data.ay, az: data.az)
                : null));
    final totalA = accel != null ? DataProcessor.totalAccelerationMagnitude(accel) : null;
    final tiltAxAz = accel != null ? DataProcessor.tiltAxAzDegrees(accel) : null;
    final motion = accel != null ? DataProcessor.motionStatusGravityReferenced(accel) : null;
    final isImperial = settings.units == 'Imperial (mph)';

    // Speed / brake / collision: prefer simulation
    final double effectiveSpeed = sim.isRunning ? sim.speed : 0.0;
    final bool effectiveBraking = sim.isRunning ? sim.isBraking : false;
    final bool effectiveCollision = sim.isRunning ? sim.isCrash : false;
    final double effectiveLat = sim.isRunning
        ? sim.latitude
        : (data != null && data.latitude != 0 ? data.latitude : 0);
    final double effectiveLng = sim.isRunning
        ? sim.longitude
        : (data != null && data.longitude != 0 ? data.longitude : 0);

    final speed = isImperial ? effectiveSpeed * 0.621371 : effectiveSpeed;
    final speedUnit = isImperial ? 'mph' : 'km/h';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                children: [
                  _buildSequentialItem(
              'BLE STATUS',
              sim.isRunning ? 'SIMULATING (VIRTUAL)' : _bleStatusLabel(bleState.valueOrNull),
              Icons.bluetooth,
              color: sim.isRunning
                  ? const Color(0xFF00BFA5)
                  : _bleStatusColor(bleState.valueOrNull),
            ),
                  _buildSequentialItem(
                    'ACCELERATION (AX / AY / AZ) m/s²',
                    accel != null
                        ? '${accel.ax.toStringAsFixed(2)} / ${accel.ay.toStringAsFixed(2)} / ${accel.az.toStringAsFixed(2)}'
                        : '—',
                    Icons.vibration,
                  ),
                  _buildSequentialItem(
                    'TOTAL ‖A‖ (IMPACT BASE)',
                    totalA != null ? '${totalA.toStringAsFixed(2)} m/s²' : '—',
                    Icons.bolt,
                  ),
                  _buildSequentialItem(
                    'GYRO (GX / GY / GZ) rad/s',
                    accel != null
                        ? '${accel.gx.toStringAsFixed(3)} / ${accel.gy.toStringAsFixed(3)} / ${accel.gz.toStringAsFixed(3)}'
                        : '—',
                    Icons.rotate_right,
                  ),
                  _buildSequentialItem(
                    'TILT atan2(AX, AZ)',
                    tiltAxAz != null ? '${tiltAxAz.toStringAsFixed(1)}°' : '—',
                    Icons.rotate_right,
                  ),
                  _buildSequentialItem(
                    'TILT (FROM VERTICAL)',
                    accel != null
                        ? '${accel.tiltDegreesFromVertical.toStringAsFixed(1)}°'
                        : '—',
                    Icons.screen_rotation,
                  ),
                  _buildSequentialItem(
                    'MOTION (GRAVITY-REF)',
                    motion ?? '—',
                    Icons.directions_run,
                  ),
                  _buildSequentialItem(
                    'MOTION (LINEAR-ONLY PIPELINE)',
                    accel != null
                        ? DataProcessor.motionStatusLinear(accel)
                        : '—',
                    Icons.linear_scale,
                  ),
                  _buildSequentialItem(
                    'RAW BLE BYTES (LAST NOTIFY)',
                    rawAsync.when(
                      data: (bytes) => _hexPreview(bytes),
                      loading: () => 'Waiting…',
                      error: (e, _) => '—',
                    ),
                    Icons.memory,
                  ),
                  _buildSequentialItem(
                    'SYSTEM TIME',
                    '00:00',
                    Icons.access_time,
                    color: AppColors.secondary,
                  ),
                  _buildSequentialItem(
                    'VELOCITY',
                    '${speed.toStringAsFixed(1)} $speedUnit',
                    Icons.speed,
                  ),
                  _buildSequentialItem(
                    'BRAKE STATUS',
                    effectiveBraking ? 'ACTIVE' : 'INACTIVE',
                    Icons.radio_button_checked,
                    color: effectiveBraking
                        ? Colors.orange
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  _buildSequentialItem(
                    'COLLISION STATUS',
                    effectiveCollision ? 'COLLISION DETECTED' : 'NORMAL',
                    Icons.security,
                    color: effectiveCollision ? Colors.red : Colors.green,
                  ),
                  _buildSequentialItem(
                    'LATITUDE',
                    effectiveLat != 0
                        ? '${effectiveLat.toStringAsFixed(4)}° N'
                        : 'No GPS Signal',
                    Icons.north_east,
                  ),
                  _buildSequentialItem(
                    'LONGITUDE',
                    effectiveLng != 0
                        ? '${effectiveLng.toStringAsFixed(4)}° E'
                        : 'No GPS Signal',
                    Icons.south_east,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'DEBUG LOGS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLogsSection([]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bleStatusLabel(BleConnectionState? s) {
    return switch (s) {
      BleConnectionState.ready => 'CONNECTED — READY',
      BleConnectionState.connected => 'CONNECTED',
      BleConnectionState.connecting => 'CONNECTING…',
      BleConnectionState.verifying => 'VERIFYING SERVICES…',
      BleConnectionState.scanning => 'SCANNING…',
      BleConnectionState.wrongDevice => 'WRONG DEVICE (UUID)',
      BleConnectionState.error => 'ERROR',
      BleConnectionState.disconnected || null => 'DISCONNECTED',
    };
  }

  Color _bleStatusColor(BleConnectionState? s) {
    return switch (s) {
      BleConnectionState.ready => AppColors.secondary,
      BleConnectionState.connected => AppColors.secondary,
      BleConnectionState.wrongDevice || BleConnectionState.error => Colors.redAccent,
      BleConnectionState.disconnected || null => AppColors.outline,
      _ => AppColors.primary,
    };
  }

  String _hexPreview(List<int> bytes) {
    if (bytes.isEmpty) return '—';
    const maxBytes = 24;
    final slice = bytes.length > maxBytes ? bytes.sublist(0, maxBytes) : bytes;
    final hex = slice
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    if (bytes.length > maxBytes) {
      return '$hex … (+${bytes.length - maxBytes} B)';
    }
    return hex;
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TELEMETRY HUD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequentialItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection(List<String> logs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: logs.isEmpty
            ? [
                const Text(
                  'Waiting for system logs...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ]
            : logs
                  .map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: AppColors.outline,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}
