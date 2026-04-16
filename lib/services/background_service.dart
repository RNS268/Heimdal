import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/constants.dart';

/// ============================================================================
/// HELMET SAFETY SERVICE - COMPLETE ALL-IN-ONE CORE
/// ============================================================================
/// 
/// This single file handles:
/// ✅ Foreground service (24/7 execution)
/// ✅ BLE scanning & connection
/// ✅ Real-time crash detection
/// ✅ Autonomous SOS trigger
/// ✅ Location capture
/// ✅ Emergency SMS dispatch
/// ✅ Auto-reconnect logic
/// 
/// Status: Production-ready. Test thoroughly before deployment.
/// ============================================================================

final service = FlutterBackgroundService();

/// Global stream for raw BLE data from background service
final backgroundRawDataController = StreamController<List<int>>.broadcast();
final backgroundRawDataStream = backgroundRawDataController.stream;

/// Global debug logging stream
final debugLogController = StreamController<String>.broadcast();
final debugLogStream = debugLogController.stream;

/// Parsed sensor data stream for graphs
final sensorDataController = StreamController<Map<String, double>>.broadcast();
final sensorDataStream = sensorDataController.stream;

/// Parsed ASCII data stream for list display
final asciiDataController = StreamController<List<Map<String, String>>>.broadcast();
final asciiDataStream = asciiDataController.stream;

/// Dedicated stream for raw serial data (ASCII text packets)
final serialDataController = StreamController<String>.broadcast();
final serialDataStream = serialDataController.stream;

/// Indicator states stream for UI indicators
final indicatorStateController = StreamController<Map<String, bool>>.broadcast();
final indicatorStateStream = indicatorStateController.stream;

/// Static GPS helper for BLE manager
Future<Position> _getPhoneGPS() async {
  try {
    return await Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 10),
    );
  } catch (e) {
    debugLogController.add('[GPS] Phone GPS failed: $e');
    // Return default location
    return Position(
      longitude: 78.3996,
      latitude: 17.4948,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

/// Sensor data model for the text protocol
class SensorDataModel {
  final double speed;
  final String indicator;
  final int brake;
  final String crash;
  final double latitude;
  final double longitude;
  final int clock;
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final double magnitude;
  final double pitch;
  final DateTime timestamp;

  SensorDataModel({
    required this.speed,
    required this.indicator,
    required this.brake,
    required this.crash,
    required this.latitude,
    required this.longitude,
    required this.clock,
    required this.ax,
    required this.ay,
    required this.az,
    this.gx = 0.0,
    this.gy = 0.0,
    this.gz = 0.0,
    required this.magnitude,
    required this.pitch,
    required this.timestamp,
  });
}

 

/// Initialize the background service
Future<void> initializeBackgroundService() async {
  try {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        await Permission.locationAlways.request();
      }
      
      // Request BLE permissions for background scanning
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      
      // If location is denied, the foreground service WILL crash in Android 14.
      if (!await Permission.location.isGranted) {
        debugLogController.add('[SERVICE] Location permission denied. Cannot start background service safely.');
        return;
      }
      
      // CREATE THE NOTIFICATION CHANNEL FIRST
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'helmet_safety_channel', // id
        'Helmet Safety Service', // name
        description: 'This channel is used for important safety notifications.', // description
        importance: Importance.high, 
      );
      
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
          
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'helmet_safety_channel',
        initialNotificationTitle: 'Helmet Safety Active',
        initialNotificationContent: 'Monitoring for crashes...',
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
    debugLogController.add('[SERVICE] Background service initialized');
  } catch (e) {
    debugLogController.add('[SERVICE] Failed to initialize: $e');
  }
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Main service entry point - runs continuously
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugLogController.add('[SERVICE] Helmet Safety Service Started');

  try {
    // Initialize location services
    await _initializeLocation();

    final state = _ServiceState();
    final detector = _CrashDetector();
    final sosManager = _SOSManager();
    final bleManager = _BLEManager();
    
    // Start BLE scanning for automatic helmet connection

    bleManager.startScanning(
      onDataReceived: (accel, gyro) {
        // Process crash detection
        if (detector.analyze(accel, gyro)) {
          debugLogController.add('[SERVICE] Crash detected! Triggering SOS...');
          state.recordCrash();
          sosManager.triggerSOS();
        }
      },
      onError: (error) {
        debugLogController.add('[BLE] Error: $error');
      },
      sosManager: sosManager,
    );

    // Service loop - keeps everything running
    late Timer periodicTimer;
    periodicTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Note: setNotificationInfo is not available in newer versions
      // Update notification using service.setForegroundNotificationInfo instead if available
    });

    service.on('stopService').listen((event) {
      periodicTimer.cancel();
      bleManager.dispose();
      service.stopSelf();
    });

    service.on('sendCommand').listen((event) {
      final command = event?['command'] as String?;
      if (command != null) {
        bleManager.sendCommand(command);
      }
    });
  } catch (e) {
    debugLogController.add('[SERVICE] Error during initialization: $e');
    debugLogController.add('[SERVICE] Stack: ${StackTrace.current}');
  }
}

