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
  BleConnectionState _lastState = BleConnectionState.disconnected;

  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final _dataController = StreamController<HelmetDataModel>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final _rawBytesController = StreamController<List<int>>.broadcast();
  final _sensorDataController = StreamController<SensorData>.broadcast();
  final _serialMonitorController = StreamController<String>.broadcast();

  Stream<BleConnectionState> get connectionState =>
      _connectionStateController.stream;
  BleConnectionState get currentState => _lastState;
  Stream<HelmetDataModel> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  /// Every notify payload as raw bytes (for debugging and alternate parsers).
  Stream<List<int>> get rawDataStream => _rawBytesController.stream;

  /// Parsed accelerometer samples when firmware sends binary (3 / 6 / 12-byte frames).
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  /// Raw ASCII string stream for serial monitor logging.
  Stream<String> get serialMonitorStream => _serialMonitorController.stream;

  void _setState(BleConnectionState state) {
    _lastState = state;
    _connectionStateController.add(state);
  }

  Future<void> startScan() async {
    _setState(BleConnectionState.scanning);

    try {
      if (await FlutterBluePlus.isSupported == false) {
        _setState(BleConnectionState.error);
        return;
      }
      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();

        debugPrint('BLUETOOTH permissions - scan: $scanStatus, connect: $connectStatus');
        
        if (!scanStatus.isGranted || !connectStatus.isGranted) {
          debugPrint('Bluetooth permissions denied!');
          _setState(BleConnectionState.error);
          return;
        }

        // Best-effort location request for older Android stacks.
        // Do not block scanning if location is denied on Android 12+.
        final locStatus = await Permission.locationWhenInUse.request();
        debugPrint('Location permission status: $locStatus');

        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
        }
      }

      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);
      }, onError: (_) {
        _setState(BleConnectionState.error);
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      debugPrint('Scan error: $e');
      _setState(BleConnectionState.error);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<DeviceModel>> scanDevices() async* {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
      androidUsesFineLocation: false,
    );

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
    _setState(BleConnectionState.connecting);
    _reconnectAttempts = 0;

    try {
      final existingState = await device.connectionState.first;
      if (existingState != BluetoothConnectionState.connected) {
        await device.connect(timeout: const Duration(seconds: 10));
      }

      _connectedDevice = device;
      
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(Constants.bleMtu);
        } catch (e) {
          debugPrint('MTU request failed: $e');
        }
      }
      
      _setState(BleConnectionState.verifying);

      final success = await _discoverServicesAndSubscribe(device);
      if (success) {
        // Success - Wait for acknowledgement if needed or just mark as ready
        _setState(BleConnectionState.ready);
      } else {
        _setState(BleConnectionState.wrongDevice);
        await device.disconnect();
      }
    } catch (e) {
      try {
        final fallbackState = await device.connectionState.first;
        if (fallbackState == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _setState(BleConnectionState.verifying);

          final success = await _discoverServicesAndSubscribe(device);
          if (success) {
            _setState(BleConnectionState.ready);
            return;
          }
        }
      } catch (_) {
        // Keep the original error path below if the fallback state check fails.
      }

      debugPrint('Connect error: $e');
      _setState(BleConnectionState.error);
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
            _serialMonitorController.add(trimmedPacket);
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
                  // For flutter_blue_plus 1.30.0+, onValueReceived is preferred
                  _dataSubscription = characteristic.onValueReceived.listen((value) {
                    final copy = List<int>.from(value);
                    _rawBytesController.add(copy);

                    final incoming = String.fromCharCodes(value);
                    incomingBuffer += incoming;

                    while (incomingBuffer.contains('\n')) {
                      final newlineIndex = incomingBuffer.indexOf('\n');
                      final packet = incomingBuffer.substring(0, newlineIndex);
                      incomingBuffer = incomingBuffer.substring(newlineIndex + 1);
                      processTextPacket(packet);
                    }

                    // Fallback if data doesn't end with newline but we have a sizable chunk
                    if (!incomingBuffer.contains('\n') &&
                        incomingBuffer.startsWith('SP:') &&
                        incomingBuffer.length > 30 &&
                        (incomingBuffer.contains('AZ:') || incomingBuffer.contains('DEV:'))) {
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
      _setState(BleConnectionState.error);
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

  /// Sends a command to the connected helmet device.
  Future<bool> sendCommand(String command) async {
    if (_connectedDevice == null || _lastState != BleConnectionState.ready) {
      return false;
    }

    try {
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            Constants.helmetServiceUuid.toLowerCase()) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                Constants.helmetCharacteristicUuid.toLowerCase()) {
              if (characteristic.properties.write ||
                  characteristic.properties.writeWithoutResponse) {
                // Add newline if missing as our protocol expects it
                final data = command.endsWith('\n') ? command : '$command\n';
                await characteristic.write(data.codeUnits);
                debugPrint('Command sent: $data');
                return true;
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Send command error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _setState(BleConnectionState.disconnected);
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
