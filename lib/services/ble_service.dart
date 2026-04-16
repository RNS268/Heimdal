/// BLE communication service for ESP32 helmet sensor connection
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_model.dart';
import '../models/helmet_data.dart';
import '../models/sensor_data.dart';
import '../utils/constants.dart';
import '../utils/parser.dart';

/// Connection state enum for BLE device
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  verifying,
  ready,
  error,
  wrongDevice,
}

/// BLE Service for managing Bluetooth Low Energy connection to helmet
class BleService {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final _dataController = StreamController<HelmetDataModel>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final _rawBytesController = StreamController<List<int>>.broadcast();
  final _sensorDataController = StreamController<SensorData>.broadcast();

  Stream<BleConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<HelmetDataModel> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  /// Every notify payload as raw bytes (for debugging and alternate parsers).
  Stream<List<int>> get rawDataStream => _rawBytesController.stream;

  /// Parsed accelerometer samples when firmware sends binary (3 / 6 / 12-byte frames).
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  Future<void> startScan() async {
    _connectionStateController.add(BleConnectionState.scanning);

    try {
      if (await FlutterBluePlus.isSupported == false) return;
      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        final locationStatus = await Permission.locationWhenInUse.request();

        if (!scanStatus.isGranted || !connectStatus.isGranted || !locationStatus.isGranted) {
          _connectionStateController.add(BleConnectionState.error);
          return;
        }
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      _connectionStateController.add(BleConnectionState.error);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<DeviceModel>> scanDevices() async* {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    yield* FlutterBluePlus.scanResults.map((results) {
      return results.map((r) {
        final deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : (r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : "Unknown Device");
            
        return DeviceModel(
          name: deviceName,
          isConnected: false,
          capabilities: ["telemetry"], // placeholder
        );
      }).toList();
    });
  }

  /// Alias for bring-up docs / clarity (`connect` is the canonical implementation).
  Future<void> connectToDevice(BluetoothDevice device) => connect(device);

  Future<void> connect(BluetoothDevice device) async {
    _connectionStateController.add(BleConnectionState.connecting);
    _reconnectAttempts = 0;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _connectionStateController.add(BleConnectionState.verifying);

      final success = await _discoverServicesAndSubscribe(device);
      if (success) {
        // Success - Wait for acknowledgement if needed or just mark as ready
        _connectionStateController.add(BleConnectionState.ready);
      } else {
        _connectionStateController.add(BleConnectionState.wrongDevice);
        await device.disconnect();
      }
    } catch (e) {
      _connectionStateController.add(BleConnectionState.error);
      _scheduleReconnect(device);
    }
  }

  void _emitSensorSample(SensorData s) {
    _sensorDataController.add(s);
    _dataController.add(
      HelmetDataModel(
        speed: 0,
        indicator: IndicatorState.none,
        brake: false,
        crash: false,
        latitude: 0,
        longitude: 0,
        blink: BlinkState.off,
        ax: s.ax,
        ay: s.ay,
        az: s.az,
        rawDevData: '',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<bool> _discoverServicesAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      bool found = false;

        var incomingBuffer = '';

        void processTextPacket(String packet) {
          final trimmedPacket = packet.trim();
          if (trimmedPacket.isEmpty) return;

          final csvOrJson = SensorData.tryParseTelemetryLine(trimmedPacket);
          if (csvOrJson != null) {
            _emitSensorSample(csvOrJson);
            return;
          }

          final parsed = Parser.parse(trimmedPacket);
          if (parsed != null) {
            _dataController.add(parsed);
            _sensorDataController.add(
              SensorData(
                ax: parsed.ax,
                ay: parsed.ay,
                az: parsed.az,
              ),
            );
          }
        }

        for (final service in services) {
          if (service.uuid.toString().toLowerCase() ==
              Constants.helmetServiceUuid.toLowerCase()) {
            for (final characteristic in service.characteristics) {
              if (characteristic.uuid.toString().toLowerCase() ==
                  Constants.helmetCharacteristicUuid.toLowerCase()) {
                if (characteristic.properties.notify) {
                  await characteristic.setNotifyValue(true);
                  found = true;
                  _dataSubscription?.cancel();
                  _dataSubscription = characteristic.lastValueStream.listen((value) {
                    final copy = List<int>.from(value);
                    _rawBytesController.add(copy);
                    if (kDebugMode) {
                      debugPrint('BLE raw: $copy');
                    }

                    final binary = SensorData.tryParse(copy);
                    if (binary != null) {
                      _emitSensorSample(binary);
                      return;
                    }

                    final incoming = String.fromCharCodes(value);
                    incomingBuffer += incoming;

                    while (incomingBuffer.contains('\n')) {
                      final newlineIndex = incomingBuffer.indexOf('\n');
                      final packet = incomingBuffer.substring(0, newlineIndex);
                      incomingBuffer = incomingBuffer.substring(newlineIndex + 1);
                      processTextPacket(packet);
                    }

                    if (!incomingBuffer.contains('\n') &&
                        incomingBuffer.startsWith('SP:') &&
                        incomingBuffer.contains('DEV:')) {
                      processTextPacket(incomingBuffer);
                      incomingBuffer = '';
                    }

                    if (incomingBuffer.length > 512) {
                      incomingBuffer = '';
                    }
                  });
                }
              }
            }
          }
        }
      return found;
    } catch (e) {
      return false;
    }
  }

  void _scheduleReconnect(BluetoothDevice device) {
    if (_reconnectAttempts >= 5) {
      _connectionStateController.add(BleConnectionState.error);
      return;
    }

    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      await disconnect();
      await connect(device);
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _connectionStateController.add(BleConnectionState.disconnected);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionStateController.close();
    _dataController.close();
    _scanResultsController.close();
    _rawBytesController.close();
    _sensorDataController.close();
  }
}
