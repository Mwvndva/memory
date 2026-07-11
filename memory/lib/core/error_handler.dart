import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:memory_app/design_system/design_system.dart';

/// Centralized error handling helpers to keep UX consistent.
/// Use `showAppError(context, message)` to display user-facing errors.

/// Show a user-facing error. Delegates to [MemorySnackBar] so every transient
/// message in the app has one implementation.
void showAppError(BuildContext context, String message, {Duration? duration}) {
  MemorySnackBar.show(
    context,
    message,
    tone: MemorySnackTone.error,
    duration: duration,
  );
}

/// Show a neutral confirmation.
void showAppMessage(
  BuildContext context,
  String message, {
  Duration? duration,
}) {
  MemorySnackBar.show(context, message, duration: duration);
}

/// Centralized Exception Taxonomy
sealed class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => message;
}

class AuthenticationException extends AppException {
  AuthenticationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

class NetworkException extends AppException {
  NetworkException(super.message, [super.originalError, super.stackTrace]);
}

class TimeoutException extends AppException {
  TimeoutException(super.message, [super.originalError, super.stackTrace]);
}

class ValidationException extends AppException {
  ValidationException(super.message, [super.originalError, super.stackTrace]);
}

class ServerException extends AppException {
  ServerException(super.message, [super.originalError, super.stackTrace]);
}

class CacheException extends AppException {
  CacheException(super.message, [super.originalError, super.stackTrace]);
}

class RealtimeException extends AppException {
  RealtimeException(super.message, [super.originalError, super.stackTrace]);
}

class MediaException extends AppException {
  MediaException(super.message, [super.originalError, super.stackTrace]);
}

class UploadException extends AppException {
  UploadException(super.message, [super.originalError, super.stackTrace]);
}

class UnknownException extends AppException {
  UnknownException(super.message, [super.originalError, super.stackTrace]);
}

/// Centralized helper to map any caught error to a typed AppException,
/// preserving logs and stack traces.
AppException mapException(dynamic error, [StackTrace? stackTrace]) {
  // Preserve stack trace or default to current
  final trace = stackTrace ?? StackTrace.current;

  // Log unexpected errors for developers/debugging
  if (error is! ValidationException && error is! NetworkException) {
    debugPrint('[ERROR DECORATOR] Unexpected failure: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  if (error is AppException) {
    return error;
  }

  if (error is DioException) {
    final message =
        error.response?.data is Map && error.response?.data['message'] != null
        ? error.response!.data['message'].toString()
        : (error.message ?? 'An unexpected error occurred.');

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return TimeoutException(
        'Connection timed out. Please try again.',
        error,
        trace,
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return NetworkException(
        'No internet connection. Please check your network settings.',
        error,
        trace,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      if (statusCode == 401 || statusCode == 403) {
        return AuthenticationException(message, error, trace);
      }
      if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
        return ValidationException(message, error, trace);
      }
      if (statusCode >= 500) {
        return ServerException(
          'Server error ($statusCode). Please try again later.',
          error,
          trace,
        );
      }
    }
    return UnknownException(message, error, trace);
  }

  if (error is SocketException) {
    return NetworkException(
      'No internet connection. Please check your network settings.',
      error,
      trace,
    );
  }

  return UnknownException(error.toString(), error, trace);
}
