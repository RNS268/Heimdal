import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/display_metrics_service.dart';

/// Provides access to stored display metrics
final displayMetricsProvider = FutureProvider<DisplayMetrics>((ref) async {
  return DisplayMetricsService.getStoredMetrics();
});

/// Get display metrics (synchronous access for already loaded data)
final displayMetricsDataProvider = StateProvider<DisplayMetrics?>((ref) {
  ref.listen(displayMetricsProvider, (previous, next) {
    ref.controller.state = next.valueOrNull;
  });
  
  return null;
});
