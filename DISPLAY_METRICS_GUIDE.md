# Display Metrics Service - Usage Guide

## Overview
The Display Metrics Service automatically detects and stores the phone's display margins (notch, safe areas, status bar, navigation bar) on the first app launch. This allows the app to adjust its UI sizes responsively based on the device's physical constraints.

## Files Created
- `lib/services/display_metrics_service.dart` - Core service for metrics detection and persistence
- `lib/providers/display_metrics_provider.dart` - Riverpod providers for accessing metrics

## How It Works
1. **First Launch Detection**: On the very first app launch, the service captures the device's display metrics using `MediaQuery`
2. **Persistent Storage**: Metrics are saved to `SharedPreferences` with key `'heimdall.display_metrics'`
3. **App-Wide Access**: Metrics are available through Riverpod providers throughout the app
4. **Responsive UI**: Use metrics to adjust component sizes and padding based on device characteristics

## Accessing Display Metrics

### In ConsumerWidget/ConsumerStatefulWidget
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Async access - waits for metrics to load
  final metricsAsync = ref.watch(displayMetricsProvider);
  
  return metricsAsync.when(
    data: (metrics) {
      return Column(
        children: [
          // Get safe area padding
          Padding(
            padding: metrics.getResponsivePadding(
              defaultHorizontal: 16,
              defaultVertical: 24,
            ),
            child: Text('Safe area content'),
          ),
          // Get content dimensions
          Container(
            width: metrics.getSafeWidth(),
            height: metrics.getAppAreaHeight(),
            child: Text('Responsive container'),
          ),
        ],
      );
    },
    loading: () => const CircularProgressIndicator(),
    error: (err, stack) => Text('Error: $err'),
  );
}
```

## Available Metrics

### Raw Metrics
- `statusBarHeight` - Height of status bar (clock, signal, battery)
- `navigationBarHeight` - Height of system navigation bar
- `leftSafeArea` - Padding from left edge (notch, punch hole)
- `rightSafeArea` - Padding from right edge
- `topSafeArea` - Total safe padding from top
- `bottomSafeArea` - Total safe padding from bottom
- `screenWidth` - Total screen width in logical pixels
- `screenHeight` - Total screen height in logical pixels
- `devicePixelRatio` - Device pixel ratio for high-DPI calculations

### Helper Methods
- `getResponsivePadding()` - Get `EdgeInsets` with safe area considered
- `getSafeWidth()` - Get usable content width excluding side safe areas
- `getSafeHeight()` - Get usable content height excluding top/bottom safe areas
- `getAppAreaHeight()` - Get height excluding status bar and navigation bar

## Example: Responsive Layout

```dart
class MyResponsiveScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(displayMetricsProvider);
    
    return metricsAsync.when(
      data: (metrics) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              // Automatically account for notches, punch holes, etc.
              padding: metrics.getResponsivePadding(),
              child: Column(
                children: [
                  // Header with adjusted height
                  Container(
                    height: 80 + metrics.topSafeArea,
                    color: Colors.blue,
                    child: Center(
                      child: Text(
                        'Header',
                        style: TextStyle(
                          fontSize: 24 * metrics.devicePixelRatio,
                        ),
                      ),
                    ),
                  ),
                  // Content area using safe width
                  Expanded(
                    child: Container(
                      width: metrics.getSafeWidth(),
                      color: Colors.grey,
                      child: Text('Content area'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
```

## First Launch Behavior
On the app's first launch:
1. Display metrics are automatically captured from `MediaQuery`
2. Values are stored in `SharedPreferences`
3. A flag (`'heimdall.is_first_launch'`) is set to `false`
4. Subsequent launches use the stored metrics (faster, no re-detection)

To force re-detection (for testing):
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('heimdall.is_first_launch', true);
await prefs.remove('heimdall.display_metrics');
// App will re-detect on next launch
```

## Integration in app.dart
The service is automatically initialized in `MainNavigationScreen.initState()`:
```dart
await DisplayMetricsService.initializeMetrics(context);
```

This runs after the first frame is rendered, ensuring `MediaQuery` data is available.

## Use Cases
1. **Notch/Punch Hole Handling** - Automatically detect and avoid drawing under notches
2. **Responsive Padding** - Adjust margins based on safe area insets
3. **Dynamic Font Sizes** - Scale text based on `devicePixelRatio`
4. **Full-Screen Overlays** - Position modals and alerts within safe areas
5. **Custom Navigation Bars** - Account for system navigation bar height
6. **Device-Specific Layouts** - Different layouts for different device types

## Device Examples

### iPhone 14 Pro (with Dynamic Island)
- `topSafeArea`: ~59pt
- `leftSafeArea`: 0
- `rightSafeArea`: 0
- `bottomSafeArea`: ~34pt

### Samsung Galaxy S23 (with notch)
- `topSafeArea`: ~72dp (status bar + notch)
- `leftSafeArea`: 0
- `rightSafeArea`: 0
- `bottomSafeArea`: ~84dp (navigation bar)

### Standard Device
- `topSafeArea`: ~24dp (status bar only)
- Safe areas: 0
- `bottomSafeArea`: ~48dp (navigation bar)