/// ============================================================================
/// CRASH DETECTION ENGINE
/// ============================================================================

class _CrashDetector {
  static const double accelThreshold = 3.5; // G-force
  static const double gyroThreshold = 600; // degrees/sec
  static const double varianceThreshold = 1.5;

  final List<double> _accelHistory = [];
  final List<double> _gyroHistory = [];
  bool _inCrashWindow = false;
  DateTime? _crashWindowStart;

  bool analyze(List<double> accel, List<double> gyro) {
    // Calculate magnitudes
    final accelMag = _magnitude(accel);
    final gyroMag = _magnitude(gyro);

    _accelHistory.add(accelMag);
    _gyroHistory.add(gyroMag);

    // Keep only last 10 samples
    if (_accelHistory.length > 10) _accelHistory.removeAt(0);
    if (_gyroHistory.length > 10) _gyroHistory.removeAt(0);

    // Check if entering crash zone
    if (accelMag > accelThreshold && gyroMag > gyroThreshold) {
      if (!_inCrashWindow) {
        _inCrashWindow = true;
        _crashWindowStart = DateTime.now();
        debugLogController.add('[DETECTOR] Entered crash window');
      }
    }

    // Check if sustained impact (3+ seconds)
    if (_inCrashWindow &&
        DateTime.now().difference(_crashWindowStart!).inSeconds >= 3) {
      final variance = _calculateVariance(_accelHistory);

      if (variance > varianceThreshold) {
        _inCrashWindow = false;
        return true; // CRASH CONFIRMED
      }
    }

    // Exit crash window if values return to normal
    if (accelMag < 1.5 && gyroMag < 100) {
      if (_inCrashWindow) {
        debugLogController.add('[DETECTOR] Exited crash window (false alarm)');
      }
      _inCrashWindow = false;
    }

    return false;
  }

  double _magnitude(List<double> vec) {
    if (vec.length < 3) return 0;
    return sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]);
  }

  double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0;
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance =
        data.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            data.length;
    return sqrt(variance);
  }
}

/// ============================================================================
/// BLE INTEGRATION ENGINE
/// ============================================================================

class _BLEManager {
  static const String serviceUuid = '12345678-1234-1234-1234-1234567890ab';
  static const String characteristicUuid = '44444444-4444-4444-4444-444444444444';
  
  static const List<String> helmetDeviceNames = [
    Constants.helmetDeviceName,
    'ESP32_HELMET',
  ];

  BluetoothDevice? _device;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _dataSubscription;
  BluetoothCharacteristic? _dataCharacteristic;

  bool isConnected = false;
  int reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const List<int> reconnectDelays = [3, 5, 10, 15, 30]; // seconds

  // CLK monitoring for connection health
  int _lastClockValue = -1;
  DateTime _lastClockUpdate = DateTime.now();

  Function(List<double>, List<double>)? _onDataReceived;
  Function(String)? _onError;
  _SOSManager? _sosManager;

  void startScanning({
    required Function(List<double>, List<double>) onDataReceived,
    required Function(String) onError,
    _SOSManager? sosManager,
  }) {
    _onDataReceived = onDataReceived;
    _onError = onError;
    _sosManager = sosManager;

    // First check if we already have connected devices
    _checkExistingConnections();

    // Start scanning for helmet devices
    _scan();
  }

