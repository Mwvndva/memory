import 'package:flutter/material.dart';

import 'memory_colors.dart';

/// Memory's type scale.
///
/// The app is set in Plus Jakarta Sans (applied once in `main.dart` via
/// `GoogleFonts.plusJakartaSansTextTheme`), so these styles deliberately carry
/// no `fontFamily` — they inherit it. Sizes and weights match the values that
/// were previously written inline, so migrating a screen does not reflow it.
///
/// Memory leans on weight rather than size for hierarchy: a heavy small label
/// reads as a section header, not a shouty one.
abstract final class MemoryTypography {
  /// 30/w900 — screen titles ("Your circle").
  static const TextStyle display = TextStyle(
    fontSize: 30,
    height: 1.05,
    fontWeight: FontWeight.w900,
  );

  /// 22/w900 — the person's name on their profile.
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
  );

  /// 19/w900 — a card's headline number ("12 Day Memory Streak").
  static const TextStyle headline = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w900,
  );

  /// 16/w800 — sheet titles.
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// 15/w800 — empty-state headlines.
  static const TextStyle emptyTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  /// 14/w800 — list tile titles.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// 13/w700 — the default body size, and button labels.
  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// 12/w600 — settings rows, detail values.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// 11/w500 — captions, timestamps, @handles.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// 10/w800/1.0 tracking — SECTION HEADERS. Always upper-cased by the caller.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  /// 10/w900 — compact button labels.
  static const TextStyle buttonCompact = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
  );

  /// 13/w900 — regular button labels.
  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  /// 8/w800 — badges and micro-labels. The smallest type Memory permits.
  static const TextStyle micro = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w800,
  );

  /// Tint a style for the current brightness.
  static TextStyle onSurface(TextStyle style, bool dark) =>
      style.copyWith(color: MemoryColors.foregroundOn(dark));

  /// Tint a style as secondary copy for the current brightness.
  static TextStyle mutedOnSurface(
    TextStyle style,
    bool dark, {
    double alpha = MemoryColors.alphaMuted,
  }) => style.copyWith(
    color: MemoryColors.foregroundOn(dark).withValues(alpha: alpha),
  );
}
