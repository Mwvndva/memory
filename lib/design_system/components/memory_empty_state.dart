import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// What Memory shows when there is nothing to show.
///
/// Calm, never apologetic: an icon, one sentence of fact, one of direction.
class MemoryEmptyState extends StatelessWidget {
  const MemoryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.dark,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MemorySpacing.section),
      decoration: BoxDecoration(
        color: MemoryColors.surface(dark),
        borderRadius: BorderRadius.circular(MemoryRadius.xl),
        border: Border.all(
          color: MemoryColors.hairline(dark, alpha: MemoryColors.alphaHairline),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: dark ? MemoryColors.accent : MemoryColors.ink,
            size: 28,
          ),
          const SizedBox(height: MemorySpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: MemoryTypography.onSurface(
              MemoryTypography.emptyTitle,
              dark,
            ),
          ),
          const SizedBox(height: MemorySpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MemoryTypography.bodySmall.copyWith(
              color: MemoryColors.muted(dark),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
