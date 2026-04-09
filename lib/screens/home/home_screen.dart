import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/speed_display.dart';
import '../../widgets/indicator_arrow.dart';
import '../../providers/ble_provider.dart';
import '../../models/helmet_data.dart';
import '../../services/analytics_service.dart';
import '../../providers/navigation_provider.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';

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
    final analytics = ref.watch(analyticsProvider);
    final settings = ref.watch(settingsProvider);
    final isImperial = settings.units == 'Imperial (mph)';

    final state = connectionState.valueOrNull;
    final isConnected = state == BleConnectionState.ready;
    final isVerifying = state == BleConnectionState.verifying;
    final isWrong = state == BleConnectionState.wrongDevice;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, ref, state),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isVerifying)
                          _buildStatusBanner(
                            'Verifying Module Status...',
                            AppColors.primary,
                          ),
                        if (isWrong)
                          _buildStatusBanner(
                            'Wrong Device Connected. Please switch.',
                            AppColors.error,
                          ),
                        if (isConnected && helmetData.valueOrNull != null)
                          _buildStatusBanner(
                            'System Ready. Trip Active.',
                            AppColors.secondary,
                          ),
                        const SizedBox(height: 16),
                        _buildIndicatorsAndSpeed(helmetData.valueOrNull),
                        const SizedBox(height: 32),
                        _buildSecondaryTelemetry(helmetData.valueOrNull),
                        const SizedBox(height: 24),
                        _buildConnectedDevices(connectionState.valueOrNull),
                        const SizedBox(height: 24),
                        _buildRideAnalytics(analytics, isImperial),
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
  ) {
    final isConnected = state == BleConnectionState.ready;

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
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'LINKED' : 'DISCONNECTED',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const Text(
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
                      ? AppColors.primary
                      : (state == BleConnectionState.wrongDevice
                            ? AppColors.error
                            : AppColors.outline),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorsAndSpeed(HelmetDataModel? data) {
    final speed = data?.speed ?? 0.0;
    final isTurningLeft = data?.isTurningLeft ?? false;
    final isTurningRight = data?.isTurningRight ?? false;
    final isBraking = data?.isBraking ?? false;

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
        SpeedDisplay(speed: speed),
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
          const Text(
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
                child: const Column(
                  children: [
                    Icon(Icons.health_and_safety, color: AppColors.secondary),
                    SizedBox(height: 8),
                    Text(
                      'Crash Sensor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.outline,
                      ),
                    ),
                    SizedBox(height: 4),
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
                            child: const Center(
                              child: Icon(
                                Icons.map,
                                size: 40,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            Icon(
                              Icons.explore,
                              size: 14,
                              color: AppColors.tertiary,
                            ),
                            SizedBox(width: 4),
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
        const Text(
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
                const Center(
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
                  style: const TextStyle(
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
            const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
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

  Widget _buildRideAnalytics(AnalyticsState analytics, bool isImperial) {
    final distance = isImperial
        ? analytics.totalDistance * 0.621371
        : analytics.totalDistance;
    final avgSpeed = isImperial
        ? analytics.averageSpeed * 0.621371
        : analytics.averageSpeed;
    final distanceUnit = isImperial ? 'mi' : 'km';
    final speedUnit = isImperial ? 'mph' : 'km/h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
              child: _buildAnalyticsCard('Time', analytics.formattedTime),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                'Dist',
                '${distance.toStringAsFixed(2)} $distanceUnit',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                'Avg Spd',
                '${avgSpeed.toStringAsFixed(1)} $speedUnit',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final scanResults = ref.watch(scanResultsProvider);
          final bleService = ref.read(bleServiceProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                const Text(
                  'Select Helmet Device',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: scanResults.when(
                    data: (results) {
                      if (results.isEmpty) {
                        return const Center(
                          child: Text('Scanning for devices...'),
                        );
                      }
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final device = results[index].device;
                          return ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(
                              device.platformName.isEmpty
                                  ? 'Unknown'
                                  : device.platformName,
                            ),
                            subtitle: Text(device.remoteId.toString()),
                            onTap: () {
                              bleService.stopScan();
                              bleService.connect(device);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
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
