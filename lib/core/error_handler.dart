import 'package:flutter/material.dart';

/// Centralized error handling helpers to keep UX consistent.
/// Use `showAppError(context, message)` to display user-facing errors.

void showAppError(BuildContext context, String message, {Duration? duration}) {
  final snack = SnackBar(
    content: Text(message),
    backgroundColor: Colors.black,
    behavior: SnackBarBehavior.floating,
    duration: duration ?? const Duration(seconds: 4),
    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
  ScaffoldMessenger.of(context).showSnackBar(snack);
}

void showAppMessage(BuildContext context, String message, {Duration? duration}) {
  final snack = SnackBar(
    content: Text(message),
    backgroundColor: Colors.grey[900],
    behavior: SnackBarBehavior.floating,
    duration: duration ?? const Duration(seconds: 3),
    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
  ScaffoldMessenger.of(context).showSnackBar(snack);
}
