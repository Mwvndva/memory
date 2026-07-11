import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// Memory's select control.
///
/// Wraps Material's dropdown so its menu surface, radius, and chevron are
/// decided once rather than re-typed at every call site. The caller supplies
/// how an option looks when open and, optionally, a tighter form for when it
/// is closed — a country row shows its dial code in the menu but not in the
/// 96dp box it collapses into.
class MemoryDropdown<T> extends StatelessWidget {
  const MemoryDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.itemBuilder,
    required this.onChanged,
    required this.dark,
    this.selectedBuilder,
    this.background,
    this.menuMaxHeight = 350,
  });

  final T value;
  final List<T> options;

  /// How one option renders inside the open menu.
  final Widget Function(T option) itemBuilder;

  /// How the chosen option renders in the closed box. Falls back to
  /// [itemBuilder].
  final Widget Function(T option)? selectedBuilder;

  final ValueChanged<T> onChanged;
  final bool dark;

  /// Overrides the closed box's fill.
  final Color? background;

  final double menuMaxHeight;

  @override
  Widget build(BuildContext context) {
    final fg = MemoryColors.foregroundOn(dark);

    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: dark ? MemoryColors.ink : MemoryColors.accent,
      borderRadius: MemoryRadius.allLg,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: fg.withValues(alpha: 0.6),
      ),
      iconSize: 20,
      isDense: true,
      isExpanded: true,
      menuMaxHeight: menuMaxHeight,
      items: [
        for (final option in options)
          DropdownMenuItem<T>(value: option, child: itemBuilder(option)),
      ],
      selectedItemBuilder: selectedBuilder == null
          ? null
          : (context) => [for (final o in options) selectedBuilder!(o)],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      style: MemoryTypography.bodyMedium.copyWith(color: fg),
      decoration: InputDecoration(
        filled: true,
        fillColor: background ?? (dark ? MemoryColors.ink : MemoryColors.cream),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MemorySpacing.lg,
          vertical: MemorySpacing.gutter,
        ),
        border: const OutlineInputBorder(
          borderRadius: MemoryRadius.allLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: MemoryRadius.allLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: MemoryRadius.allLg,
          borderSide: BorderSide(color: MemoryColors.accent, width: 1.4),
        ),
      ),
    );
  }
}
