import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'providers/ble_provider.dart';
import 'providers/simulation_provider.dart';
import 'providers/ride_provider.dart';
import 'services/settings_service.dart';
import 'models/helmet_data.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:heimdall/screens/crash/crash_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<LatLng> _ridePath = [];
  bool _crashsequenceStarted = false;

  // Animation Controllers for Smooth Transitions
  late AnimationController _moveController;
  late Animation<LatLng> _posAnimation;
  late AnimationController _headingController;
  late Animation<double> _headingAnimation;

  LatLng _currentPos = const LatLng(17.3850, 78.4867);
  final double _currentHeading = 0.0;
  double _leanAngle = 0.0; // In degrees, calculated from accelerometer

  bool _isFirstFix = true;

  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _posAnimation = LatLngTween(begin: _currentPos, end: _currentPos).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutCubic),
    );

    _headingAnimation = Tween<double>(
      begin: _currentHeading,
      end: _currentHeading,
    ).animate(
      CurvedAnimation(parent: _headingController, curve: Curves.easeOut),
    );

    _usePhoneLocation();
    _initSpeech();
  }

  void _handleSimGpsUpdate(SimulationState sim) {
    final nextPos = LatLng(sim.latitude, sim.longitude);
    _posAnimation = LatLngTween(
      begin: _posAnimation.value,
      end: nextPos,
    ).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutCubic),
    );
    _moveController.forward(from: 0);

    final double nextHeadingRad = sim.heading * (math.pi / 180);
    _headingAnimation = Tween<double>(
      begin: _headingAnimation.value,
      end: nextHeadingRad,
    ).animate(
      CurvedAnimation(parent: _headingController, curve: Curves.easeOut),
    );
    _headingController.forward(from: 0);

    setState(() {
      _leanAngle = sim.leanAngle;
      _currentPos = nextPos;
    });
    _updatePath(nextPos);
    if (_isFirstFix) {
      _isFirstFix = false;
      _animatedMapMove(nextPos, 15.0);
    }
  }

  final _nominatim = Nominatim(userAgent: 'com.heimdall.helmet');

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    try {
      final results = await _nominatim.searchByName(query: query, limit: 1);
      if (results.isNotEmpty) {
        final result = results.first;
        final latLng = LatLng(result.lat, result.lon);
        _animatedMapMove(latLng, 15.0);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _searchController.text = _lastWords;
        });
        if (result.finalResult) {
          _stopListening();
          _performSearch(_lastWords);
        }
      });
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _usePhoneLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (_isFirstFix) {
        if (mounted) {
          setState(() {
            _currentPos = LatLng(position.latitude, position.longitude);
            _posAnimation = LatLngTween(
              begin: _currentPos,
              end: _currentPos,
            ).animate(_moveController);
            _isFirstFix = false;
          });
          _animatedMapMove(_currentPos, 15.0);
        }
      }
    } catch (e) {
      debugPrint('Error getting phone location: $e');
    }
  }

  void _handleGpsUpdate(HelmetDataModel data) {
    final bool hasValidGps = data.latitude.abs() > 0.0001;
    if (!hasValidGps) {
      setState(() {
        _leanAngle = 0.0;
      });
      return;
    }

    final nextPos = LatLng(data.latitude, data.longitude);

    // 1. Position Interpolation
    _posAnimation = LatLngTween(
      begin: _posAnimation.value,
      end: nextPos,
    ).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutCubic),
    );
    _moveController.forward(from: 0);

    // 2. Heading Smoothing
    if (_ridePath.isNotEmpty) {
      final double nextHeading =
          const Distance().bearing(_ridePath.last, nextPos) * (math.pi / 180);

      _headingAnimation = Tween<double>(
        begin: _headingAnimation.value,
        end: nextHeading,
      ).animate(
        CurvedAnimation(parent: _headingController, curve: Curves.easeOut),
      );
      _headingController.forward(from: 0);
    }

    // 3. Lean Angle Calculation
    setState(() {
      _leanAngle = math.atan2(data.ay, data.az) * (180 / math.pi);
      _currentPos = nextPos;
    });

    // 4. State Management
    _updatePath(nextPos);
    _updateCamera(nextPos, data.crash);
  }

  void _updatePath(LatLng pos) {
    if (_ridePath.isEmpty) {
      if (mounted) setState(() => _ridePath.add(pos));
      return;
    }

    final double distance = const Distance().as(
      LengthUnit.Meter,
      _ridePath.last,
      pos,
    );

    if (distance > 3) {
      if (mounted) {
        setState(() {
          _ridePath.add(pos);
          if (_ridePath.length > 1000) _ridePath.removeAt(0);
        });
      }
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _updateCamera(LatLng pos, bool isCrash) {
    if (_isFirstFix) {
      _isFirstFix = false;
      _animatedMapMove(pos, 15.0);
    } else if (isCrash) {
      _animatedMapMove(pos, 18.0);
    }
  }

  Future<void> _handleCrashSequence() async {
    if (_crashsequenceStarted) return;
    _crashsequenceStarted = true;

    // 1. Play sound
    final player = AudioPlayer();
    try {
      // Try Asset first (Standard approach)
      await player.setAsset('assets/sounds/crash.m4a');
      player.play();
    } catch (_) {
      try {
        // Fallback to local Mac path
        const soundPath = '/Users/Shashank/Downloads/Car_Crash_Sound_Effect_two_different_sounds_128KBPS (mp3cut.net)';
        await player.setFilePath(soundPath);
        player.play();
      } catch (e) {
        debugPrint('Error playing crash sound: $e. Using fallback alert.');
        // Fallback: use platform channel tone
        try {
          const MethodChannel('com.heimdall.helmet/emergency_calls').invokeMethod('startSosTone');
        } catch (_) {}
      }
    }

    // 2. Intense vibration
    for (int i = 0; i < 8; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // 3. 5s delay
    await Future.delayed(const Duration(seconds: 5));

    // 4. Trigger SOS (Show CrashScreen)
    if (mounted) {
      ref.read(simulationProvider.notifier).stop(); // End virtual ride
      showCrashOverlay(context);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _headingController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(simulationProvider);

    // Seed simulation origin from phone GPS once when it starts
    ref.listen(simulationProvider, (prev, next) {
      if (!( prev?.isRunning ?? false) && next.isRunning) {
        // Just started: seed origin
        final simNotifier = ref.read(simulationProvider.notifier);
        simNotifier.start(lat: _currentPos.latitude, lng: _currentPos.longitude);
        setState(() => _ridePath.clear());
      }
    });

    // Feed simulation GPS into map when active
    if (sim.isRunning) {
      ref.listen(simulationProvider, (previous, next) {
        if (next.isRunning) {
          _handleSimGpsUpdate(next);
          if (next.isCrash) {
            _handleCrashSequence();
          }
        } else if (previous?.isRunning ?? false) {
          setState(() {
            _leanAngle = 0.0;
          });
        }
      });
    } else {
      // Listen for real GPS updates from BLE
      ref.listen(helmetDataStreamProvider, (previous, next) {
        if (next.hasValue) {
          _handleGpsUpdate(next.value!);
        } else if (previous?.hasValue ?? false) {
          setState(() {
            _leanAngle = 0.0;
          });
        }
      });
    }

    final settings = ref.watch(settingsProvider);
    final isImperial = settings.units == 'imperial';
    
    final bleState = ref.watch(bleConnectionStateProvider).valueOrNull;
    final isConnected = bleState == BleConnectionState.ready || bleState == BleConnectionState.connected;
    final ride = ref.watch(rideProvider);
    final rideDuration = ref.watch(rideDurationProvider).valueOrNull ?? Duration.zero;

    final helmetDataAsync = ref.watch(helmetDataStreamProvider);
    final helmetData = sim.isRunning ? sim.toHelmetData() : (isConnected ? helmetDataAsync.valueOrNull : null);
    if (!sim.isRunning && !isConnected && _leanAngle != 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _leanAngle = 0.0;
        });
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _moveController,
            builder: (context, child) {
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _posAnimation.value,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.heimdall.helmet',
                    tileBuilder: (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -0.9, 0, 0, 0, 255, // R
                          0, -0.9, 0, 0, 255, // G
                          0, 0, -0.9, 0, 255, // B
                          0, 0, 0, 1, 0, // A
                        ]),
                        child: tileWidget,
                      );
                    },
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _ridePath,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        strokeWidth: 8.0,
                      ),
                      Polyline(
                        points: _ridePath,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 3.0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _posAnimation.value,
                        width: 60,
                        height: 60,
                        child: _buildAnimatedMarker(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          _buildTopSearchBar(),
          _buildHUDOverlay(helmetData, isImperial, sim, ride, rideDuration, isConnected),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _performSearch(_searchController.text),
                  child: Icon(Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _performSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Where to, Rider?',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMarker() {
    return AnimatedBuilder(
      animation: _headingAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _headingAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _MarkerPulse(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.navigation, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHUDOverlay(
    HelmetDataModel? data,
    bool isImperial,
    SimulationState sim,
    RideState ride,
    Duration rideDuration,
    bool isConnected,
  ) {
    final bool hasValidGps = (data?.latitude.abs() ?? 0) > 0.0001;
    final speed = data?.speed ?? 0;
    final displaySpeed = isImperial ? speed * 0.621371 : speed;
    const displayDistance = 0.0;
    const displayAvg = 0.0;
    final speedUnit = isImperial ? 'MPH' : 'KM/H';
    final distUnit = isImperial ? 'MI' : 'KM';

    String formatDuration(Duration d) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String mm = twoDigits(d.inMinutes.remainder(60));
      String ss = twoDigits(d.inSeconds.remainder(60));
      return "${twoDigits(d.inHours)}:$mm:$ss";
    }

    return Column(
      children: [
        const SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHUDCard(
                child: Column(
                  children: [
                    Text('SPEED',
                        style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context).colorScheme.outline)),
                    Text('${displaySpeed.toInt()}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(speedUnit,
                        style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
              _buildHUDCard(
                child: Column(
                  children: [
                    Text('LEAN ANGLE',
                        style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context).colorScheme.outline)),
                    Text('${_leanAngle.abs().toStringAsFixed(0)}°',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _leanAngle.abs() > 30
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.secondary)),
                    Text(_leanAngle > 0 ? 'RIGHT' : 'LEFT',
                        style: TextStyle(
                            fontSize: 8,
                            color: _leanAngle > 0
                                ? Colors.greenAccent
                                : Colors.orangeAccent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _buildHUDCard(child: _buildSmallStat('TIME', formatDuration(rideDuration))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHUDCard(
                    child: _buildSmallStat('DIST',
                        '${displayDistance.toStringAsFixed(1)} $distUnit')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHUDCard(
                    child: _buildSmallStat(
                        'AVG', '${displayAvg.toStringAsFixed(1)} $speedUnit')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: _buildHUDCard(
            width: double.infinity,
            child: Row(
              children: [
                Icon(
                  hasValidGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: hasValidGps
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasValidGps ? 'LIVE TRACKING' : 'SIGNAL LOST',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: hasValidGps
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error),
                      ),
                      Text(
                        hasValidGps
                            ? 'HEIMDALL LINK ACTIVE'
                            : 'SEARCHING FOR SATELLITES...',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (hasValidGps)
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        ),
        // ── Map Action Buttons ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  ride.isRecording ? 'END RIDE' : 'START RIDE',
                  ride.isRecording ? Icons.stop_circle : Icons.play_circle_fill,
                  onTap: isConnected ? () {
                    final notifier = ref.read(rideProvider.notifier);
                    if (ride.isRecording) {
                      notifier.stopRide();
                    } else {
                      notifier.startRide();
                    }
                  } : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connect helmet to start ride recording')),
                    );
                  },
                  isDanger: ride.isRecording,
                  isEnabled: isConnected,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    _usePhoneLocation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Refreshing GPS position...'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }

  Widget _buildHUDCard({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    required VoidCallback onTap,
    bool isDanger = false,
    bool isEnabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = isDanger ? colorScheme.error : colorScheme.secondary;
    final buttonBackground = isDanger
        ? colorScheme.error.withValues(alpha: 0.2)
        : colorScheme.secondary.withValues(alpha: 0.2);
    final buttonBorder = isDanger
        ? colorScheme.error.withValues(alpha: 0.5)
        : colorScheme.secondary.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: !isEnabled
              ? colorScheme.outline.withValues(alpha: 0.1)
              : buttonBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !isEnabled
                ? colorScheme.outline.withValues(alpha: 0.1)
                : buttonBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: !isEnabled
                    ? colorScheme.outline.withValues(alpha: 0.4)
                    : buttonColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: !isEnabled
                    ? colorScheme.outline.withValues(alpha: 0.4)
                    : buttonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerPulse extends StatefulWidget {
  @override
  State<_MarkerPulse> createState() => _MarkerPulseState();
}

class _MarkerPulseState extends State<_MarkerPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
          width: 60 * _controller.value,
          height: 60 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}
