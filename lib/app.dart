import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/home/home_screen.dart';
import 'screens/crash/crash_screen.dart';
import 'screens/music/music_screen.dart';
import 'screens/raw_data/raw_data_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'map_screen.dart';
import 'providers/navigation_provider.dart';
import 'services/crash_detection_service.dart';
import 'services/background_service.dart';
import 'providers/ble_provider.dart';
import 'services/settings_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class HeimdallApp extends ConsumerWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final settings = ref.watch(settingsProvider);
      return MaterialApp(
        title: 'HEIMDALL',
        debugShowCheckedModeBanner: false,
        theme: settings.theme == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme,
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
        home: Scaffold(
          body: Center(
            child: Text('App Error: $e'),
          ),
        ),
      );
    }
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const RawDataScreen(),
    const MapScreen(),
    const MusicScreen(),
    const SettingsScreen(),
  ];

  StreamSubscription<bool>? _crashSub;
  double _previousSpeed = 0.0;
  bool _crashOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize background service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await initializeBackgroundService();
        print('✓ [APP] Background service initialized');
      } catch (e) {
        print('⚠️ [APP] Background service init failed: $e');
      }
    });
    
    // Listen for crash events and take over the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crashService = ref.read(crashDetectionServiceProvider);
      _crashSub = crashService.crashStream.listen((isCrash) {
        if (isCrash && mounted && !_crashOverlayOpen) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
          _crashOverlayOpen = true;
          showCrashOverlay(context);
        } else if (!isCrash) {
          _crashOverlayOpen = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _crashSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      try {
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
      } catch (e) {
        print('⚠️ [APP] Data stream error: $e');
      }

      final currentIndex = ref.watch(navigationProvider);

      return Scaffold(
        body: IndexedStack(index: currentIndex, children: _screens),
        bottomNavigationBar: _buildBottomNav(currentIndex),
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

  Widget _buildBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
              _buildNavItem(Icons.home, 'Home', 0, currentIndex),
              _buildNavItem(Icons.analytics, 'Raw Data', 1, currentIndex),
              _buildNavItem(Icons.explore, 'Maps', 2, currentIndex),
              _buildNavItem(Icons.music_note, 'Music', 3, currentIndex),
              _buildNavItem(Icons.settings, 'Settings', 4, currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => ref.read(navigationProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
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
              color: isSelected ? Colors.white : AppColors.outline,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
