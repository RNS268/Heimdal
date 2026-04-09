import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Application logger using dart:developer
class Logger {
  static const String _tag = 'HEIMDALL';

  static void debug(String message, {String? tag}) {
    _log('DEBUG', message, tag: tag);
  }

  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  static void warning(String message, {String? tag}) {
    _log('WARNING', message, tag: tag);
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logTag = tag ?? _tag;
    final fullMessage = '[$level][$logTag] $message';

    if (kDebugMode) {
      developer.log(
        fullMessage,
        name: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
