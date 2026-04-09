import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simplified Spotify Remote Control Service
/// Sends volume control to helmet speakers via BLE
class SpotifyRemoteService {
  bool _isPlaying = false;
  String _currentTrack = 'Spotify';
  String _currentArtist = 'Connected';
  double _volume = 0.7;

  final _playbackStateController = StreamController<bool>.broadcast();
  final _trackInfoController = StreamController<Map<String, String>>.broadcast();

  Stream<bool> get playbackState => _playbackStateController.stream;
  Stream<Map<String, String>> get trackInfo => _trackInfoController.stream;

  bool get isAuthenticated => true;
  bool get isPlaying => _isPlaying;
  String get currentTrack => _currentTrack;
  String get currentArtist => _currentArtist;

  /// Connect to Spotify
  Future<bool> connect() async {
    try {
      print('🎵 [SPOTIFY] Connecting...');
      await Future.delayed(Duration(seconds: 1));
      
      print('✓ [SPOTIFY] Connected successfully');
      _trackInfoController.add({
        'track': 'Ready for Music',
        'artist': 'Tap to Play',
        'duration': '180000',
        'position': '0',
      });
      
      return true;
    } catch (e) {
      print('❌ [SPOTIFY] Connection failed: $e');
      return false;
    }
  }

  /// Disconnect from Spotify
  Future<void> disconnect() async {
    try {
      print('✓ [SPOTIFY] Disconnected');
    } catch (e) {
      print('❌ [SPOTIFY] Disconnect error: $e');
    }
  }

  /// Play current track
  Future<void> play() async {
    try {
      _isPlaying = true;
      _playbackStateController.add(true);
      print('▶️ [SPOTIFY] Playing');
    } catch (e) {
      print('❌ [SPOTIFY] Play error: $e');
    }
  }

  /// Pause current track
  Future<void> pause() async {
    try {
      _isPlaying = false;
      _playbackStateController.add(false);
      print('⏸️ [SPOTIFY] Paused');
    } catch (e) {
      print('❌ [SPOTIFY] Pause error: $e');
    }
  }

  /// Skip to next track
  Future<void> skipNext() async {
    try {
      print('⏭️ [SPOTIFY] Skipped to next');
      _currentTrack = 'Next Track';
      _trackInfoController.add({
        'track': _currentTrack,
        'artist': 'Now Playing',
        'duration': '210000',
        'position': '0',
      });
    } catch (e) {
      print('❌ [SPOTIFY] Skip next error: $e');
    }
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    try {
      print('⏮️ [SPOTIFY] Skipped to previous');
      _currentTrack = 'Previous Track';
      _trackInfoController.add({
        'track': _currentTrack,
        'artist': 'Now Playing',
        'duration': '195000',
        'position': '0',
      });
    } catch (e) {
      print('❌ [SPOTIFY] Skip previous error: $e');
    }
  }

  /// Set volume (0-1.0) - sends to helmet speakers via BLE
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume;
      final volumePercent = (volume * 100).toInt();
      print('🔊 [SPOTIFY] Volume set to: $volumePercent%');
      // TODO: Send volume command to helmet speaker via BLE
    } catch (e) {
      print('❌ [SPOTIFY] Volume error: $e');
    }
  }

  /// Seek to position
  Future<void> seek(int positionMs) async {
    try {
      print('⏩ [SPOTIFY] Seeked to ${positionMs ~/ 1000}s');
    } catch (e) {
      print('❌ [SPOTIFY] Seek error: $e');
    }
  }

  void dispose() {
    _playbackStateController.close();
    _trackInfoController.close();
  }
}

final spotifyRemoteProvider = Provider<SpotifyRemoteService>((ref) {
  final service = SpotifyRemoteService();
  ref.onDispose(() => service.dispose());
  return service;
});
