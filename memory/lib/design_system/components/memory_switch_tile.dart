import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// A settings row that toggles one thing.
///
/// Wraps Material's [Switch] so the accent, the row's height, and the label's
/// weight are decided once. Feature code never reaches for [SwitchListTile]:
/// its default padding and 56dp minimum make a list of toggles taller than a
/// settings sheet has room for.
class MemorySwitchTile extends StatelessWidget {
  const MemorySwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.dark,
    this.subtitle,
  });

  final String label;

  /// Secondary line, for a toggle whose consequence is not obvious.
  final String? subtitle;

  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics, not Semantics + ExcludeSemantics: the Switch must keep
    // its own toggle action, or a screen-reader user can read the setting and
    // never change it. Merging folds the label into the switch's node, so it
    // is announced as "Push Notifications, switch, on".
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MemorySpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MemoryTypography.onSurface(
                      MemoryTypography.bodyMedium,
                      dark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: MemorySpacing.xxs),
                    Text(
                      subtitle!,
                      style: MemoryTypography.mutedOnSurface(
                        MemoryTypography.caption,
                        dark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: MemorySpacing.xl),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: MemoryColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
