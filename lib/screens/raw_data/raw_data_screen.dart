import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/ble_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../models/sensor_data.dart';
import '../../models/settings_model.dart';
import '../../models/helmet_data.dart';
import '../../processing/data_processor.dart';
import '../../services/settings_service.dart';
import '../../services/background_service.dart';

class RawDataScreen extends ConsumerStatefulWidget {
  const RawDataScreen({super.key});

  @override
  ConsumerState<RawDataScreen> createState() => _RawDataScreenState();
}

class _RawDataScreenState extends ConsumerState<RawDataScreen> {
  List<int> _backgroundRawData = [];
  StreamSubscription<List<int>>? _backgroundDataSubscription;
  final List<String> _debugLogs = [];
  StreamSubscription<String>? _debugLogSubscription;
  Map<String, double> _latestSensorData = {};
  StreamSubscription<Map<String, double>>? _sensorDataSubscription;
  List<Map<String, String>> _asciiData = [];
  StreamSubscription<List<Map<String, String>>>? _asciiDataSubscription;
  String _latestRawAscii = '';
  StreamSubscription<String>? _rawAsciiSubscription;
  StreamSubscription<String>? _backgroundRawAsciiSubscription;
  final List<double> _axHistory = [];
  final List<double> _ayHistory = [];
  final List<double> _azHistory = [];
  static const int _maxHistory = 50;
  final List<String> _asciiLog = [];

