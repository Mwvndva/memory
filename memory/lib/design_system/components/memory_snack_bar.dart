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
    final isError = tone == MemorySnackTone.error;
    return SnackBar(
      // The visual is fully custom below, so strip the default SnackBar chrome.
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration:
          d ??
          (isError ? const Duration(seconds: 4) : const Duration(seconds: 3)),
      margin: const EdgeInsets.symmetric(
        horizontal: MemorySpacing.sheet,
        vertical: MemorySpacing.md,
      ),
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MemorySpacing.xl,
          vertical: MemorySpacing.lg,
        ),
        decoration: BoxDecoration(
          color: MemoryColors.ink,
          borderRadius: MemoryRadius.allLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? MemoryColors.danger : MemoryColors.accent,
              size: 20,
            ),
            const SizedBox(width: MemorySpacing.md),
            Expanded(
              child: Text(
                message,
                style: MemoryTypography.bodySmall.copyWith(
                  color: MemoryColors.cream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: MemorySpacing.lg),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel,
                  style: MemoryTypography.bodySmall.copyWith(
                    color: MemoryColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
    // Dismiss the snack when its action is taken, then run the callback.
    VoidCallback? wrappedAction;
    if (onAction != null) {
      wrappedAction = () {
        messenger.hideCurrentSnackBar();
        onAction();
      };
    }
    messenger.showSnackBar(
      _build(message, tone, duration, actionLabel, wrappedAction),
    );
  }

  /// How long a snack takes to slide in. Exposed so motion stays in one place.
  static const Duration transition = MemoryDurations.normal;
}
