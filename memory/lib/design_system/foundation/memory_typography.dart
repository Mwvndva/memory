import 'package:flutter/material.dart';

import 'memory_colors.dart';

/// Memory's type scale.
///
/// The app is set in Plus Jakarta Sans (applied once in `main.dart` via
/// `GoogleFonts.plusJakartaSansTextTheme`), so these styles deliberately carry
/// no `fontFamily` — they inherit it. None of them carries a colour either:
/// colour comes from the surface, via [onSurface] and [mutedOnSurface].
///
/// Ten steps, and no more. Feature code must never construct a `TextStyle`.
/// If a screen wants a size that is not here, the answer is almost always that
/// it should use the nearest step; the scale earns its keep by being small
/// enough that two screens cannot drift a point apart.
///
/// Memory leans on weight rather than size for hierarchy: a heavy small label
/// reads as a section header, not a shouty one.
abstract final class MemoryTypography {
  // ── The scale ────────────────────────────────────────────────────────────

  /// 32/w900 — the auth screens' opening line. The largest type in the app
  /// that is still a sentence.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    height: 1,
    fontWeight: FontWeight.w900,
  );

  /// 24/w900 — a headline number: a streak count, a rank, a milestone.
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
  );

  /// 20/w900 — the title of a screen ("Notifications", "Your circle").
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  /// 18/w900 — a section heading, and what an empty screen says.
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  /// 16/w800 — sheet titles, and the largest body copy.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// 14/w800 — list tile titles.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// 13/w700 — the default body size.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// 12/w600 — settings rows, detail values, secondary copy.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// 11/w500 — timestamps, @handles, hints.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// 10/w800, tracked out — SECTION HEADERS. Upper-cased by the caller.
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  // ── Off-scale, and each one earns it ─────────────────────────────────────

  /// 36/w900 — the wordmark on the login screen. One string, one place. It is
  /// larger than [displayLarge] because it is a logo, not a sentence.
  static const TextStyle wordmark = TextStyle(
    fontSize: 36,
    height: 1,
    fontWeight: FontWeight.w900,
  );

  /// 28/w900/1.05 — a memory's caption, set over the photo or video it
  /// belongs to. It is sized to fill the frame rather than to sit in a
  /// paragraph, so it does not belong to the reading scale.
  static const TextStyle mediaCaption = TextStyle(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w900,
  );

  /// 9/w900 — the digits inside a badge. Below [overline] because a badge is
  /// a dot that happens to contain a number.
  static const TextStyle micro = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w900,
  );

  /// 13/w900 — a button label. [bodyMedium]'s size at a button's weight.
  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  /// 10/w900 — a compact button label.
  static const TextStyle buttonCompact = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
  );

  /// An emoji is a picture, not type: it has no weight and no family, and its
  /// line height is pinned so it does not push its row apart. The size is the
  /// only thing a caller chooses.
  static TextStyle emoji(double size) => TextStyle(fontSize: size, height: 1);

  // ── Tinting ──────────────────────────────────────────────────────────────

  /// Tint a style for the current brightness.
  static TextStyle onSurface(TextStyle style, bool dark) =>
      style.copyWith(color: MemoryColors.foregroundOn(dark));

  /// Tint a style as secondary copy for the current brightness.
  static TextStyle mutedOnSurface(
    TextStyle style,
    bool dark, {
    double alpha = MemoryColors.alphaMuted,
  }) =>
      style.copyWith(color: MemoryColors.muted(dark).withValues(alpha: alpha));
}
