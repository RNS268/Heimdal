import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_settings/app_settings.dart';
import '../../models/helmet_data.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../screens/crash/crash_screen.dart';
import '../../services/settings_service.dart';

// Color Palette from Tailwind Config
const _surface = Color(0xFF0d1321);
const _onSurface = Color(0xFFdde2f6);
const _onSurfaceVariant = Color(0xFFc2c6d6);
const _primary = Color(0xFFadc6ff);
const _primaryContainer = Color(0xFF4d8eff);
const _onPrimary = Color(0xFF002e6a);
const _surfaceContainerHigh = Color(0xFF242a39);
const _surfaceContainerHighest = Color(0xFF2f3544);
const _outlineVariant = Color(0xFF424754);
const _error = Color(0xFFffb4ab);
const _tertiary = Color(0xFFffb786);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final bleState = ref.watch(bleConnectionStateProvider).valueOrNull;
    final connected = bleState == BleConnectionState.ready ||
        bleState == BleConnectionState.connected;

    // LED Logic
    final bool isSystemSecure =
        settings.autoSOS && settings.emergencyContacts.isNotEmpty && connected;

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, ref, isSystemSecure),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                children: [
                  _buildConnectedGear(context, connected, bleState),
                  const SizedBox(height: 32),
                  _buildSafetyAlerts(context, settings, controller, ref),
                  const SizedBox(height: 32),
                  _buildSimulation(context, ref),
                  const SizedBox(height: 32),
                  _buildApplication(context, ref, settings, controller),
                  const SizedBox(height: 48),
                  _buildAboutSection(),
                  const SizedBox(height: 100), // Padding for BottomNavBar
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, bool secure) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: _surface.withValues(alpha: 0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _primary),
                onPressed: () =>
                    ref.read(navigationProvider.notifier).state = 0, // Go Home
              ),
              const SizedBox(width: 8),
              const Text(
                'SETTINGS',
                style: TextStyle(
                  color: _primary,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                secure ? 'SYSTEM SECURE' : 'SYSTEM ALERT',
                style: TextStyle(
                  color: secure ? _onSurfaceVariant : _error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              _PulsingLed(isSecure: secure),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildConnectedGear(
      BuildContext context, bool connected, BleConnectionState? bleState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONNECTED GEAR',
              style: TextStyle(
                color: _onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'BT_MESH_V4',
              style: TextStyle(
                color: _primary.withValues(alpha: 0.6),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: [
              _buildGearItem(
                icon: Icons.sports_motorsports,
                iconColor: connected ? _primary : _onSurfaceVariant,
                title: 'Heimdall Smart Helmet (ESP32)',
                subtitle: connected ? 'Connected' : 'Disconnected',
                subtitleColor: connected ? _primary : _onSurfaceVariant,
                trailingIcon: connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryContainer.withValues(alpha: 0.1),
                  border: const Border(
                    top: BorderSide(
                      color: _outlineVariant,
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [_primary, _primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      AppSettings.openAppSettings(
                        type: AppSettingsType.bluetooth,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'PAIR NEW DEVICE',
                      style: TextStyle(
                        color: _onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGearItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required IconData trailingIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor == _primary
                  ? _primaryContainer.withValues(alpha: 0.2)
                  : _surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(trailingIcon, color: iconColor.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildSafetyAlerts(BuildContext context, dynamic settings, dynamic controller, WidgetRef ref) {
    double speedDrop = 0;
    double gForce = 0;
    if (settings.crashSensitivity == 'low') { gForce = 6.0; speedDrop = 35; }
    else if (settings.crashSensitivity == 'medium') { gForce = 4.5; speedDrop = 25; }
    else if (settings.crashSensitivity == 'high') { gForce = 3.5; speedDrop = 15; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAFETY & ALERTS',
          style: TextStyle(
            color: _onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.crisis_alert,
                iconColor: _tertiary,
                title: 'Crash Sensitivity',
                trailingText:
                    "${settings.crashSensitivity[0].toUpperCase()}${settings.crashSensitivity.substring(1)}",
                onTap: () {
                  _showSensitivityDialog(context, settings.crashSensitivity, controller);
                },
                extraChild: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Thresholds: {g_force: >= ${gForce}g, speed_drop: >= $speedDrop%}',
                    style: TextStyle(
                      color: _onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSettingItem(
                icon: Icons.contact_phone,
                iconColor: _tertiary,
                title: 'Emergency Contacts',
                subtitle: '${settings.emergencyContacts.length} contacts active',
                onTap: () {
                  _showContactsDialog(context, settings, controller);
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSwitchItem(
                icon: Icons.emergency,
                iconColor: _error,
                title: 'Auto-SOS on Crash',
                value: settings.autoSOS,
                onChanged: controller.setAutoSos,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimulation(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(simulationProvider);
    final simNotifier = ref.read(simulationProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SIMULATION',
              style: TextStyle(
                color: _onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sim.isRunning
                    ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                    : _surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: sim.isRunning
                      ? const Color(0xFF00BFA5).withValues(alpha: 0.4)
                      : _outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                sim.isRunning ? '● LIVE' : '○ IDLE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: sim.isRunning
                      ? const Color(0xFF00BFA5)
                      : _onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.emergency,
                iconColor: _error,
                title: 'Simulate 30s Crash Scenario',
                subtitle: 'Triggers crash after 30s with sound/vibes',
                trailingIcon: Icons.play_arrow,
                onTap: () {
                  final simNotifier = ref.read(simulationProvider.notifier);
                  final sim = ref.read(simulationProvider);
                  if (!sim.isRunning) simNotifier.start();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Crash sequence will trigger in 30 seconds...')),
                  );
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSettingItem(
                icon: Icons.bug_report,
                iconColor: _tertiary,
                title: 'Instant Crash Transition',
                subtitle: 'Launch crash screen immediately',
                trailingIcon: Icons.open_in_new,
                onTap: () {
                  showCrashOverlay(context);
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              // Master toggle
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: sim.isRunning
                            ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                            : _surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.play_circle_outline,
                        color: sim.isRunning
                            ? const Color(0xFF00BFA5)
                            : _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Simulation',
                            style: TextStyle(
                              color: _onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Drive all screens with virtual data',
                            style: TextStyle(
                              color: _onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: sim.isRunning,
                      onChanged: (_) => simNotifier.toggle(),
                      activeThumbColor: _surface,
                      activeTrackColor: const Color(0xFF00BFA5),
                      inactiveThumbColor: _onSurfaceVariant,
                      inactiveTrackColor: _surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
              if (sim.isRunning) ..._buildSimLiveReadings(sim, simNotifier),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSimLiveReadings(SimulationState sim, dynamic simNotifier) {
    return [
      const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _simRow('SPEED', '${sim.speed.toStringAsFixed(1)} km/h',
                icon: Icons.speed),
            const SizedBox(height: 10),
            _simRow(
                'INDICATORS',
                sim.indicator == IndicatorState.left
                    ? '← LEFT'
                    : sim.indicator == IndicatorState.right
                        ? 'RIGHT →'
                        : 'OFF',
                icon: Icons.turn_slight_right),
            const SizedBox(height: 10),
            _simRow('BRAKING', sim.isBraking ? 'ACTIVE' : 'INACTIVE',
                icon: Icons.stop_circle_outlined,
                valueColor: sim.isBraking ? _error : null),
            const SizedBox(height: 10),
            _simRow('ACCEL (AX/AY/AZ)',
                '${sim.ax.toStringAsFixed(2)} / ${sim.ay.toStringAsFixed(2)} / ${sim.az.toStringAsFixed(2)} m/s²',
                icon: Icons.vibration),
            const SizedBox(height: 10),
            _simRow('GYRO (GX/GY/GZ)',
                '${sim.gx.toStringAsFixed(3)} / ${sim.gy.toStringAsFixed(3)} / ${sim.gz.toStringAsFixed(3)} rad/s',
                icon: Icons.rotate_right),
            const SizedBox(height: 10),
            _simRow('LEAN ANGLE', '${sim.leanAngle.toStringAsFixed(1)}°',
                icon: Icons.screen_rotation),
            const SizedBox(height: 10),
            _simRow('HEART RATE', '${sim.heartRate} bpm',
                icon: Icons.favorite, valueColor: _error),
            const SizedBox(height: 10),
            _simRow(
                'BATTERY', '${(sim.battery * 100).toStringAsFixed(0)}%',
                icon: Icons.battery_charging_full,
                valueColor: sim.battery < 0.2 ? _error : _primary),
            const SizedBox(height: 10),
            _simRow('TEMPERATURE', '${sim.temperature.toStringAsFixed(1)}°C',
                icon: Icons.thermostat),
            const SizedBox(height: 10),
            _simRow(
                'GPS',
                '${sim.latitude.toStringAsFixed(4)}°N, ${sim.longitude.toStringAsFixed(4)}°E',
                icon: Icons.gps_fixed,
                valueColor: const Color(0xFF00BFA5)),
          ],
        ),
      ),
      const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MANUAL CONTROLS',
              style: TextStyle(
                color: _onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _controlButton(
                    'LEFT',
                    Icons.arrow_back,
                    sim.indicator == IndicatorState.left,
                    () => simNotifier.setIndicatorLeft(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _controlButton(
                    'OFF',
                    Icons.stop,
                    sim.indicator == IndicatorState.none,
                    () => simNotifier.setIndicatorOff(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _controlButton(
                    'RIGHT',
                    Icons.arrow_forward,
                    sim.indicator == IndicatorState.right,
                    () => simNotifier.setIndicatorRight(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _controlButton(
              sim.isBraking ? 'STOP BRAKE' : 'APPLY BRAKE',
              sim.isBraking ? Icons.stop_circle : Icons.warning,
              sim.isBraking,
              () => simNotifier.toggleBrake(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _simRow(String label, String value,
      {required IconData icon, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _controlButton(String label, IconData icon, bool isActive, VoidCallback onTap, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _primary.withValues(alpha: 0.15) : _surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? _primary.withValues(alpha: 0.4) : _outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? _primary : _onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _primary : _onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplication(BuildContext context, WidgetRef ref, dynamic settings, dynamic controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APPLICATION',
          style: TextStyle(
            color: _onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: [
              _buildSwitchItem(
                icon: Icons.dark_mode,
                iconColor: _primary,
                title: 'Dark Mode',
                value: settings.theme == 'dark',
                onChanged: (val) {
                  controller.setTheme(val ? 'dark' : 'light');
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSettingItem(
                icon: Icons.straighten,
                iconColor: _primary,
                title: 'Measurement Units',
                trailingText: settings.units == 'metric' ? 'Metric (km/h)' : 'Imperial (mph)',
                trailingIcon: Icons.expand_more,
                onTap: () {
                  _showMeasurementUnitsDialog(context, settings, controller);
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSettingItem(
                icon: Icons.refresh,
                iconColor: _primary,
                title: 'Refresh Services',
                subtitle: 'Reconnect BLE, GPS, music and background streams',
                trailingIcon: Icons.refresh,
                onTap: () {
                  _refreshAppServices(ref);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing all services...')),
                  );
                },
              ),
              const Divider(color: _outlineVariant, height: 1, thickness: 0.5),
              _buildSettingItem(
                icon: Icons.music_note,
                iconColor: _primary,
                title: 'Default Music App',
                subtitle: _resolveMusicAppLabel(settings.defaultMusicAppPackage),
                trailingIcon: Icons.chevron_right,
                onTap: () {
                  _showDefaultMusicAppDialog(context, settings, controller);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _refreshAppServices(WidgetRef ref) {
    ref.invalidate(bleConnectionStateProvider);
    ref.invalidate(helmetDataStreamProvider);
    ref.invalidate(sensorDataStreamProvider);
    ref.invalidate(rawBleDataProvider);
    ref.invalidate(scanResultsProvider);
    ref.invalidate(devicesProvider);
    ref.invalidate(musicProvider);
    ref.invalidate(rideDurationProvider);
  }

  String _resolveMusicAppLabel(String package) {
    if (package.isEmpty) return 'Auto / system default';
    const labels = {
      'com.spotify.music': 'Spotify',
      'com.google.android.apps.youtube.music': 'YouTube Music',
      'com.amazon.mp3': 'Amazon Music',
      'com.soundcloud.android': 'SoundCloud',
      'com.google.android.music': 'Google Play Music',
      'com.apple.android.music': 'Apple Music',
    };
    return labels[package] ?? package;
  }

  void _showDefaultMusicAppDialog(BuildContext context, dynamic settings, dynamic controller) {
    const apps = [
      {'label': 'Auto / System default', 'package': ''},
      {'label': 'Spotify', 'package': 'com.spotify.music'},
      {'label': 'YouTube Music', 'package': 'com.google.android.apps.youtube.music'},
      {'label': 'Amazon Music', 'package': 'com.amazon.mp3'},
      {'label': 'SoundCloud', 'package': 'com.soundcloud.android'},
      {'label': 'Google Play Music', 'package': 'com.google.android.music'},
      {'label': 'Apple Music', 'package': 'com.apple.android.music'},
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceContainerHigh,
          title: const Text('Default Music App', style: TextStyle(color: _onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: apps.map((app) {
              return RadioListTile<String>(
                title: Text(app['label']!, style: const TextStyle(color: _onSurface)),
                value: app['package']!,
                groupValue: settings.defaultMusicAppPackage,
                activeColor: _primary,
                onChanged: (value) {
                  if (value != null) {
                    controller.setDefaultMusicApp(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showMeasurementUnitsDialog(BuildContext context, dynamic settings, dynamic controller) {
    const units = [
      {'label': 'Metric (km/h)', 'value': 'metric'},
      {'label': 'Imperial (mph)', 'value': 'imperial'},
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceContainerHigh,
          title: const Text('Measurement Units', style: TextStyle(color: _onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: units.map((u) {
              return RadioListTile<String>(
                title: Text(u['label']!, style: const TextStyle(color: _onSurface)),
                value: u['value']!,
                groupValue: settings.units,
                activeColor: _primary,
                onChanged: (value) {
                  if (value != null) {
                    controller.setUnits(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? trailingText,
    IconData trailingIcon = Icons.chevron_right,
    VoidCallback? onTap,
    Widget? extraChild,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: _onSurfaceVariant.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailingText != null)
                    Text(
                      trailingText,
                      style: const TextStyle(
                        color: _onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  if (trailingText != null) const SizedBox(width: 8),
                  Icon(trailingIcon, color: _onSurfaceVariant.withValues(alpha: 0.4), size: 18),
                ],
              ),
              if (extraChild != null)
                Padding(
                  padding: const EdgeInsets.only(left: 40.0),
                  child: extraChild,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _surface,
            activeTrackColor: _primary,
            inactiveThumbColor: _onSurfaceVariant,
            inactiveTrackColor: _surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.security, size: 40, color: _primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Heimdall Smart Helmet v3.9.16',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Advanced real-time telemetry, crash detection, and GPS navigation system for smart motorcycling.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLink('SUPPORT'),
            const SizedBox(width: 16),
            _buildLink('PRIVACY POLICY'),
            const SizedBox(width: 16),
            _buildLink('TERMS OF SERVICE'),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.1)),
          ),
          child: const Text(
            'Version 3.9.16',
            style: TextStyle(
              color: _onSurface,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _primary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  void _showSensitivityDialog(BuildContext context, String current, dynamic controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceContainerHigh,
        title: const Text('Crash Sensitivity', style: TextStyle(color: _onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['low', 'medium', 'high'].map((level) {
            return RadioListTile<String>(
              title: Text(level.toUpperCase(), style: const TextStyle(color: _onSurface)),
              value: level,
              groupValue: current,
              activeColor: _primary,
              onChanged: (val) {
                if (val != null) {
                  controller.setCrashSensitivity(val);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showContactsDialog(BuildContext context, dynamic settings, dynamic controller) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceContainerHigh,
        title: const Text('Emergency Contacts', style: TextStyle(color: _onSurface)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ...settings.emergencyContacts.map<Widget>((c) => ListTile(
                    title: Text(c.name, style: const TextStyle(color: _onSurface)),
                    subtitle: Text(c.phone, style: const TextStyle(color: _onSurfaceVariant)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: _error),
                      onPressed: () {
                        controller.removeEmergencyContact(c);
                        Navigator.pop(context);
                      },
                    ),
                  )),
              const Divider(color: _outlineVariant),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: _onSurface),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: _onSurfaceVariant),
                ),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _onSurface),
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: _onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryContainer),
                onPressed: () async {
                  await controller.addEmergencyContact(nameCtrl.text, phoneCtrl.text);
                  Navigator.pop(context);
                },
                child: const Text('Add Contact', style: TextStyle(color: _onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PulsingLed extends StatefulWidget {
  final bool isSecure;
  const _PulsingLed({required this.isSecure});

  @override
  State<_PulsingLed> createState() => _PulsingLedState();
}

class _PulsingLedState extends State<_PulsingLed>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSecure ? Colors.greenAccent : _error;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              )
            ],
          ),
        );
      },
    );
  }
}
