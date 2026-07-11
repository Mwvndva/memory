import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_interactions.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// One choice in a bottom sheet: an icon, a label, and a consequence.
///
/// Replaces the bare [ListTile]s that used to appear inside modal sheets.
/// They came with Material's own 56dp minimum, its own ripple, and no
/// destructive treatment, so "Delete message" looked exactly like
/// "Retry sending" apart from the colour someone had hand-typed.
class MemorySheetAction extends StatelessWidget {
  const MemorySheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  /// Irreversible. Tints the glyph and the label.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final tint = isDestructive
        ? MemoryColors.danger
        : MemoryColors.foregroundOn(dark);

    return Semantics(
      button: true,
      label: label,
      // ExcludeSemantics wraps only the glyph and the label. Wrapping the
      // BouncyTap would strip its tap action, leaving a row that announces
      // itself as a button and cannot be activated.
      child: BouncyTap(
        onTap: onTap,
        pressedScale: 0.98,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MemorySpacing.gutter,
            vertical: MemorySpacing.xxl,
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(icon, color: tint, size: 20),
                const SizedBox(width: MemorySpacing.gutter),
                Text(
                  label,
                  style: MemoryTypography.bodyMedium.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only row in a list: a title, a supporting line, and an optional
/// trailing mark. It reports nothing and does nothing when tapped.
class MemoryDetailRow extends StatelessWidget {
  const MemoryDetailRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dark,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool dark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MemorySpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MemoryTypography.onSurface(
                    MemoryTypography.bodyMedium,
                    dark,
                  ),
                ),
                const SizedBox(height: MemorySpacing.xxs),
                Text(
                  subtitle,
                  style: MemoryTypography.mutedOnSurface(
                    MemoryTypography.caption,
                    dark,
                    alpha: 0.6,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MemorySpacing.xl),
            trailing!,
          ],
        ],
      ),
    );
  }
}
