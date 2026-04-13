import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/music_remote_service.dart';

// Colors from the design
class AppColors {
  static const surface = Color(0xFF0d1321);
  static const primary = Color(0xFFadc6ff);
  static const onSurface = Color(0xFFdde2f6);
  static const onSurfaceVariant = Color(0xFFc2c6d6);
  static const surfaceVariant = Color(0xFF2f3544);
  static const surfaceContainerHigh = Color(0xFF242a39);
  static const surfaceContainerHighest = Color(0xFF2f3544);
  static const primaryContainer = Color(0xFF4d8eff);
  static const onPrimaryContainer = Color(0xFF00285d);
  static const outline = Color(0xFF8c909f);
}

// Music state
class MusicState {
  final String songTitle;
  final String artist;
  final Uint8List? albumArtBytes;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final double volume;

 MusicState({
    this.songTitle = 'NEON HORIZON',
    this.artist = 'CYBERDRIFT',
    this.albumArtBytes,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = const Duration(minutes: 3, seconds: 45),
    this.volume = 0.7,
  });

  MusicState copyWith({
    String? songTitle,
    String? artist,
    Uint8List? albumArtBytes,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    double? volume,
  }) {
    return MusicState(
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      albumArtBytes: albumArtBytes ?? this.albumArtBytes,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      volume: volume ?? this.volume,
    );
  }
}

class MusicNotifier extends StateNotifier<MusicState> {
  final MusicRemoteService _service;
  StreamSubscription<Map<String, dynamic>>? _metadataSubscription;
  Timer? _positionUpdateTimer;

  MusicNotifier(this._service) : super(MusicState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    _loadCurrentTrack();
    _listenToMetadataChanges();
    _startPositionUpdates();
  }

  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (state.isPlaying && state.totalDuration.inMilliseconds > 0) {
        final newPosition = state.currentPosition + const Duration(milliseconds: 500);
        // Don't exceed total duration
        final cappedPosition = newPosition.inMilliseconds > state.totalDuration.inMilliseconds
            ? state.totalDuration
            : newPosition;
        state = state.copyWith(currentPosition: cappedPosition);
      }
    });
  }

  void _listenToMetadataChanges() {
    _metadataSubscription = _service.metadataStream.listen((metadata) {
      Uint8List? albumArtBytes;
      final albumArt = metadata['albumArt'];
      if (albumArt is Uint8List) {
        albumArtBytes = albumArt;
      } else if (albumArt is String && albumArt.isNotEmpty) {
        try {
          albumArtBytes = base64.decode(albumArt);
        } catch (_) {
          albumArtBytes = null;
        }
      }

      state = state.copyWith(
        songTitle: metadata['title'] ?? state.songTitle,
        artist: metadata['artist'] ?? state.artist,
        albumArtBytes: albumArtBytes ?? state.albumArtBytes,
        isPlaying: metadata['isPlaying'] ?? state.isPlaying,
        currentPosition: Duration(milliseconds: metadata['position'] ?? state.currentPosition.inMilliseconds),
        totalDuration: Duration(milliseconds: metadata['duration'] ?? state.totalDuration.inMilliseconds),
      );
    });
  }

  Future<void> _loadCurrentTrack() async {
    final track = await _service.getCurrentTrack();
    if (track != null) {
      Uint8List? albumArtBytes;
      final albumArt = track['albumArt'];
      if (albumArt is Uint8List) {
        albumArtBytes = albumArt;
      } else if (albumArt is String && albumArt.isNotEmpty) {
        try {
          albumArtBytes = base64.decode(albumArt);
        } catch (_) {
          albumArtBytes = null;
        }
      }

      state = state.copyWith(
        songTitle: track['title'] ?? 'Unknown',
        artist: track['artist'] ?? 'Unknown',
        albumArtBytes: albumArtBytes ?? state.albumArtBytes,
        isPlaying: track['isPlaying'] ?? false,
        currentPosition: Duration(milliseconds: track['position'] ?? 0),
        totalDuration: Duration(milliseconds: track['duration'] ?? 0),
      );
    }
  }

  Future<void> playPause() async {
    final newState = !state.isPlaying;
    await _service.playPause();
    state = state.copyWith(isPlaying: newState);
  }

  Future<void> next() async {
    await _service.next();
    await Future.delayed(const Duration(milliseconds: 500));
    _loadCurrentTrack();
  }

  Future<void> previous() async {
    await _service.previous();
    await Future.delayed(const Duration(milliseconds: 500));
    _loadCurrentTrack();
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position.inMilliseconds);
    state = state.copyWith(currentPosition: position);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
    _service.setVolume(volume);
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _metadataSubscription?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
}

final musicProvider = StateNotifierProvider<MusicNotifier, MusicState>((ref) {
  final service = ref.watch(musicRemoteServiceProvider);
  return MusicNotifier(service);
});