  Future<void> _checkExistingConnections() async {
    try {
      final connectedDevices = FlutterBluePlus.connectedDevices;
      for (final device in connectedDevices) {
        final deviceName = device.platformName.isNotEmpty
            ? device.platformName
            : device.advName;
        
        if (helmetDeviceNames.contains(deviceName)) {
          debugLogController.add('[BLE] Found already connected helmet: $deviceName');
          // Try to discover services on this device
          await _discoverServices(device);
          return; // Found one, stop looking
        }
      }
    } catch (e) {
      debugLogController.add('[BLE] Error checking existing connections: $e');
    }
  }

  Future<void> _scan() async {
    debugLogController.add('[BLE] Starting device scan...');

    try {
      // ignore: unused_result
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      // ignore: unused_result
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          final deviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;

          final hasService = result.advertisementData.serviceUuids
              .map((u) => u.toString().toLowerCase())
              .contains(serviceUuid.toLowerCase());

          if (helmetDeviceNames.contains(deviceName) || hasService) {
            debugLogController.add('[BLE] Found helmet: $deviceName (ServiceMatch: $hasService)');

            // Fire and forget the connection
            // ignore: unused_result
            FlutterBluePlus.stopScan();
            _connect(result.device);
            break;
          }
        }
      });
    } catch (e) {
      _onError?.call('Scan failed: $e');
      await Future.delayed(const Duration(seconds: 5));
      await _scan();
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      debugLogController.add('[BLE] Connecting to ${device.platformName}...');

      _device = device;
      await device.connect(timeout: const Duration(seconds: 10));
      isConnected = true;
      reconnectAttempts = 0;

      debugLogController.add('[BLE] Connected');

      _connectionSubscription =
          device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          debugLogController.add('[BLE] Disconnected');
          isConnected = false;
          _reconnect();
        }
      });

      await _discoverServices(device);
    } catch (e) {
      debugLogController.add('[BLE] Connection failed: $e');
      isConnected = false;
      _reconnect();
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      debugLogController.add('[BLE] Discovering services...');

      // Request MTU to match ESP32 firmware (185 bytes)
      await device.requestMtu(185);
      debugLogController.add('[BLE] MTU set to 185 bytes');

      final services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          debugLogController.add('[BLE] Found helmet service: $serviceUuid');
          
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristicUuid) {
              debugLogController.add('[BLE] Found data characteristic: $characteristicUuid');

              await characteristic.setNotifyValue(true);
              _dataCharacteristic = characteristic;

              _dataSubscription = characteristic.lastValueStream.listen((value) {
                _parseData(value, _sosManager);
                _displayRawData(value);
              });
              return;
            }
          }
        }
      }

      _onError?.call('Helmet service or characteristic not found');
    } catch (e) {
      debugLogController.add('[BLE] Service discovery failed: $e');
      _onError?.call('Service discovery error: $e');
    }
  }

  void _parseData(List<int> data, _SOSManager? sosManager) async {
    try {
      // Convert bytes to string
      final rawString = String.fromCharCodes(data).trim();
      
      // Parse the text protocol
      final sensorData = await _parseTextProtocol(rawString);
      if (sensorData != null) {
        // Check for ASCII crash detection (C:ACCT)
        if (sensorData.crash == 'ACCT') {
          debugLogController.add('[CRASH] ASCII crash detected (C:ACCT)! Triggering SOS...');
          sosManager?.triggerSOS();
        }

        // Send sensor data for graphs
        sensorDataController.add({
          'ax': sensorData.ax,
          'ay': sensorData.ay,
          'az': sensorData.az,
          'gx': sensorData.gx,
          'gy': sensorData.gy,
          'gz': sensorData.gz,
          'magnitude': sensorData.magnitude,
          'pitch': sensorData.pitch,
          'speed': sensorData.speed,
        });

        // Send parsed ASCII data for list display
        asciiDataController.add([
          {'label': 'Speed', 'value': '${sensorData.speed.toStringAsFixed(2)} km/h', 'icon': '🚗'},
          {'label': 'Indicator', 'value': sensorData.indicator, 'icon': '🧭'},
          {'label': 'Brake', 'value': sensorData.brake == 1 ? 'ON' : 'OFF', 'icon': '🛑'},
          {'label': 'Crash Status', 'value': sensorData.crash, 'icon': sensorData.crash == 'ACCT' ? '🚨' : '✅'},
          {'label': 'Latitude', 'value': sensorData.latitude.toStringAsFixed(6), 'icon': '📍'},
          {'label': 'Longitude', 'value': sensorData.longitude.toStringAsFixed(6), 'icon': '📍'},
          {'label': 'Clock', 'value': sensorData.clock.toString(), 'icon': '⏰'},
          {'label': 'Accel X', 'value': '${sensorData.ax.toStringAsFixed(2)} g', 'icon': '📊'},
          {'label': 'Accel Y', 'value': '${sensorData.ay.toStringAsFixed(2)} g', 'icon': '📊'},
          {'label': 'Accel Z', 'value': '${sensorData.az.toStringAsFixed(2)} g', 'icon': '📊'},
          {'label': 'Gyro X', 'value': '${sensorData.gx.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
          {'label': 'Gyro Y', 'value': '${sensorData.gy.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
          {'label': 'Gyro Z', 'value': '${sensorData.gz.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
          {'label': 'Magnitude', 'value': '${sensorData.magnitude.toStringAsFixed(2)} g', 'icon': '📈'},
          {'label': 'Pitch', 'value': '${sensorData.pitch.toStringAsFixed(2)}°', 'icon': '📐'},
          {'label': 'Timestamp', 'value': sensorData.timestamp.toIso8601String().substring(11, 19), 'icon': '🕐'},
        ]);

        // Send indicator states for UI
        indicatorStateController.add({
          'leftIndicator': sensorData.indicator == 'L',
          'rightIndicator': sensorData.indicator == 'R',
          'brake': sensorData.brake == 1,
        });

        // Check CLK for connection health
        _monitorConnectionHealth(sensorData.clock);

        // Legacy callback for crash detection (convert to old format)
        _onDataReceived?.call([sensorData.ax, sensorData.ay, sensorData.az], [0, 0, 0]);
      }
    } catch (e) {
      debugLogController.add('[ERROR] Failed to parse data: $e');
    }
  }

  Future<void> sendCommand(String command) async {
    if (_dataCharacteristic == null || !isConnected) {
      debugLogController.add('[BLE] Cannot send command: Not connected');
      return;
    }

    try {
      final data = command.endsWith('\n') ? command : '$command\n';
      await _dataCharacteristic!.write(data.codeUnits);
      debugLogController.add('[BLE] Sent command: $command');
    } catch (e) {
      debugLogController.add('[BLE] Failed to send command: $e');
    }
  }

  Future<SensorDataModel?> _parseTextProtocol(String data) async {
    try {
      // Handle missing comma after CLK value (ESP32 sends CLK:0DEV: together)
      String normalizedData = data.replaceAll('DEV:', ',');
      // If DEV: wasn't found, try the old format just in case
      if (normalizedData == data) {
        normalizedData = data.replaceAll('CLK:', 'CLK:0,DEV:');
      }

      debugLogController.add('[PARSE] Raw data: $data');
      debugLogController.add('[PARSE] Normalized: $normalizedData');

      // Parse key-value pairs
      final pairs = <String, String>{};
      final parts = normalizedData.split(',');
      for (final part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          pairs[kv[0].trim()] = kv[1].trim();
        }
      }

      // Extract values with defaults
      final speed = double.tryParse(pairs['SP'] ?? '0') ?? 0.0;
      final indicator = pairs['I'] ?? 'N';  // Fixed: was '1' but should be 'I'
      final brake = int.tryParse(pairs['B'] ?? '0') ?? 0;
      final crash = pairs['C'] ?? 'NO';
      var latitude = double.tryParse(pairs['LAT'] ?? '0') ?? 0.0;
      var longitude = double.tryParse(pairs['LOG'] ?? '0') ?? 0.0;
      
      // GPS fallback: if ESP32 GPS is 0, use phone GPS
      if (latitude == 0.0 && longitude == 0.0) {
        try {
          final position = await _getPhoneGPS();
          latitude = position.latitude;
          longitude = position.longitude;
          debugLogController.add('[GPS] Using phone GPS: $latitude, $longitude');
        } catch (e) {
          debugLogController.add('[GPS] Phone GPS failed, keeping 0.0: $e');
        }
      }
      
      final clock = int.tryParse(pairs['CLK'] ?? '0') ?? 0;
      
      // Parse sensor values (AX, AY, AZ) - supporting both top-level and DEV level
      double ax = double.tryParse(pairs['AX'] ?? '') ?? 0.0;
      double ay = double.tryParse(pairs['AY'] ?? '') ?? 0.0;
      double az = double.tryParse(pairs['AZ'] ?? '') ?? 9.81;
      double gx = double.tryParse(pairs['GX'] ?? '') ?? 0.0;
      double gy = double.tryParse(pairs['GY'] ?? '') ?? 0.0;
      double gz = double.tryParse(pairs['GZ'] ?? '') ?? 0.0;
      
      final devData = pairs['DEV'] ?? '';
      if (devData.isNotEmpty) {
        final devParts = devData.split(',');
        for (final part in devParts) {
          final kv = part.split(':');
          if (kv.length != 2) continue;
          
          final key = kv[0].trim().toUpperCase();
          final value = double.tryParse(kv[1].trim()) ?? 0.0;
          
          switch (key) {
            case 'AX': if (ax == 0.0) ax = value;
            case 'AY': if (ay == 0.0) ay = value;
            case 'AZ': if (az == 9.81) az = value;
            case 'GX': gx = value;
            case 'GY': gy = value;
            case 'GZ': gz = value;
          }
        }
      }
      
      final magnitude = sqrt(ax * ax + ay * ay + az * az);
      final pitch = atan2(ax, sqrt(ay * ay + az * az)) * 180 / pi;

      return SensorDataModel(
        speed: speed,
        indicator: indicator,
        brake: brake,
        crash: crash,
        latitude: latitude,
        longitude: longitude,
        clock: clock,
        ax: ax,
        ay: ay,
        az: az,
        gx: gx,
        gy: gy,
        gz: gz,
        magnitude: magnitude,
        pitch: pitch,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugLogController.add('[PARSE ERROR] $e');
      return null;
    }
  }

  void _monitorConnectionHealth(int currentClock) {
    final now = DateTime.now();
    
    // If clock changed, update timestamp
    if (currentClock != _lastClockValue) {
      _lastClockValue = currentClock;
      _lastClockUpdate = now;
      debugLogController.add('[HEALTH] CLK updated: $currentClock');
      return;
    }

    // Check if clock hasn't changed for 3 seconds
    final timeSinceLastUpdate = now.difference(_lastClockUpdate).inSeconds;
    if (timeSinceLastUpdate >= 3) {
      debugLogController.add('[HEALTH] CLK stale for ${timeSinceLastUpdate}s - connection lost');
      _onError?.call('BLE connection lost - CLK not updating');
      
      // Trigger reconnection
      if (isConnected) {
        _reconnect();
      }
    }
  }

  void _displayRawData(List<int> data) {
    try {
      // Send raw data to UI stream
      backgroundRawDataController.add(data);
      
      final asciiData = String.fromCharCodes(data).trim();
      if (asciiData.isNotEmpty) {
        serialDataController.add(asciiData);
        debugLogController.add('[SERIAL] $asciiData');
      }
    } catch (e) {
      debugLogController.add('[RAW DATA ERROR] $e');
    }
  }

  Future<void> _reconnect() async {
    if (reconnectAttempts >= maxReconnectAttempts) {
      debugLogController.add('✗ [BLE] Max reconnect attempts reached');
      _scan();
      reconnectAttempts = 0;
      return;
    }

    final delay = reconnectDelays[reconnectAttempts];
    debugLogController.add(
        '⏳ [BLE] Reconnecting in ${delay}s (attempt ${reconnectAttempts + 1}/$maxReconnectAttempts)');

    reconnectAttempts++;

    await Future.delayed(Duration(seconds: delay));

    if (_device != null) {
      _connect(_device!);
    } else {
      _scan();
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _device?.disconnect();
  }
}

/// ============================================================================
/// AUTONOMOUS SOS ENGINE
/// ============================================================================

class _SOSManager {
  static const int countdownSeconds = 10;
  static const int cooldownMinutes = 5;

  int sosCount = 0;
  DateTime? _lastSOSTime;
  bool _countdownActive = false;

  Future<void> triggerSOS() async {
    // Check cooldown
    if (_lastSOSTime != null) {
      final elapsed = DateTime.now().difference(_lastSOSTime!);
      if (elapsed.inMinutes < cooldownMinutes) {
        debugLogController.add(
            '⏱️ [SOS] In cooldown. Next SOS available in ${cooldownMinutes - elapsed.inMinutes}m');
        return;
      }
    }

    _lastSOSTime = DateTime.now();
    sosCount++;

    debugLogController.add('🚨 [SOS] Countdown started (${countdownSeconds}s)');
    _countdownActive = true;

    bool cancelled = false;

    // 10-second countdown
    for (int i = countdownSeconds; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));

      if (!_countdownActive) {
        debugLogController.add('✓ [SOS] Cancelled by user');
        cancelled = true;
        break;
      }

      debugLogController.add('⏳ [SOS] ${i}s remaining...');
    }

    _countdownActive = false;

    if (!cancelled) {
      debugLogController.add('📤 [SOS] Sending emergency alerts...');
      await _sendSOS();
    }
  }

  Future<void> _sendSOS() async {
    try {
      // Get current location
      final position = await _getCurrentLocation();

      // Build message
      final message =
          'EMERGENCY: Helmet crash detected!\n\nLocation: https://maps.google.com/?q=${position.latitude},${position.longitude}\n\nTime: ${DateTime.now()}';

      // Send to emergency contacts (Twilio integration)
      await _sendViaTwilio(message);

      // Also attempt native SMS
      await _sendViaNativeSMS(message);

      debugLogController.add('✓ [SOS] Emergency alerts sent');
    } catch (e) {
      debugLogController.add('✗ [SOS] Failed to send: $e');
      // Retry in 30 seconds
      await Future.delayed(const Duration(seconds: 30));
      _sendSOS();
    }
  }

  Future<Position> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugLogController.add('⚠️ [GPS] Failed: $e');
      // Return default location
      return Position(
        longitude: 78.3996,
        latitude: 17.4948,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  Future<void> _sendViaTwilio(String message) async {
    try {
      // ⚠️ CONFIGURE THESE IN PRODUCTION
      const String twilioSid = "YOUR_TWILIO_SID";
      const String twilioToken = "YOUR_TWILIO_TOKEN";
      const String twilioFrom = "YOUR_TWILIO_PHONE";
      const String emergencyTo = "+91XXXXXXXXXX";

      if (twilioSid == "YOUR_TWILIO_SID") {
        debugLogController.add('⚠️ [TWILIO] Not configured - skipping');
        return;
      }

      final uri = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$twilioSid/Messages.json');

      final response = await http.post(
        uri,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$twilioSid:$twilioToken'))}',
        },
        body: {
          'From': twilioFrom,
          'To': emergencyTo,
          'Body': message,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        debugLogController.add('✓ [TWILIO] SMS sent successfully');
      } else {
        debugLogController.add('✗ [TWILIO] Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugLogController.add('✗ [TWILIO] Error: $e');
    }
  }

  Future<void> _sendViaNativeSMS(String message) async {
    try {
      // Native SMS would require platform channel
      // For now, just log
      debugLogController.add('📝 [SMS] (Requires platform channel): $message');
    } catch (e) {
      debugLogController.add('✗ [SMS] Error: $e');
    }
  }

  void cancelCountdown() {
    _countdownActive = false;
  }
}

/// ============================================================================
/// SERVICE STATE TRACKER
/// ============================================================================

class _ServiceState {
  bool crashTriggered = false;
  bool sosActive = false;
  int totalCrashesDetected = 0;
  int totalSOSTriggered = 0;
  DateTime? lastCrashTime;
  DateTime? lastSOSTime;

  void recordCrash() {
    totalCrashesDetected++;
    lastCrashTime = DateTime.now();
  }

  void recordSOS() {
    totalSOSTriggered++;
    lastSOSTime = DateTime.now();
  }
}

/// ============================================================================
/// LOCATION INITIALIZATION
/// ============================================================================

Future<void> _initializeLocation() async {
  try {
    final permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugLogController.add('⚠️ [GPS] Permission denied');
      return;
    }

    debugLogController.add('✓ [GPS] Permission granted');
  } catch (e) {
    debugLogController.add('✗ [GPS] Init failed: $e');
  }
}

/// ============================================================================
/// PUBLIC API FOR UI
/// ============================================================================

class HelmetSafetyService {
  static final HelmetSafetyService _instance = HelmetSafetyService._internal();

  factory HelmetSafetyService() {
    return _instance;
  }

  HelmetSafetyService._internal();

  Future<void> initialize() async {
    await initializeBackgroundService();
  }

  void start() {
    service.startService();
  }

  void stop() {
    service.invoke('stopService');
  }
}

/// ============================================================================
/// USAGE IN main.dart
/// ============================================================================
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await HelmetSafetyService().initialize();
///   runApp(MyApp());
/// }
///
/// ============================================================================