  // Status trackers
  @override
  void initState() {
    super.initState();
    _backgroundDataSubscription = backgroundRawDataStream.listen((data) {
      setState(() {
        _backgroundRawData = data;
      });
    });
    
    _debugLogSubscription = debugLogStream.listen((log) {
      setState(() {
        _debugLogs.add('${DateTime.now().toIso8601String().substring(11, 19)} $log');
        if (_debugLogs.length > 100) {
          _debugLogs.removeAt(0); // Keep only last 100 logs
        }
      });
    });
    
    _sensorDataSubscription = sensorDataStream.listen((data) {
      setState(() {
        _latestSensorData = data;
        _updateHistory(data['ax'] ?? 0, data['ay'] ?? 0, data['az'] ?? 0);
      });
    });

    _asciiDataSubscription = asciiDataStream.listen((data) {
      setState(() {
        _asciiData = data;
      });
    });

    _rawAsciiSubscription = ref.read(serialMonitorStreamProvider.stream).listen((data) {
      setState(() {
        _latestRawAscii = data;
        _asciiLog.insert(0, data);
        if (_asciiLog.length > 50) _asciiLog.removeLast();
      });
    });

    _backgroundRawAsciiSubscription = ref.read(backgroundSerialDataProvider.stream).listen((data) {
      setState(() {
        _latestRawAscii = data;
        _asciiLog.insert(0, data);
        if (_asciiLog.length > 50) _asciiLog.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _backgroundDataSubscription?.cancel();
    _debugLogSubscription?.cancel();
    _sensorDataSubscription?.cancel();
    _asciiDataSubscription?.cancel();
    _rawAsciiSubscription?.cancel();
    _backgroundRawAsciiSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helmetData = ref.watch(helmetDataStreamProvider);
    final data = helmetData.valueOrNull;
    final sensorAsync = ref.watch(sensorDataStreamProvider);
    final rawAsync = ref.watch(rawBleDataProvider);
    final bleState = ref.watch(bleConnectionStateProvider);
    final settings = ref.watch(settingsProvider);
    final sim = ref.watch(simulationProvider);

    final isImperial = settings.units == 'Imperial (mph)';
    final double effectiveSpeed = sim.isRunning ? sim.speed : (data?.speed ?? 0.0);
    final speed = isImperial ? effectiveSpeed * 0.621371 : effectiveSpeed;


    // Generate ASCII data from simulation when active, otherwise use background service
    if (sim.isRunning) {
      _asciiData = _generateAsciiDataFromSimulation(sim, isImperial);
      // Update sensor data for graphs with simulation data
      _latestSensorData = {
        'ax': sim.ax,
        'ay': sim.ay,
        'az': sim.az,
        'magnitude': sqrt(sim.ax * sim.ax + sim.ay * sim.ay + sim.az * sim.az),
        'pitch': atan2(sim.ax, sim.az) * 180 / pi,
        'speed': sim.speed,
      };
      // Add simulation status to logs
      final simLog = '${DateTime.now().toIso8601String().substring(11, 19)} [SIM] Speed: ${sim.speed.toStringAsFixed(1)} km/h, Indicators: ${sim.indicator == IndicatorState.left ? 'LEFT' : sim.indicator == IndicatorState.right ? 'RIGHT' : 'OFF'}, Brake: ${sim.isBraking ? 'ON' : 'OFF'}';
      if (!_debugLogs.contains(simLog)) {
        _debugLogs.add(simLog);
        if (_debugLogs.length > 100) {
          _debugLogs.removeAt(0);
        }
      }
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(),
              TabBar(
                tabs: const [
                  Tab(text: 'ASCII'),
                  Tab(text: 'GRAPHS'),
                  Tab(text: 'LOGS'),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.outline,
                indicatorColor: AppColors.primary,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAsciiTab(),
                    _buildGraphsTab(),
                    _buildLogsTab(),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildAsciiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASCII DATA FROM ESP32',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              _latestRawAscii.isEmpty ? 'Waiting for packets...' : _latestRawAscii,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PACKET HISTORY (SERIAL MONITOR)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _asciiLog.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _asciiLog[index],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PARSED FIELDS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 16),
          if (_asciiData.isEmpty)
            Center(
              child: Text(
                'No ASCII data received yet',
                style: TextStyle(color: AppColors.outline),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'LABEL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'VALUE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data rows
                  ..._asciiData.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.outline.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text(
                                item['icon']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['label']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['value']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraphsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Text(
          'SENSOR GRAPHS (Accelerometer + Gyroscope)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: 12),
        _buildSensorGraphs(_latestSensorData),
        const SizedBox(height: 24),
        _buildGyroGraphs(_latestSensorData),
      ],
    );
  }

  Widget _buildSensorGraphs(Map<String, double> sensorData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Real-time Accelerometer (m/s²)',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Last update: ${DateTime.now().toIso8601String().substring(11, 19)}',
                style: TextStyle(
                  color: AppColors.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAccelBar('AX (X-axis)', sensorData['ax'] ?? 0, Colors.red),
          const SizedBox(height: 12),
          _buildAccelBar('AY (Y-axis)', sensorData['ay'] ?? 0, Colors.green),
          const SizedBox(height: 12),
          _buildAccelBar('AZ (Z-axis)', sensorData['az'] ?? 0, Colors.blue),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSensorValue('Magnitude', sensorData['magnitude'] ?? 0),
              _buildSensorValue('Pitch', sensorData['pitch'] ?? 0),
              _buildSensorValue('Speed', sensorData['speed'] ?? 0),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                histories: [_axHistory, _ayHistory, _azHistory],
                colors: [Colors.red, Colors.green, Colors.blue],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGyroGraphs(Map<String, double> sensorData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Real-time Gyroscope',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Last update: ${DateTime.now().toIso8601String().substring(11, 19)}',
                style: TextStyle(
                  color: AppColors.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildGyroBar('GX (X-axis)', sensorData['gx'] ?? 0, Colors.orange),
          const SizedBox(height: 12),
          _buildGyroBar('GY (Y-axis)', sensorData['gy'] ?? 0, Colors.purple),
          const SizedBox(height: 12),
          _buildGyroBar('GZ (Z-axis)', sensorData['gz'] ?? 0, Colors.cyan),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSensorValue('GX Total', sensorData['gx'] ?? 0),
              _buildSensorValue('GY Total', sensorData['gy'] ?? 0),
              _buildSensorValue('GZ Total', sensorData['gz'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccelBar(String label, double value, Color color) {
    // Normalize accelerometer value for display (-20 to +20 m/s² range)
    final normalizedValue = (value / 20.0).clamp(-1.0, 1.0);
    final barWidth = (normalizedValue.abs() * 120).toDouble(); // Max 120px bar
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Background bar
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Value bar
                  Align(
                    alignment: normalizedValue >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: barWidth,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Center line
                  Center(
                    child: Container(
                      width: 2,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGyroBar(String label, double value, Color color) {
    // Normalize gyroscope value for display (-10 to +10 rad/s range)
    final normalizedValue = (value / 10.0).clamp(-1.0, 1.0);
    final barWidth = (normalizedValue.abs() * 120).toDouble(); // Max 120px bar
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Background bar
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Value bar
                  Align(
                    alignment: normalizedValue >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: barWidth,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Center line
                  Center(
                    child: Container(
                      width: 2,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                value.toStringAsFixed(3),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorBar(String label, double value, Color color) {
    // Normalize value for display (-20 to +20 range)
    final normalizedValue = (value / 20.0).clamp(-1.0, 1.0);
    final barWidth = (normalizedValue.abs() * 120).toDouble(); // Max 120px bar
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Background bar
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Value bar
                  Align(
                    alignment: normalizedValue >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: barWidth,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Center line
                  Center(
                    child: Container(
                      width: 2,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorValue(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.outline,
          fontSize: 10,
        ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
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
        _buildLogsSection(_debugLogs),
      ],
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

  List<Map<String, String>> _generateAsciiDataFromSimulation(SimulationState sim, bool isImperial) {
    final speed = isImperial ? sim.speed * 0.621371 : sim.speed;
    final speedUnit = isImperial ? 'mph' : 'km/h';
    
    return [
      {'label': 'Speed', 'value': '${speed.toStringAsFixed(2)} $speedUnit', 'icon': '🚗'},
      {'label': 'Indicator', 'value': sim.indicator == IndicatorState.left ? 'LEFT' : sim.indicator == IndicatorState.right ? 'RIGHT' : 'OFF', 'icon': '🧭'},
      {'label': 'Brake', 'value': sim.isBraking ? 'ON' : 'OFF', 'icon': '🛑'},
      {'label': 'Crash Status', 'value': sim.isCrash ? 'CRASH' : 'NORMAL', 'icon': sim.isCrash ? '🚨' : '✅'},
      {'label': 'Latitude', 'value': sim.latitude.toStringAsFixed(6), 'icon': '📍'},
      {'label': 'Longitude', 'value': sim.longitude.toStringAsFixed(6), 'icon': '📍'},
      {'label': 'Accel X', 'value': '${sim.ax.toStringAsFixed(2)} m/s²', 'icon': '📊'},
      {'label': 'Accel Y', 'value': '${sim.ay.toStringAsFixed(2)} m/s²', 'icon': '📊'},
      {'label': 'Accel Z', 'value': '${sim.az.toStringAsFixed(2)} m/s²', 'icon': '📊'},
      {'label': 'Gyro X', 'value': '${sim.gx.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
      {'label': 'Gyro Y', 'value': '${sim.gy.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
      {'label': 'Gyro Z', 'value': '${sim.gz.toStringAsFixed(3)} rad/s', 'icon': '🔄'},
      {'label': 'Lean Angle', 'value': '${sim.leanAngle.toStringAsFixed(1)}°', 'icon': '📐'},
      {'label': 'Heart Rate', 'value': '${sim.heartRate} bpm', 'icon': '❤️'},
      {'label': 'Battery', 'value': '${(sim.battery * 100).toStringAsFixed(0)}%', 'icon': '🔋'},
      {'label': 'Temperature', 'value': '${sim.temperature.toStringAsFixed(1)}°C', 'icon': '🌡️'},
      {'label': 'Altitude', 'value': '${sim.altitude.toStringAsFixed(0)} m', 'icon': '⛰️'},
      {'label': 'Scenario', 'value': sim.scenario, 'icon': '🎭'},
    ];
  }

  void _updateHistory(double ax, double ay, double az) {
    _axHistory.add(ax);
    _ayHistory.add(ay);
    _azHistory.add(az);
    if (_axHistory.length > _maxHistory) _axHistory.removeAt(0);
    if (_ayHistory.length > _maxHistory) _ayHistory.removeAt(0);
    if (_azHistory.length > _maxHistory) _azHistory.removeAt(0);
  }
}

class WaveformPainter extends CustomPainter {
  final List<List<double>> histories;
  final List<Color> colors;

  WaveformPainter({required this.histories, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw background grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const double maxVal = 20.0;
    const double minVal = -20.0;
    const double range = maxVal - minVal;

    for (int h = 0; h < histories.length; h++) {
      final history = histories[h];
      if (history.isEmpty) continue;

      paint.color = colors[h];
      final path = Path();

      for (int i = 0; i < history.length; i++) {
        final x = size.width * i / 49;
        final normalized = (history[i] - minVal) / range;
        final y = size.height - (normalized * size.height);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}


