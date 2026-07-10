import 'package:flutter/material.dart';

import 'memory_colors.dart';

/// Memory's elevation.
///
/// Depth comes from a single soft shadow, never from borders. The shadow is
/// weaker on light surfaces because cream already separates a card from the
/// page behind it.
abstract final class MemoryShadows {
  /// Resting cards and tiles.
  static List<BoxShadow> card(bool dark) => [
    BoxShadow(
      color: MemoryColors.ink.withValues(alpha: dark ? 0.12 : 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Raised surfaces: the profile header, feature cards.
  static List<BoxShadow> raised(bool dark) => [
    BoxShadow(
      color: MemoryColors.ink.withValues(alpha: dark ? 0.16 : 0.04),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  /// Sheets and panels that float over content.
  static List<BoxShadow> overlay(bool dark) => [
    BoxShadow(
      color: MemoryColors.ink.withValues(alpha: dark ? 0.22 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// No shadow. Named so a screen states the intent explicitly.
  static const List<BoxShadow> none = <BoxShadow>[];
}
