import 'package:flutter/material.dart';

import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// The small tracked-out label that titles a group of rows.
///
/// Always renders upper-case. Callers pass natural text; the component owns
/// the casing so the rule cannot drift.
class MemorySectionHeader extends StatelessWidget {
  const MemorySectionHeader({
    super.key,
    required this.title,
    required this.dark,
  });

  final String title;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: MemorySpacing.sm,
        bottom: MemorySpacing.md,
        top: MemorySpacing.xxl,
      ),
      child: Text(
        title.toUpperCase(),
        style: MemoryTypography.mutedOnSurface(
          MemoryTypography.sectionLabel,
          dark,
          alpha: 0.76,
        ),
      ),
    );
  }
}
