import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../models/helmet_data.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import '../services/background_service.dart';

export '../services/ble_service.dart' show BleConnectionState, BleService;

/// Riverpod wiring: BLE → parser → streams → UI.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

final bleConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.connectionState;
});

final helmetDataStreamProvider = StreamProvider<HelmetDataModel>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.dataStream;
});

/// Latest raw notify payload (bytes) for bring-up and debugging.
final rawBleDataProvider = StreamProvider<List<int>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.rawDataStream;
});

/// Parsed [SensorData] when frames are binary or from text telemetry (AX/AY/AZ).
final sensorDataStreamProvider = StreamProvider<SensorData>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.sensorDataStream;
});

final serialMonitorStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.serialMonitorStream;
});

final backgroundSerialDataProvider = StreamProvider<String>((ref) {
  return serialDataStream;
});

final scanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.scanResults;
});

final devicesProvider = StreamProvider<List<DeviceModel>>((ref) {
  final ble = ref.read(bleServiceProvider);
  return ble.scanDevices();
});

final validDevicesProvider = Provider<List<DeviceModel>>((ref) {
  final devicesAsync = ref.watch(devicesProvider);

  return devicesAsync.when(
    data: (devices) =>
        devices.where((d) => d.capabilities.isNotEmpty).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
