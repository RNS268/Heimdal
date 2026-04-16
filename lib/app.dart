import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/crash/crash_screen.dart';
import 'screens/music/music_screen.dart';
import 'screens/raw_data/raw_data_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'map_screen.dart';
import 'providers/navigation_provider.dart';
import 'services/crash_detection_service.dart';
import 'providers/ble_provider.dart';
import 'services/settings_service.dart';
import 'providers/simulation_provider.dart';
import 'services/display_metrics_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HeimdallApp extends ConsumerWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final settings = ref.watch(settingsProvider);
      
      // Global Crash/SOS listener
      ref.listen<bool>(crashDetectedProvider, (prev, isCrash) {
        if (isCrash) {
          // Intense sustained vibration sequence
          HapticFeedback.vibrate();
          for (int i = 1; i < 4; i++) {
            Future.delayed(Duration(milliseconds: i * 400), () {
              HapticFeedback.vibrate();
            });
          }
          // Rapid heavy hits for texture
          for (int i = 0; i < 8; i++) {
            Future.delayed(Duration(milliseconds: i * 100), () {
              HapticFeedback.heavyImpact();
            });
          }
          // Sound
          SystemSound.play(SystemSoundType.alert);
          
          // Navigation to crash screen
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/crash', (_) => false);
        }
      });

      return MaterialApp(
        title: 'HEIMDALL',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: settings.theme == 'dark'
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: const MainNavigationScreen(),
        routes: {
          '/crash': (context) => const CrashScreen(),
          '/music': (context) => const MusicScreen(),
          '/gps': (context) => const MapScreen(),
          '/raw': (context) => const RawDataScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      );
    } catch (e) {
      print('❌ [APP] Build error: $e');
      return MaterialApp(
        home: Scaffold(body: Center(child: Text('App Error: $e'))),
      );
    }
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const RawDataScreen(),
    const MapScreen(),
    const MusicScreen(),
    const SettingsScreen(),
  ];

  double _previousSpeed = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize non-BLE app services after first frame.
    // The helmet BLE connection should stay in the foreground flow unless the
    // user explicitly starts the autonomous background monitor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDisplayMetrics();
    });
  }

  Future<void> _initializeDisplayMetrics() async {
    try {
      await DisplayMetricsService.initializeMetrics(context);
      print('✓ [APP] Display metrics initialized');
    } catch (e) {
      print('⚠️ [APP] Display metrics init failed: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      try {
        // Real BLE data
        ref.listen(helmetDataStreamProvider, (previous, next) {
          if (!next.hasValue) return;
          final data = next.value!;
          ref.read(crashDetectionServiceProvider).checkCrash(
            crashFlag: data.crash,
            currentSpeed: data.speed,
            previousSpeed: _previousSpeed,
            ax: data.ax,
            ay: data.ay,
            az: data.az,
          );
          _previousSpeed = data.speed;
        });

        // Simulation data
        ref.listen(simulatedHelmetDataProvider, (previous, next) {
          final data = next.valueOrNull;
          if (data == null) return;
          ref.read(crashDetectionServiceProvider).checkCrash(
            crashFlag: data.crash,
            currentSpeed: data.speed,
            previousSpeed: _previousSpeed,
            ax: data.ax,
            ay: data.ay,
            az: data.az,
          );
          _previousSpeed = data.speed;
        });
      } catch (e) {
        print('⚠️ [APP] Data stream error: $e');
      }

      final currentIndex = ref.watch(navigationProvider);

      return Scaffold(
        body: IndexedStack(index: currentIndex, children: _screens),
        bottomNavigationBar: _buildBottomNav(context, currentIndex),
      );
    } catch (e) {
      print('❌ [NAV] Build error: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Navigation Error: $e'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: colorScheme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0, currentIndex, colorScheme),
              _buildNavItem(
                Icons.analytics,
                'Raw Data',
                1,
                currentIndex,
                colorScheme,
              ),
              _buildNavItem(
                Icons.explore,
                'Maps',
                2,
                currentIndex,
                colorScheme,
              ),
              _buildNavItem(
                Icons.music_note,
                'Music',
                3,
                currentIndex,
                colorScheme,
              ),
              _buildNavItem(
                Icons.settings,
                'Settings',
                4,
                currentIndex,
                colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    int currentIndex,
    ColorScheme colorScheme,
  ) {
    final isSelected = currentIndex == index;
    final unselectedColor = colorScheme.outline;

    return GestureDetector(
      onTap: () => ref.read(navigationProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : unselectedColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
