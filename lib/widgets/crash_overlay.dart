import "dart:async";
import "dart:ui";
import "package:flutter/material.dart";
import "../theme/app_colors.dart";

class CrashOverlay extends StatefulWidget {
  final int countdownSeconds;
  final VoidCallback onCancel;
  final VoidCallback onCallEmergency;
  final double latitude;
  final double longitude;

  const CrashOverlay({
    super.key,
    required this.countdownSeconds,
    required this.onCancel,
    required this.onCallEmergency,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<CrashOverlay> createState() => _CrashOverlayState();
}

class _CrashOverlayState extends State<CrashOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _pingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _pingAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 10;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pingController, curve: Curves.easeOut));

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onCallEmergency();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _pingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: AppColors.errorContainer.withValues(alpha: 0.2),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
            Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: Center(child: _buildCentralContent())),
                  _buildBottomActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(Icons.warning, color: AppColors.error, size: 24),
          SizedBox(width: 12),
          Text(
            'EMERGENCY ALERT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.primary,
            ),
          ),
          Spacer(),
          Text(
            'HEIMDALL',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildImpactVisualizer(),
        const SizedBox(height: 32),
        _buildCountdown(),
        const SizedBox(height: 32),
        _buildContextCard(),
      ],
    );
  }

  Widget _buildImpactVisualizer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.3,
          child: AnimatedBuilder(
            animation: _pingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pingAnimation.value,
                child: Container(
                  width: 256,
                  height: 256,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.car_crash,
                  size: 64,
                  color: AppColors.error,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        const Text(
          'AUTOMATIC SOS IN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _remainingSeconds.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 128,
                fontWeight: FontWeight.w900,
                letterSpacing: -4,
                color: Colors.white,
                height: 1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'SEC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContextCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.error.withValues(alpha: 0.6), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'GPS: ${widget.latitude.toStringAsFixed(4)}° N, ${widget.longitude.toStringAsFixed(4)}° W',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Significant impact detected. Dispatching emergency services and notifying your emergency contacts in $_remainingSeconds seconds.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "I'M OK",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Cancel Emergency Signal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onCallEmergency,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: const Center(
                child: Text(
                  'CALL EMERGENCY SERVICES NOW',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    final paint2 = Paint()
      ..color = AppColors.errorContainer.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.25),
      200,
      paint1,
    );

    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.75),
      200,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
