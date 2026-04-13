import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MusicRemoteService {
  static const MethodChannel _methodChannel = MethodChannel('com.heimdall.music');
  static const EventChannel _eventChannel = EventChannel('com.heimdall.music/events');

  Stream<Map<String, dynamic>>? _metadataStream;

  Future<void> initialize() async {
    try {
      await _methodChannel.invokeMethod('initialize');
    } on PlatformException catch (e) {
      print('Failed to initialize music service: ${e.message}');
    }
  }

  Stream<Map<String, dynamic>> get metadataStream {
    _metadataStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event);
    });
    return _metadataStream!;
  }

  Future<void> playPause() async {
    try {
      await _methodChannel.invokeMethod('playPause');
    } on PlatformException catch (e) {
      print('Failed to play/pause: ${e.message}');
    }
  }

  Future<void> next() async {
    try {
      await _methodChannel.invokeMethod('next');
    } on PlatformException catch (e) {
      print('Failed to skip next: ${e.message}');
    }
  }

  Future<void> previous() async {
    try {
      await _methodChannel.invokeMethod('previous');
    } on PlatformException catch (e) {
      print('Failed to skip previous: ${e.message}');
    }
  }

  Future<void> seek(int positionMs) async {
    try {
      await _methodChannel.invokeMethod('seekTo', {'position': positionMs});
    } on PlatformException catch (e) {
      print('Failed to seek track: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> getCurrentTrack() async {
    try {
      final result = await _methodChannel.invokeMethod('getCurrentTrack');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Failed to get current track: ${e.message}');
      return null;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print('Failed to set volume: ${e.message}');
    }
  }
}

final musicRemoteServiceProvider = Provider<MusicRemoteService>((ref) {
  return MusicRemoteService();
});