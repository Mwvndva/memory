import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_motion.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// Whether a message reports a failure or simply confirms something happened.
enum MemorySnackTone { neutral, error }

/// Memory's only transient message.
///
/// Floating, inset from the edges, and gone before it becomes furniture.
/// Screens never build a [SnackBar] themselves — they call [show].
abstract final class MemorySnackBar {
  static SnackBar _build(
    String message,
    MemorySnackTone tone,
    Duration? d,
    String? actionLabel,
    VoidCallback? onAction,
  ) {
    return SnackBar(
      action: (actionLabel == null || onAction == null)
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: MemoryColors.accent,
              onPressed: onAction,
            ),
      content: Text(
        message,
        style: MemoryTypography.bodySmall.copyWith(color: MemoryColors.cream),
      ),
      backgroundColor: tone == MemorySnackTone.error
          ? MemoryColors.ink
          : MemoryColors.charcoal,
      behavior: SnackBarBehavior.floating,
      duration:
          d ??
          (tone == MemorySnackTone.error
              ? const Duration(seconds: 4)
              : const Duration(seconds: 3)),
      margin: const EdgeInsets.symmetric(
        horizontal: MemorySpacing.sheet,
        vertical: MemorySpacing.md,
      ),
      shape: const RoundedRectangleBorder(borderRadius: MemoryRadius.allMd),
      animation: null, // let the framework drive it; timing is below
    );
  }

  /// Present [message]. Replaces any snack already on screen so messages never
  /// queue up behind one another.
  static void show(
    BuildContext context,
    String message, {
    MemorySnackTone tone = MemorySnackTone.neutral,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      _build(message, tone, duration, actionLabel, onAction),
    );
  }

  /// How long a snack takes to slide in. Exposed so motion stays in one place.
  static const Duration transition = MemoryDurations.normal;
}
