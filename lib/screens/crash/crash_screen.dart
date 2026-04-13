import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/crash_detection_service.dart';
import '../../services/emergency_alert_service.dart';
import '../../services/settings_service.dart';

const MethodChannel _sosToneChannel = MethodChannel('com.heimdall.helmet/emergency_calls');

// ─── Route helper ─────────────────────────────────────────────────────────────
/// Call this from anywhere to take over the entire screen with CrashScreen.
void showCrashOverlay(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const CrashScreen()),
    (_) => false, // removes ALL previous routes
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CrashScreen extends ConsumerStatefulWidget {
  const CrashScreen({super.key});

  @override
  ConsumerState<CrashScreen> createState() => _CrashScreenState();
}

class _CrashScreenState extends ConsumerState<CrashScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 10;

  int _remaining = _totalSeconds;
  bool _sosSent = false;
  bool _isOk = false;
  bool _awaitingManualSos = false;

  Timer? _countdownTimer;
  late AnimationController _pulseController;

  double? _latitude;
  double? _longitude;
  bool _gpsLoading = true;

  @override
  void initState() {
    super.initState();

    // Force full-screen, hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fetchLocation();
    _startCountdown();
    _startSosTone();
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopSosTone();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _gpsLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _gpsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ─── Countdown ────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining > 0) {
        _startSosTone(); // Keep tone alive during countdown
        HapticFeedback.vibrate(); // Intense haptic feedback
      }
      if (_remaining <= 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _startSosTone() {
    if (!mounted || _sosSent || _isOk) return;
    _invokeToneMethod('startSosTone');
  }

  void _stopSosTone() {
    _invokeToneMethod('stopSosTone');
  }

  void _invokeToneMethod(String method) {
    try {
      _sosToneChannel.invokeMethod<bool>(method);
    } on PlatformException catch (e) {
      debugPrint('SOS tone platform error: ${e.message}');
    }
  }

  // ─── SOS ──────────────────────────────────────────────────────────────────

  Future<void> _triggerSOS() async {
    if (_sosSent || _isOk) return;
    final autoSosEnabled = ref.read(settingsProvider).autoSOS;
    if (!autoSosEnabled) {
      if (mounted) {
        setState(() => _awaitingManualSos = true);
      }
      return;
    }
    setState(() => _sosSent = true);
    _stopSosTone();

    final alertService = ref.read(emergencyAlertServiceProvider);
    final latitude = _latitude ?? 0.0;
    final longitude = _longitude ?? 0.0;

    // 1. Send SMS to all contacts
    await alertService.sendCrashAlerts(
      latitude: latitude,
      longitude: longitude,
    );

    // 2. Wait before calling the same emergency number
    await Future.delayed(const Duration(seconds: 2));

    await alertService.callEmergencyContact(
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ─── I'M OK ───────────────────────────────────────────────────────────────

  void _handleImOk() {
    _countdownTimer?.cancel();
    _stopSosTone();
    setState(() => _isOk = true);
    ref.read(crashDetectionServiceProvider).cancelCrashAlert();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    });
  }

  Future<void> _sendSosManually() async {
    if (_sosSent || _isOk) return;
    setState(() {
      _awaitingManualSos = false;
      _sosSent = true;
    });
    _stopSosTone();

    final alertService = ref.read(emergencyAlertServiceProvider);
    final latitude = _latitude ?? 0.0;
    final longitude = _longitude ?? 0.0;

    await alertService.sendCrashAlerts(
      latitude: latitude,
      longitude: longitude,
    );

    await Future.delayed(const Duration(seconds: 2));

    await alertService.callEmergencyContact(
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // disable back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _sosSent
                        ? _buildSOSSentState()
                        : _isOk
                        ? _buildOkState()
                        : _buildCountdownState(),
                  ),
                  if (!_sosSent && !_isOk) _buildBottomActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Background ───────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Theme.of(context).colorScheme.error.withValues(
                  alpha: 0.08 + _pulseController.value * 0.06,
                ),
                Colors.black,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error.withValues(
                alpha: 0.5 + _pulseController.value * 0.5,
              ),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'EMERGENCY ALERT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const Spacer(),
          Text(
            'HEIMDALL',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Countdown State ──────────────────────────────────────────────────────

  Widget _buildCountdownState() {
    final progress = _remaining / _totalSeconds;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PulsingCrashIcon(),
        const SizedBox(height: 32),
        // Circular countdown arc
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Builder(
                builder: (context) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return CustomPaint(
                    size: const Size(160, 160),
                    painter: _ArcPainter(
                      progress: progress,
                      errorColor: colorScheme.error,
                      warningColor: Colors.deepOrange,
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _remaining.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    'SEC',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AUTOMATIC SOS IN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _buildGpsCard(),
        if (_awaitingManualSos) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-SOS is off. Confirm manual SOS below if needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── GPS Card ─────────────────────────────────────────────────────────────

  Widget _buildGpsCard() {
    String gpsText;
    if (_gpsLoading) {
      gpsText = 'Acquiring GPS...';
    } else if (_latitude == null || _longitude == null) {
      gpsText = 'GPS unavailable';
    } else {
      gpsText =
          '${_latitude!.toStringAsFixed(5)}° N,  ${_longitude!.toStringAsFixed(5)}° E';
    }

    final contacts = ref.watch(settingsProvider).emergencyContacts;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _gpsLoading
                    ? Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Acquiring GPS...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        gpsText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.people,
                color: Theme.of(context).colorScheme.tertiary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contacts.isEmpty
                      ? 'No contacts set — will call 112'
                      : 'Alerting: ${contacts.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SOS Sent State ───────────────────────────────────────────────────────

  Widget _buildSOSSentState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
            border: Border.all(
              color: Theme.of(context).colorScheme.error,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.cell_tower,
            color: Theme.of(context).colorScheme.error,
            size: 56,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'SOS SENT',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Emergency contacts notified.\nCall in progress.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        _buildGpsCard(),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _handleImOk,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                "I'M SAFE — CANCEL ALERT",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── OK State ─────────────────────────────────────────────────────────────

  Widget _buildOkState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary,
          size: 100,
        ),
        const SizedBox(height: 24),
        Text(
          "ALERT CANCELLED",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Returning to main screen...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ─── Bottom Actions ───────────────────────────────────────────────────────

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // I'M OK button
          GestureDetector(
            onTap: _handleImOk,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(
                        alpha: 0.85 + _pulseController.value * 0.15,
                      ),
                      Theme.of(context).colorScheme.primaryContainer.withValues(
                        alpha: 0.85 + _pulseController.value * 0.15,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(
                        alpha: 0.2 + _pulseController.value * 0.2,
                      ),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "I'M OK",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cancel Emergency Signal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Manual call now
          GestureDetector(
            onTap: _triggerSOS,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  'CALL EMERGENCY SERVICES NOW',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
          if (_awaitingManualSos) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _sendSosManually,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'SEND SOS NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Arc Painter (countdown ring) ────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color errorColor;
  final Color warningColor;
  _ArcPainter({
    required this.progress,
    required this.errorColor,
    required this.warningColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Progress arc (red, shrinks as time runs out)
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = progress > 0.4 ? errorColor : warningColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.errorColor != errorColor ||
      old.warningColor != warningColor;
}

// ─── Pulsing Crash Icon ───────────────────────────────────────────────────────

class _PulsingCrashIcon extends StatefulWidget {
  const _PulsingCrashIcon();

  @override
  State<_PulsingCrashIcon> createState() => _PulsingCrashIconState();
}

class _PulsingCrashIconState extends State<_PulsingCrashIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ring = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _ring.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.car_crash,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
