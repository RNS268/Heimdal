import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'providers/ble_provider.dart';
import 'services/analytics_service.dart';
import 'services/settings_service.dart';
import 'models/helmet_data.dart';
import 'theme/app_colors.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<LatLng> _ridePath = [];

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

    _posAnimation = Tween<LatLng>(begin: _currentPos, end: _currentPos).animate(
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
            _posAnimation = Tween<LatLng>(
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
    if (!hasValidGps) return;

    final nextPos = LatLng(data.latitude, data.longitude);

    // 1. Position Interpolation
    _posAnimation = Tween<LatLng>(
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

  @override
  void dispose() {
    _moveController.dispose();
    _headingController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for GPS updates
    ref.listen(helmetDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        _handleGpsUpdate(next.value!);
      }
    });

    final helmetData = ref.watch(helmetDataStreamProvider).valueOrNull;
    final analytics = ref.watch(analyticsProvider);
    final settings = ref.watch(settingsProvider);
    final isImperial = settings.units == 'Imperial (mph)';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                        color: AppColors.primary.withValues(alpha: 0.3),
                        strokeWidth: 8.0,
                      ),
                      Polyline(
                        points: _ridePath,
                        color: AppColors.primary,
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
          _buildHUDOverlay(helmetData, analytics, isImperial),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _performSearch(_searchController.text),
                child: const Icon(Icons.search,
                    color: AppColors.outline, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _performSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Where to, Rider?',
                    hintStyle: TextStyle(color: AppColors.outline, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  color: _isListening ? Colors.red : AppColors.primary,
                  size: 20,
                ),
              ),
            ],
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
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
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
    AnalyticsState analytics,
    bool isImperial,
  ) {
    final bool hasValidGps = (data?.latitude.abs() ?? 0) > 0.0001;
    final speed = data?.speed ?? 0;
    final displaySpeed = isImperial ? speed * 0.621371 : speed;
    final displayDistance =
        isImperial ? analytics.totalDistance * 0.621371 : analytics.totalDistance;
    final displayAvg =
        isImperial ? analytics.averageSpeed * 0.621371 : analytics.averageSpeed;
    final speedUnit = isImperial ? 'MPH' : 'KM/H';
    final distUnit = isImperial ? 'MI' : 'KM';

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
                    const Text('SPEED',
                        style:
                            TextStyle(fontSize: 8, color: AppColors.outline)),
                    Text('${displaySpeed.toInt()}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(speedUnit,
                        style: const TextStyle(
                            fontSize: 8, color: AppColors.primary)),
                  ],
                ),
              ),
              _buildHUDCard(
                child: Column(
                  children: [
                    const Text('LEAN ANGLE',
                        style:
                            TextStyle(fontSize: 8, color: AppColors.outline)),
                    Text('${_leanAngle.abs().toStringAsFixed(0)}°',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _leanAngle.abs() > 30
                                ? AppColors.tertiary
                                : AppColors.secondary)),
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
                child: _buildHUDCard(
                    child: _buildSmallStat('TIME', analytics.formattedTime)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHUDCard(
                    child: _buildSmallStat(
                        'DIST', '${displayDistance.toStringAsFixed(1)} $distUnit')),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: _buildHUDCard(
            width: double.infinity,
            child: Row(
              children: [
                Icon(
                  hasValidGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: hasValidGps ? AppColors.secondary : AppColors.error,
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
                                ? AppColors.secondary
                                : AppColors.error),
                      ),
                      Text(
                        hasValidGps
                            ? 'HEIMDALL LINK ACTIVE'
                            : 'SEARCHING FOR SATELLITES...',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
                if (hasValidGps)
                  const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 8, color: AppColors.outline)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    );
  }

  Widget _buildHUDCard({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
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
              color: AppColors.primary.withValues(alpha: 1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
