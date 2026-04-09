import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/helmet_data.dart';

class GpsTrackingService {
  final _locationController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _positionSubscription;

  final List<Position> _ridePath = [];
  bool _isTracking = false;
  Position? _lastKnownPosition;

  Stream<Position> get locationStream => _locationController.stream;
  List<Position> get ridePath => List.unmodifiable(_ridePath);
  bool get isTracking => _isTracking;
  Position? get lastKnownPosition => _lastKnownPosition;

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    _ridePath.clear();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _lastKnownPosition = position;
        _ridePath.add(position);
        _locationController.add(position);
      },
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  void clearPath() {
    _ridePath.clear();
  }

  void updateFromHelmetData(HelmetDataModel data) {
    if (data.latitude != 0.0 && data.longitude != 0.0) {
      final position = Position(
        latitude: data.latitude,
        longitude: data.longitude,
        timestamp: data.timestamp,
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: data.speed,
        speedAccuracy: 0,
      );
      _lastKnownPosition = position;
      _locationController.add(position);
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return _lastKnownPosition;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return _lastKnownPosition;
    }
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

final gpsTrackingServiceProvider = Provider<GpsTrackingService>((ref) {
  final service = GpsTrackingService();
  ref.onDispose(() => service.dispose());
  return service;
});

final currentPositionProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(gpsTrackingServiceProvider);
  return service.locationStream;
});

final ridePathProvider = StateProvider<List<Position>>((ref) => []);

final isGpsTrackingProvider = StateProvider<bool>((ref) => false);
