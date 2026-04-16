import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/speed_display.dart';
import '../../widgets/indicator_arrow.dart';
import '../../providers/ble_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/helmet_data.dart';
import '../../services/background_service.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(bleConnectionStateProvider);
    final helmetData = ref.watch(helmetDataStreamProvider);
    final settings = ref.watch(settingsProvider);
    final sim = ref.watch(simulationProvider);
    final indicatorState = ref.watch(
      StreamProvider((ref) => indicatorStateStream),
    );
    final colorScheme = Theme.of(context).colorScheme;

    // Merge: prefer simulation data when it's running
    final HelmetDataModel? effectiveData = sim.isRunning
        ? sim.toHelmetData()
        : helmetData.valueOrNull;

    final state = connectionState.valueOrNull;
    final isConnected = state == BleConnectionState.ready;
    final isVerifying = state == BleConnectionState.verifying;
    final isWrong = state == BleConnectionState.wrongDevice;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, ref, state, sim.isRunning),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sim.isRunning)
                          _buildStatusBanner(
                            '⚡ SIMULATION ACTIVE — VIRTUAL TELEMETRY',
                            const Color(0xFF00BFA5),
                          )
                        else if (isVerifying)
                          _buildStatusBanner(
                            'Verifying Module Status...',
                            Theme.of(context).colorScheme.primary,
                          )
                        else if (isWrong)
                          _buildStatusBanner(
                            'Wrong Device Connected. Please switch.',
                            Theme.of(context).colorScheme.error,
                          )
                        else if (isConnected && helmetData.valueOrNull != null)
                          _buildStatusBanner(
                            'System Ready. Trip Active.',
                            Theme.of(context).colorScheme.secondary,
                          ),
                        const SizedBox(height: 16),
                        _buildIndicatorsAndSpeed(
                          effectiveData,
                          settings.units == 'imperial',
                          indicatorState.valueOrNull,
                          sim,
                        ),
                        const SizedBox(height: 32),
                        _buildSecondaryTelemetry(effectiveData),
                        const SizedBox(height: 24),
                        _buildConnectedDevices(connectionState.valueOrNull),
                        const SizedBox(height: 24),
                        _buildRideAnalytics(
                          effectiveData,
                          settings.units == 'imperial',
                          sim,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    BleConnectionState? state,
    bool simRunning,
  ) {
    final isConnected = state == BleConnectionState.ready;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine the label/icon/colour for the left status chip
    final btState = FlutterBluePlus.adapterStateNow;
    final bool btOff = btState == BluetoothAdapterState.off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        boxShadow: [
          BoxShadow(
            color: colorScheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    simRunning
                        ? Icons.science
                        : (btOff
                              ? Icons.bluetooth_disabled
                              : (isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_disabled)),
                    color: simRunning
                        ? const Color(0xFF00BFA5)
                        : (btOff ? colorScheme.error : colorScheme.secondary),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    simRunning
                        ? 'SIMULATING'
                        : (btOff
                              ? 'BLUETOOTH OFF'
                              : (isConnected ? 'LINKED' : 'DISCONNECTED')),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: simRunning
                          ? const Color(0xFF00BFA5)
                          : (btOff ? colorScheme.error : colorScheme.secondary),
                    ),
                  ),
                ],
              ),
              Text(
                'HEIMDALL',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.primaryContainer,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(bleServiceProvider).startScan();
                  _showDeviceSelector(context, ref);
                },
                child: Icon(
                  Icons.bluetooth,
                  color: isConnected
                      ? colorScheme.primary
                      : (state == BleConnectionState.wrongDevice
                            ? colorScheme.error
                            : colorScheme.outline),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorsAndSpeed(
    HelmetDataModel? data,
    bool isImperial,
    Map<String, bool>? indicatorState,
    SimulationState sim,
  ) {
    final rawSpeed = data?.speed ?? 0.0;
    final speed = isImperial ? rawSpeed * 0.621371 : rawSpeed;
    final unit = isImperial ? 'mph' : 'km/h';

    // Priority: Simulation > ASCII > Helmet Data
    bool isTurningLeft, isTurningRight, isBraking;

    if (sim.isRunning) {
      // Use simulation indicator state
      isTurningLeft = sim.indicator == IndicatorState.left;
      isTurningRight = sim.indicator == IndicatorState.right;
      isBraking = sim.isBraking;
    } else if (indicatorState != null) {
      // Use ASCII indicator state from background service
      isTurningLeft = indicatorState['leftIndicator'] ?? false;
      isTurningRight = indicatorState['rightIndicator'] ?? false;
      isBraking = indicatorState['brake'] ?? false;
    } else {
      // Fall back to helmet data
      isTurningLeft = data?.isTurningLeft ?? false;
      isTurningRight = data?.isTurningRight ?? false;
      isBraking = data?.isBraking ?? false;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IndicatorArrow(isActive: isTurningLeft, isLeft: true),
            IndicatorArrow(isActive: isTurningRight, isLeft: false),
          ],
        ),
        const SizedBox(height: 24),
        SpeedDisplay(speed: speed, unit: unit),
        if (isBraking) ...[const SizedBox(height: 24), _buildBrakeWarning()],
      ],
    );
  }

  Widget _buildBrakeWarning() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PulsingDot(),
          const SizedBox(width: 16),
          Text(
            'BRAKE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 16),
          _PulsingDot(),
        ],
      ),
    );
  }

  Widget _buildSecondaryTelemetry(HelmetDataModel? helmetData) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.health_and_safety, color: AppColors.secondary),
                    const SizedBox(height: 8),
                    Text(
                      'Crash Sensor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NORMAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(navigationProvider.notifier).state = 2,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: AppColors.surfaceContainerLowest,
                            child: Center(
                              child: Icon(
                                Icons.map,
                                size: 40,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            Icon(
                              Icons.explore,
                              size: 14,
                              color: AppColors.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MAP VIEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectedDevices(BleConnectionState? state) {
    final isConnected = state == BleConnectionState.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECTED DEVICES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.outlineVariant,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 12,
          child: Column(
            children: [
              if (isConnected)
                _buildDeviceItem(
                  icon: Icons.headset,
                  name: 'HELMET_V4',
                  status: 'Active Connection',
                  isConnected: true,
                )
              else
                Center(
                  child: Text(
                    'No Devices Linked',
                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
            : AppColors.surfaceContainerLow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.outline.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              color: isConnected ? AppColors.primary : AppColors.outline,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isConnected ? AppColors.primary : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            Icon(Icons.check_circle, color: AppColors.primary, size: 20)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Connect',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRideAnalytics(
    HelmetDataModel? data,
    bool isImperial,
    SimulationState sim,
  ) {
    final double rawDist = sim.isRunning
        ? 0.42 // Placeholder for mock distance in sim
        : 0.0;
    final double rawAvg = sim.isRunning
        ? sim.speed * 0.9
        : (data?.speed ?? 0.0);

    final distance = isImperial ? rawDist * 0.621371 : rawDist;
    final avgSpeed = isImperial ? rawAvg * 0.621371 : rawAvg;
    final distanceUnit = isImperial ? 'mi' : 'km';
    final speedUnit = isImperial ? 'mph' : 'km/h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE ANALYTICS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.outlineVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 12,
                child: Column(
                  children: [
                    Text(
                      distance.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'DISTANCE ($distanceUnit)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 12,
                child: Column(
                  children: [
                    Text(
                      avgSpeed.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      'AVG SPEED ($speedUnit)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeviceSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final bleService = ref.read(bleServiceProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Select Helmet Device',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Looking for MAC: 90:70:...',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => bleService.startScan(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<ScanResult>>(
                    stream: FlutterBluePlus.scanResults,
                    builder: (context, snapshot) {
                      final results = snapshot.data ?? [];
                      final connectedDevices = FlutterBluePlus.connectedDevices;
                      final targetName = Constants.helmetDeviceName
                          .toLowerCase();

                      // Convert to display objects
                      final List<Map<String, dynamic>> displayItems = [];

                      for (final d in connectedDevices) {
                        final mac = d.remoteId.str;
                        final name = d.platformName.isNotEmpty
                            ? d.platformName
                            : "Connected Device";
                        final isHelmet =
                            name.toLowerCase().contains(targetName) ||
                            mac.toUpperCase().startsWith("90:70");
                        displayItems.add({
                          'device': d,
                          'name': name,
                          'mac': mac,
                          'rssi': -20,
                          'isHelmet': isHelmet,
                          'status': 'Connected',
                        });
                      }

                      for (final r in results) {
                        // Avoid duplicates
                        if (connectedDevices.any(
                          (d) => d.remoteId == r.device.remoteId,
                        )) {
                          continue;
                        }

                        final mac = r.device.remoteId.str;
                        final name = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                  ? r.advertisementData.advName
                                  : "Unknown Device");
                        final isHelmet =
                            name.toLowerCase().contains(targetName) ||
                            mac.toUpperCase().startsWith("90:70");

                        displayItems.add({
                          'device': r.device,
                          'name': name,
                          'mac': mac,
                          'rssi': r.rssi,
                          'isHelmet': isHelmet,
                          'status': 'Available',
                        });
                      }

                      // Sort: Helmets first
                      displayItems.sort((a, b) {
                        final aH = a['isHelmet'] ? 1 : 0;
                        final bH = b['isHelmet'] ? 1 : 0;
                        if (aH != bH) return bH - aH;
                        return (b['rssi'] as int).compareTo(a['rssi'] as int);
                      });

                      if (displayItems.isEmpty) {
                        return const Center(
                          child: Text('Scanning for devices...'),
                        );
                      }

                      return ListView.builder(
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          final device = item['device'] as BluetoothDevice;
                          final isHelmet = item['isHelmet'] as bool;

                          return ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: isHelmet
                                  ? AppColors.secondary
                                  : AppColors.outline,
                            ),
                            title: Text(
                              isHelmet
                                  ? "${item['name']} (HELMET FOUND)"
                                  : item['name'],
                              style: TextStyle(
                                fontWeight: isHelmet
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              "MAC: ${item['mac']} • ${item['status']} • RSSI: ${item['rssi']}",
                            ),
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Connecting to ${item['name']}...',
                                  ),
                                ),
                              );

                              await bleService.stopScan();
                              await bleService.connect(device);

                              if (!context.mounted) return;
                              if (bleService.currentState ==
                                  BleConnectionState.ready) {
                                Navigator.pop(context);
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to initialize helmet services.',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error,
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.8),
                blurRadius: 12 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
