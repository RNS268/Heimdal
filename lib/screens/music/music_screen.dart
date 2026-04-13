import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import '../../providers/music_provider.dart' hide AppColors;
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicProvider);
    final musicNotifier = ref.read(musicProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              child: const Text(
                'Now Playing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Album Art
            Container(
              width: 280,
              height: 280,
              margin: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                image: musicState.albumArtBytes != null
                    ? DecorationImage(
                        image: MemoryImage(musicState.albumArtBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: musicState.albumArtBytes == null
                  ? Center(
                      child: Icon(
                        Icons.music_note,
                        size: 120,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),

            // Track Info
            Column(
              children: [
                Text(
                  musicState.songTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  musicState.artist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Progress Bar
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    value: musicState.currentPosition.inMilliseconds.toDouble().clamp(
                        0.0, musicState.totalDuration.inMilliseconds.toDouble()),
                    max: musicState.totalDuration.inMilliseconds.toDouble() > 0 
                         ? musicState.totalDuration.inMilliseconds.toDouble() 
                         : 1.0,
                    onChanged: (value) {
                      musicNotifier.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        musicNotifier.formatDuration(musicState.currentPosition),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        musicNotifier.formatDuration(musicState.totalDuration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous
                _ControlButton(
                  icon: Icons.skip_previous,
                  onPressed: () => musicNotifier.previous(),
                  size: 40,
                ),

                // Play/Pause
                _ControlButton(
                  icon: musicState.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: () => _handleMusicPlayPause(
                    context,
                    musicState,
                    musicNotifier,
                    ref.watch(settingsProvider).defaultMusicAppPackage,
                    ref,
                  ),
                  size: 60,
                  isMainControl: true,
                ),

                // Next
                _ControlButton(
                  icon: Icons.skip_next,
                  onPressed: () => musicNotifier.next(),
                  size: 40,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Volume Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Helmet Speaker Volume',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: musicState.volume,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        musicNotifier.setVolume(value);
                      },
                    ),
                  ),
                  Text(
                    '${(musicState.volume * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

Future<void> _handleMusicPlayPause(
  BuildContext context,
  MusicState musicState,
  MusicNotifier musicNotifier,
  String defaultMusicPackage,
  WidgetRef ref,
) async {
  final shouldOpenMusicApp = !_hasActiveTrack(musicState);

  if (shouldOpenMusicApp) {
    final opened = await _launchMusicApp(context, defaultMusicPackage);
    if (opened) {
      // Wait a moment for the app to start playing
      await Future.delayed(const Duration(milliseconds: 500));
      // Refresh the music provider to get updated state
      ref.invalidate(musicProvider);
      return;
    }
  }

  await musicNotifier.playPause();
}

bool _hasActiveTrack(MusicState musicState) {
  return musicState.totalDuration.inMilliseconds > 0 &&
      musicState.songTitle != 'No Media' &&
      musicState.songTitle != 'Permission Denied';
}

Future<bool> _launchMusicApp(BuildContext context, String defaultPackage) async {
  final fallbackApps = [
    'com.spotify.music',
    'com.google.android.apps.youtube.music',
    'com.amazon.mp3',
    'com.soundcloud.android',
    'com.google.android.music',
    'com.apple.android.music',
  ];

  try {
    if (defaultPackage.isNotEmpty) {
      await LaunchApp.openApp(androidPackageName: defaultPackage, openStore: false);
      return true;
    }

    if (Platform.isAndroid) {
      for (final package in fallbackApps) {
        final installed = await LaunchApp.isAppInstalled(androidPackageName: package);
        if (installed == true) {
          await LaunchApp.openApp(androidPackageName: package, openStore: false);
          return true;
        }
      }
    } else if (Platform.isIOS) {
      await LaunchApp.openApp(iosUrlScheme: 'music://', openStore: false);
      return true;
    }
  } catch (_) {
    // ignore
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No music app available to open.')),
  );
  return false;
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isMainControl;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    this.isMainControl = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isMainControl ? AppColors.primary : Colors.white10,
          shape: BoxShape.circle,
          boxShadow: isMainControl
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Icon(icon, size: size * 0.5, color: isMainControl ? AppColors.onPrimaryContainer : Colors.white),
      ),
    );
  }
}
