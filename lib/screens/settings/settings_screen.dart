import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/ble_provider.dart';
import '../../models/device_model.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bleState = ref.watch(bleConnectionStateProvider);
    final devices = ref.watch(validDevicesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(bleState.valueOrNull),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildConnectedGear(bleState.valueOrNull, devices),
                    const SizedBox(height: 32),
                    _buildSafetySection(settings),
                    const SizedBox(height: 32),
                    _buildAppSection(settings),
                    const SizedBox(height: 32),
                    _buildAboutSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ────────────────────────────────────────────────────────────────

  Widget _buildTopAppBar(BleConnectionState? bleState) {
    final isConnected = bleState == BleConnectionState.ready;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back, size: 24, color: AppColors.secondary),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.secondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                isConnected ? 'SYSTEM SECURE' : 'NOT CONNECTED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: (isConnected ? AppColors.secondary : AppColors.error)
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? AppColors.primary : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CONNECTED GEAR ─────────────────────────────────────────────────────────

  Widget _buildConnectedGear(BleConnectionState? bleState, List<DeviceModel> validDevices) {
    final isScanning = bleState == BleConnectionState.scanning;
    final isConnected = bleState == BleConnectionState.ready ||
        bleState == BleConnectionState.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONNECTED GEAR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              'BT_MESH_V4',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Helmet device — real state from BLE
                  _buildDeviceItem(
                    icon: Icons.sports_motorsports,
                    name: 'Heimdall Smart Helmet (ESP32)',
                    status: _bleStatusLabel(bleState),
                    isConnected: isConnected,
                    onTap: isConnected
                        ? () => ref.read(bleServiceProvider).disconnect()
                        : null,
                  ),
                  _buildDeviceItem(
                    icon: Icons.favorite,
                    name: 'BLE Heart Rate Monitor',
                    status: 'Not Connected',
                    isConnected: false,
                  ),

                  // Show all discovered capabilities-filtered devices
                  ...validDevices.map((device) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    leading: const Icon(Icons.bluetooth, color: AppColors.primary, size: 20),
                    title: Text(device.name, style: const TextStyle(color: AppColors.onSurface, fontSize: 13)),
                    subtitle: Text(device.isConnected ? "Connected" : "Available", style: const TextStyle(color: AppColors.outline, fontSize: 11)),
                    trailing: TextButton(
                      onPressed: () {}, // Will be implemented in next step
                      child: const Text('Connect', style: TextStyle(color: AppColors.primary)),
                    ),
                  )),

                  // Pair / Scanning button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.1),
                    ),
                    child: GestureDetector(
                      onTap: isScanning
                          ? () => ref.read(bleServiceProvider).stopScan()
                          : () => ref.read(bleServiceProvider).startScan(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isScanning
                              ? const LinearGradient(
                                  colors: [Color(0xFF424242), Color(0xFF212121)],
                                )
                              : AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isScanning) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              isScanning ? 'Scanning... Tap to stop' : 'Pair New Device',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _bleStatusLabel(BleConnectionState? state) {
    switch (state) {
      case BleConnectionState.scanning:
        return 'Scanning...';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.verifying:
        return 'Verifying...';
      case BleConnectionState.ready:
        return 'Connected';
      case BleConnectionState.error:
        return 'Error — Tap to retry';
      case BleConnectionState.wrongDevice:
        return 'Wrong device';
      case BleConnectionState.disconnected:
      default:
        return 'Not Connected';
    }
  }

  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
    required bool isConnected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.transparent
              : AppColors.surfaceContainerLow.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.primaryContainer.withValues(alpha: 0.2)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isConnected ? AppColors.primary : AppColors.outline,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected ? AppColors.primary : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.link_off,
              color: isConnected
                  ? AppColors.onSurfaceVariant.withValues(alpha: 0.4)
                  : AppColors.outline.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }


  // ─── SAFETY SECTION ──────────────────────────────────────────────────────────

  Widget _buildSafetySection(SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAFETY & ALERTS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          children: [
            _buildSettingItem(
              icon: Icons.crisis_alert,
              iconColor: AppColors.tertiary,
              title: 'Crash Sensitivity',
              value: settings.crashSensitivity,
              onTap: () => _showCrashSensitivityPicker(settings.crashSensitivity),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.contact_phone,
              iconColor: AppColors.tertiary,
              title: 'Emergency Contacts',
              subtitle: '${settings.emergencyContacts.length} contacts active',
              onTap: () => _showContactsManager(settings),
            ),
            _buildDivider(),
            _buildToggleItem(
              icon: Icons.emergency,
              iconColor: AppColors.error,
              title: 'Auto-SOS on Crash',
              value: settings.autoSOS,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setAutoSos(v),
            ),
          ],
        ),
      ],
    );
  }

  // ─── APP SECTION ────────────────────────────────────────────────────────────

  Widget _buildAppSection(SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APPLICATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          children: [
            _buildToggleItem(
              icon: Icons.dark_mode,
              iconColor: AppColors.primary,
              title: 'Dark Mode',
              value: settings.theme == 'dark',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setDarkMode(v),
            ),
            _buildDivider(),
            _buildSettingItem(
              icon: Icons.straighten,
              iconColor: AppColors.primary,
              title: 'Measurement Units',
              value: settings.units,
              onTap: () => _showUnitsPicker(settings.units),
            ),
          ],
        ),
      ],
    );
  }

  // ─── SHARED CARD WRAPPER ────────────────────────────────────────────────────

  Widget _buildGlassCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(
        height: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.15),
        indent: 20,
        endIndent: 20,
      );

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? value,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null)
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.outline.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }

  // ─── DIALOGS ────────────────────────────────────────────────────────────────

  void _showCrashSensitivityPicker(String current) {
    const options = ['Low', 'Medium', 'High'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildPickerSheet(
        title: 'Crash Sensitivity',
        options: options,
        current: current,
        onSelect: (value) {
          ref.read(settingsProvider.notifier).setCrashSensitivity(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showUnitsPicker(String current) {
    const options = ['Metric (km/h)', 'Imperial (mph)'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildPickerSheet(
        title: 'Measurement Units',
        options: options,
        current: current,
        onSelect: (value) {
          ref.read(settingsProvider.notifier).setUnits(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildPickerSheet({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.outline,
              ),
            ),
          ),
          ...options.map(
            (o) => ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              title: Text(
                o,
                style: TextStyle(
                  color: o == current ? Colors.white : AppColors.outline,
                  fontWeight:
                      o == current ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              trailing: o == current
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () => onSelect(o),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showContactsManager(SettingsModel settings) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              final contacts =
                  ref.read(settingsProvider).emergencyContacts;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'EMERGENCY CONTACTS',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900,
                        letterSpacing: 2, color: AppColors.outline,
                      ),
                    ),
                  ),
                  if (contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No contacts added',
                        style: TextStyle(color: AppColors.outline),
                      ),
                    )
                  else
                    ...contacts.map(
                      (c) => ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        leading: const Icon(Icons.person,
                            color: AppColors.primary),
                        title: Text(c,
                            style: const TextStyle(color: AppColors.onSurface)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete,
                              color: AppColors.error, size: 20),
                          onPressed: () {
                            ref
                                .read(settingsProvider.notifier)
                                .removeEmergencyContact(c);
                            setLocalState(() {});
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Add phone number...',
                              hintStyle: const TextStyle(
                                  color: AppColors.outline),
                              filled: true,
                              fillColor:
                                  AppColors.surfaceVariant.withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            if (controller.text.trim().isNotEmpty) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .addEmergencyContact(
                                      controller.text.trim());
                              controller.clear();
                              setLocalState(() {});
                            }
                          },
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── ABOUT SECTION ──────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(Icons.shield, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Heimdall Smart Helmet v2.4',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Advanced real-time telemetry, crash detection,\nand GPS navigation for smart motorcycling.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLink('Support'),
                  _buildLink('Privacy Policy'),
                  _buildLink('Terms'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
                child: const Text(
                  'Build 2026.04.09',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
