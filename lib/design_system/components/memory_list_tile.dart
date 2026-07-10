import 'package:flutter/material.dart';

import 'package:memory_app/core/playful.dart';
import '../foundation/memory_colors.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';
import 'memory_divider.dart';

/// A read-only `label — value` row inside a [MemoryCard].
class MemoryListTile extends StatelessWidget {
  const MemoryListTile({
    super.key,
    required this.label,
    required this.value,
    required this.dark,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool dark;

  /// The last row in a card carries no rule.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MemorySpacing.lg),
      decoration: isLast
          ? null
          : BoxDecoration(border: MemoryDivider.bottom(dark)),
      child: Row(
        children: [
          Text(
            label,
            style: MemoryTypography.mutedOnSurface(
              MemoryTypography.caption.copyWith(fontWeight: FontWeight.w600),
              dark,
              alpha: 0.68,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: MemoryTypography.onSurface(
              MemoryTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              dark,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row with a trailing chevron. Settings, legal, data management.
class MemoryActionTile extends StatelessWidget {
  const MemoryActionTile({
    super.key,
    required this.title,
    required this.onTap,
    required this.dark,
    this.isLast = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool dark;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MemorySpacing.lg),
        decoration: isLast
            ? null
            : BoxDecoration(border: MemoryDivider.bottom(dark)),
        child: Row(
          children: [
            Text(
              title,
              style: MemoryTypography.onSurface(
                MemoryTypography.bodySmall,
                dark,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: MemoryColors.foregroundOn(dark).withValues(alpha: 0.68),
              size: 11,
            ),
          ],
        ),
      ),
    );
  }
}
