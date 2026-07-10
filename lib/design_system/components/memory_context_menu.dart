import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_typography.dart';

/// One entry in a [MemoryContextMenu].
class MemoryMenuItem<T> {
  const MemoryMenuItem({
    required this.value,
    required this.label,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final bool isDestructive;
}

/// Memory's long-press / overflow menu.
///
/// Wraps [PopupMenuButton] so radius, surface and type never diverge between
/// the two places a menu appears.
class MemoryContextMenu<T> extends StatelessWidget {
  const MemoryContextMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.dark,
    required this.child,
    this.tooltip,
    this.initialValue,
  });

  final List<MemoryMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool dark;
  final Widget child;
  final String? tooltip;
  final T? initialValue;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: initialValue,
      tooltip: tooltip ?? '',
      onSelected: onSelected,
      color: MemoryColors.surface(dark),
      shape: const RoundedRectangleBorder(borderRadius: MemoryRadius.allMd),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: Text(
              item.label,
              style: MemoryTypography.bodySmall.copyWith(
                color: item.isDestructive
                    ? MemoryColors.danger
                    : MemoryColors.foregroundOn(dark),
              ),
            ),
          ),
      ],
      child: child,
    );
  }
}
