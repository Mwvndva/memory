import 'package:flutter/foundation.dart';

class StructuredLogger {
  static void log(
    String message, {
    String? category,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final categoryString = category != null ? '[$category]' : '[General]';
    final errorString = error != null ? ' | Error: $error' : '';

    debugPrint('$timestamp $categoryString $message$errorString');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void logWarning(String message, {String? category, dynamic error}) {
    log('WARN: $message', category: category, error: error);
  }

  static void logError(
    String message, {
    String? category,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    log(
      'ERROR: $message',
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
