import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/navigation_data.dart';

class NavigationService {
  final _navigationController = StreamController<NavigationData>.broadcast();

  Stream<NavigationData> get navigationStream => _navigationController.stream;

  NavigationService() {
    // Service initialized, waiting for real navigation feed
  }

  void updateNavigationData(NavigationData data) {
    _navigationController.add(data);
  }

  void dispose() {
    _navigationController.close();
  }
}

final navigationServiceProvider = Provider<NavigationService>((ref) {
  final service = NavigationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final navigationStreamProvider = StreamProvider<NavigationData>((ref) {
  final service = ref.watch(navigationServiceProvider);
  return service.navigationStream;
});
