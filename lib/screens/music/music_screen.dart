import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/spotify_remote_service.dart';
import '../../theme/app_colors.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  bool _connected = false;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSpotify();
    });
  }

  Future<void> _initSpotify() async {
    final spotify = ref.read(spotifyRemoteProvider);
    final connected = await spotify.connect();
    setState(() => _connected = connected);
  }

  @override
  Widget build(BuildContext context) {
    final spotify = ref.watch(spotifyRemoteProvider);
    final trackInfo = spotify.trackInfo;
    final playbackState = spotify.playbackState;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _connected
          ? SingleChildScrollView(
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

                  // Album Art Placeholder
                  Container(
                    width: 280,
                    height: 280,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 120,
                      color: Colors.white,
                    ),
                  ),

                  // Track Info
                  StreamBuilder<Map<String, String>>(
                    stream: trackInfo,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final info = snapshot.data!;
                        return Column(
                          children: [
                            Text(
                              info['track'] ?? 'No Track',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              info['artist'] ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }
                      return const Text(
                        'Connect to Spotify',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Progress Bar
                  StreamBuilder<Map<String, String>>(
                    stream: trackInfo,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final info = snapshot.data!;
                        final position = int.tryParse(info['position'] ?? '0') ?? 0;
                        final duration = int.tryParse(info['duration'] ?? '0') ?? 1;
                        
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                inactiveTrackColor: Colors.white.withOpacity(0.2),
                                activeTrackColor: AppColors.success,
                                thumbColor: AppColors.success,
                              ),
                              child: Slider(
                                value: position.toDouble(),
                                max: duration.toDouble(),
                                onChanged: (value) {
                                  spotify.seek(value.toInt());
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 40),

                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Previous
                      _ControlButton(
                        icon: Icons.skip_previous,
                        onPressed: () => spotify.skipPrevious(),
                        size: 40,
                      ),

                      // Play/Pause
                      StreamBuilder<bool>(
                        stream: playbackState,
                        initialData: false,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return _ControlButton(
                            icon: isPlaying ? Icons.pause : Icons.play_arrow,
                            onPressed: isPlaying
                                ? () => spotify.pause()
                                : () => spotify.play(),
                            size: 60,
                            isMainControl: true,
                          );
                        },
                      ),

                      // Next
                      _ControlButton(
                        icon: Icons.skip_next,
                        onPressed: () => spotify.skipNext(),
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
                            color: Colors.white.withOpacity(0.7),
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
                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                            activeTrackColor: AppColors.success,
                            thumbColor: AppColors.success,
                          ),
                          child: Slider(
                            value: _volume,
                            min: 0,
                            max: 1,
                            onChanged: (value) {
                              setState(() => _volume = value);
                              spotify.setVolume(value);
                            },
                          ),
                        ),
                        Text(
                          '${(_volume * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Spotify Not Connected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Make sure Spotify is running on your device',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _initSpotify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
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
          color: isMainControl ? AppColors.success : Colors.white10,
          shape: BoxShape.circle,
          boxShadow: isMainControl
              ? [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

