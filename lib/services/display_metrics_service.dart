import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

/// Stores device display metrics and margins
class DisplayMetrics {
  final double statusBarHeight;
  final double navigationBarHeight;
  final double leftSafeArea;
  final double rightSafeArea;
  final double topSafeArea;
  final double bottomSafeArea;
  final double screenWidth;
  final double screenHeight;
  final double devicePixelRatio;

  DisplayMetrics({
    required this.statusBarHeight,
    required this.navigationBarHeight,
    required this.leftSafeArea,
    required this.rightSafeArea,
    required this.topSafeArea,
    required this.bottomSafeArea,
    required this.screenWidth,
    required this.screenHeight,
    required this.devicePixelRatio,
  });

  factory DisplayMetrics.fromMediaQuery(MediaQueryData mediaQuery) {
    return DisplayMetrics(
      statusBarHeight: mediaQuery.padding.top,
      navigationBarHeight: mediaQuery.padding.bottom,
      leftSafeArea: mediaQuery.viewPadding.left,
      rightSafeArea: mediaQuery.viewPadding.right,
      topSafeArea: mediaQuery.viewPadding.top,
      bottomSafeArea: mediaQuery.viewPadding.bottom,
      screenWidth: mediaQuery.size.width,
      screenHeight: mediaQuery.size.height,
      devicePixelRatio: mediaQuery.devicePixelRatio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusBarHeight': statusBarHeight,
      'navigationBarHeight': navigationBarHeight,
      'leftSafeArea': leftSafeArea,
      'rightSafeArea': rightSafeArea,
      'topSafeArea': topSafeArea,
      'bottomSafeArea': bottomSafeArea,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'devicePixelRatio': devicePixelRatio,
    };
  }

  factory DisplayMetrics.fromJson(Map<String, dynamic> json) {
    return DisplayMetrics(
      statusBarHeight: (json['statusBarHeight'] as num?)?.toDouble() ?? 0,
      navigationBarHeight: (json['navigationBarHeight'] as num?)?.toDouble() ?? 0,
      leftSafeArea: (json['leftSafeArea'] as num?)?.toDouble() ?? 0,
      rightSafeArea: (json['rightSafeArea'] as num?)?.toDouble() ?? 0,
      topSafeArea: (json['topSafeArea'] as num?)?.toDouble() ?? 0,
      bottomSafeArea: (json['bottomSafeArea'] as num?)?.toDouble() ?? 0,
      screenWidth: (json['screenWidth'] as num?)?.toDouble() ?? 0,
      screenHeight: (json['screenHeight'] as num?)?.toDouble() ?? 0,
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Calculate responsive padding based on safe area
  EdgeInsets getResponsivePadding({
    double defaultHorizontal = 8,
    double defaultVertical = 8,
  }) {
    return EdgeInsets.fromLTRB(
      leftSafeArea + defaultHorizontal,
      topSafeArea + defaultVertical,
      rightSafeArea + defaultHorizontal,
      bottomSafeArea + defaultVertical,
    );
  }

  /// Get safe content area width
  double getSafeWidth() => screenWidth - leftSafeArea - rightSafeArea;

  /// Get safe content area height
  double getSafeHeight() => screenHeight - topSafeArea - bottomSafeArea;

  /// Get content area height excluding status and navigation bars
  double getAppAreaHeight() => screenHeight - statusBarHeight - navigationBarHeight;
}

class DisplayMetricsService {
  static const String _prefsKey = 'heimdall.display_metrics';
  static const String _isFirstLaunchKey = 'heimdall.is_first_launch';

  static Future<DisplayMetrics> initializeMetrics(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_isFirstLaunchKey) ?? true;

    // Only capture from MediaQuery on first launch
    if (isFirstLaunch) {
      final mediaQuery = MediaQuery.of(context);
      final metrics = DisplayMetrics.fromMediaQuery(mediaQuery);
      
      // Save in background, don't wait
      _saveMetrics(prefs, metrics).ignore();
      prefs.setBool(_isFirstLaunchKey, false).ignore();
      
      return metrics;
    }

    // Return immediately from cache on subsequent launches
    return getStoredMetrics();
  }

  static Future<DisplayMetrics> getStoredMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);

    if (stored != null && stored.isNotEmpty) {
      try {
        final json = Map<String, dynamic>.from(
          (jsonDecode(stored) as Map).cast<String, dynamic>(),
        );
        return DisplayMetrics.fromJson(json);
      } catch (_) {
        // Fallback to defaults
        return DisplayMetrics(
          statusBarHeight: 0,
          navigationBarHeight: 0,
          leftSafeArea: 0,
          rightSafeArea: 0,
          topSafeArea: 0,
          bottomSafeArea: 0,
          screenWidth: 392,
          screenHeight: 844,
          devicePixelRatio: 1.0,
        );
      }
    }

    return DisplayMetrics(
      statusBarHeight: 0,
      navigationBarHeight: 0,
      leftSafeArea: 0,
      rightSafeArea: 0,
      topSafeArea: 0,
      bottomSafeArea: 0,
      screenWidth: 392,
      screenHeight: 844,
      devicePixelRatio: 1.0,
    );
  }

  static Future<void> _saveMetrics(SharedPreferences prefs, DisplayMetrics metrics) async {
    final json = metrics.toJson();
    await prefs.setString(_prefsKey, jsonEncode(json));
  }

  static bool isFirstLaunch(SharedPreferences prefs) {
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }
}
