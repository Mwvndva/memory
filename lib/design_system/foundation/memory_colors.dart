import 'package:flutter/material.dart';

/// Memory's colour palette.
///
/// Every value here is lifted verbatim from the constants that were previously
/// scattered across feature code, so adopting these tokens changed nothing on
/// screen. Those legacy `k*` constants have since been deleted: this class is
/// now the only place a colour is defined.
abstract final class MemoryColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  /// The single accent. Used sparingly: primary actions, active state, focus.
  static const accent = Color(0xFFF4C430);

  /// The warmer accent used on gradients and celebratory surfaces.
  static const accentWarm = Color(0xFFFADA5E);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  /// Deepest surface and default foreground on light backgrounds.
  static const ink = Color(0xFF000000);

  /// Softer ink for body copy; never pure black on cream.
  static const charcoal = Color(0xFF191716);

  /// The default light surface.
  static const cream = Color(0xFFFFF8EF);

  /// Foreground on dark surfaces.
  static const onDark = cream;

  // ── Muted text ───────────────────────────────────────────────────────────
  /// Secondary copy on dark surfaces.
  static const mutedOnDark = Color(0xFFC9B8AA);

  /// Secondary copy on light surfaces.
  static const mutedOnLight = Color(0xFF776B62);

  // ── Supporting hues (stat cards, gradients) ──────────────────────────────
  static const amber = Color(0xFFFFC857);
  static const mint = Color(0xFF5ED6B3);
  static const sky = Color(0xFF63B3FF);
  static const lavender = Color(0xFFBBA7FF);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const danger = Colors.red;
  static const success = mint;

  // ── Third-party brand marks (share sheets only) ──────────────────────────
  static const instagram = Color(0xFFE1306C);
  static const whatsApp = Color(0xFF25D366);

  // ── Opacity ramp ─────────────────────────────────────────────────────────
  //
  // Standardised alphas. Named by intent so a screen never reasons about a
  // magic 0.06 vs 0.08.
  static const double alphaHairline = 0.06;
  static const double alphaBorder = 0.08;
  static const double alphaDivider = 0.10;
  static const double alphaScrim = 0.12;
  static const double alphaMuted = 0.66;
  static const double alphaSecondary = 0.80;

  /// Foreground for [surface], honouring the dark flag.
  static Color foregroundOn(bool dark) => dark ? cream : charcoal;

  /// The card/sheet surface for the current brightness.
  static Color surface(bool dark) => dark ? ink : Colors.white;

  /// Secondary copy for the current brightness.
  static Color muted(bool dark) => dark ? mutedOnDark : mutedOnLight;

  /// A hairline rule/border colour for the current brightness.
  static Color hairline(bool dark, {double alpha = alphaBorder}) =>
      (dark ? Colors.white : charcoal).withValues(alpha: alpha);
}
