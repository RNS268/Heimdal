import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Don't initialize background service immediately - let UI start first
  // The app will initialize it after first build
  
  runApp(
    const ProviderScope(
      child: HeimdallApp(),
    ),
  );
}
