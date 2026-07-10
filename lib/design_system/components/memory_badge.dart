import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// The unread badge.
///
/// Prefer the bare dot. In a list, Memory tells you *that* something is
/// waiting, not how far behind you are — a per-row count is noise.
///
/// Pass [count] only where the badge stands for a whole inbox the user cannot
/// see from here, such as the camera's messages button: there the number is
/// the only signal of how much is waiting. Counts above nine collapse to "9+",
/// because past that the exact figure stops informing and starts nagging.
class MemoryBadge extends StatelessWidget {
  const MemoryBadge({super.key, required this.dark, this.size = 14, this.count})
    : assert(count == null || count > 0, 'A zero badge should not be built.');

  final bool dark;

  /// Diameter of the dot. Ignored when [count] is set: the capsule sizes to
  /// its digits so "9+" never clips.
  final double size;

  /// Unread items. Null renders the bare dot.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: MemoryColors.surface(dark), width: 2);

    if (count == null) {
      return Semantics(
        label: 'Unread',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: MemoryColors.accent,
            shape: BoxShape.circle,
            border: border,
          ),
        ),
      );
    }

    final label = count! > 9 ? '9+' : '$count';
    return Semantics(
      label: '$count unread',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MemorySpacing.xs,
          vertical: MemorySpacing.xxs,
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MemoryColors.accent,
          borderRadius: MemoryRadius.allPill,
          border: border,
        ),
        child: Text(
          label,
          style: MemoryTypography.micro.copyWith(color: MemoryColors.ink),
        ),
      ),
    );
  }
}

/// A small capsule of text: a role, a rank, a status.
class MemoryChip extends StatelessWidget {
  const MemoryChip({
    super.key,
    required this.label,
    required this.dark,
    this.leading,
    this.trailing,
    this.onTap,
    this.background,
    this.foreground,
  });

  final String label;
  final bool dark;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? MemoryColors.foregroundOn(dark);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            background ??
            MemoryColors.hairline(dark, alpha: MemoryColors.alphaHairline),
        borderRadius: MemoryRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
