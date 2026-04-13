import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/ble_provider.dart';
import '../../services/navigation_service.dart';
import '../../services/settings_service.dart';
import '../../models/navigation_data.dart';

class GpsScreen extends ConsumerStatefulWidget {
  const GpsScreen({super.key});

  @override
  ConsumerState<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends ConsumerState<GpsScreen> {
  double _currentSpeed = 0.0;
  double _latitude = 0.0;

  @override
  Widget build(BuildContext context) {
    final helmetData = ref.watch(helmetDataStreamProvider);
    final navData = ref.watch(navigationStreamProvider);
    final settings = ref.watch(settingsProvider);
    final isImperial = settings.units == 'Imperial (mph)';

    final speedKmh = helmetData.valueOrNull?.speed ?? 0.0;
    _currentSpeed = isImperial ? speedKmh * 0.621371 : speedKmh;
    _latitude = helmetData.valueOrNull?.latitude ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          _buildMapBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(),
                const Spacer(),
                _buildBottomControls(navData.valueOrNull, isImperial),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Positioned.fill(
      child: Container(
        color: AppColors.surfaceContainerLowest,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _MapBackgroundPainter()),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface.withValues(alpha: 0.8),
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.surface.withValues(alpha: 0.4),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.bluetooth_connected, color: AppColors.primary, size: 20),
          Text(
            'HEIMDALL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: AppColors.onSurface,
            ),
          ),
          Icon(Icons.location_on, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildBottomControls(NavigationData? navData, bool isImperial) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: _buildSpeedCard(isImperial))],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(
                'Navigate to Safe Zone',
                Icons.shield,
                isPrimary: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildActionButton(
                'Share Location',
                Icons.share,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard(bool isImperial) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currentSpeed.toInt().toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          isImperial ? 'MPH' : 'KM/H',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 24,
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_4_bar,
                    size: 14,
                    color: _latitude != 0.0
                        ? AppColors.primary
                        : AppColors.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _latitude != 0.0 ? 'GPS OK' : 'GPS SEARCHING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _latitude != 0.0
                          ? AppColors.primary
                          : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    required bool isPrimary,
  }) {
    return Expanded(
      child: GestureDetector(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primaryContainer
                : AppColors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: isPrimary
                ? null
                : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPrimary
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurface,
                ),
              ),
              Icon(
                icon,
                size: 22,
                color: isPrimary
                    ? AppColors.onPrimaryContainer
                    : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceContainerHigh.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 20; i++) {
      final y = size.height * i / 20;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (var i = 0; i < 15; i++) {
      final x = size.width * i / 15;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final markerPaint = Paint()
      ..color = AppColors.tertiary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 8, markerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
