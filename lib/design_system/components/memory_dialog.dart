import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// A dialog action. [isDestructive] tints the label; it does not confirm.
class MemoryDialogAction {
  const MemoryDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isPrimary;
}

/// Memory's only dialog.
///
/// Screens never construct [AlertDialog]. Title, body and actions come in;
/// radius, colour and type come from tokens.
class MemoryDialog extends StatelessWidget {
  const MemoryDialog({
    super.key,
    required this.title,
    required this.dark,
    required this.actions,
    this.message,
    this.content,
    this.isDestructive = false,
  });

  final String title;
  final bool dark;

  /// Plain body copy. Mutually exclusive with [content].
  final String? message;

  /// Arbitrary body, for scrolling policy text.
  final Widget? content;

  final List<MemoryDialogAction> actions;

  /// Tints the title. For irreversible actions.
  final bool isDestructive;

  /// Present a Memory dialog on the current navigator.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showDialog<T>(context: context, builder: builder);

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive
        ? MemoryColors.danger
        : MemoryColors.foregroundOn(dark);

    return AlertDialog(
      backgroundColor: MemoryColors.surface(dark),
      shape: const RoundedRectangleBorder(borderRadius: MemoryRadius.allLg),
      title: Text(
        title,
        style: MemoryTypography.subtitle.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w900,
        ),
      ),
      content:
          content ??
          (message == null
              ? null
              : Text(
                  message!,
                  style: MemoryTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? MemoryColors.danger
                        : MemoryColors.foregroundOn(
                            dark,
                          ).withValues(alpha: MemoryColors.alphaSecondary),
                  ),
                )),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: MemorySpacing.md,
        vertical: MemorySpacing.md,
      ),
      actions: [
        for (final action in actions)
          TextButton(
            onPressed: action.onPressed,
            child: Text(
              action.label,
              style: MemoryTypography.body.copyWith(
                color: action.isDestructive
                    ? MemoryColors.danger
                    : action.isPrimary
                    ? MemoryColors.accent
                    : MemoryColors.foregroundOn(dark).withValues(alpha: 0.6),
                fontWeight: action.isDestructive || action.isPrimary
                    ? FontWeight.bold
                    : FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
