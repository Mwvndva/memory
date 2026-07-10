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

  /// Confirmation. Deeper than [mint] so it stays legible as 10px text on
  /// the cream auth surfaces, where mint washes out.
  static const success = Color(0xFF20A978);

  // ── Third-party brand marks (share sheets only) ──────────────────────────
  static const instagram = Color(0xFFE1306C);
  static const whatsApp = Color(0xFF25D366);

  /// Instagram's story gradient, in the order Instagram draws it.
  static const instagramGradient = [
    Color(0xFFF058A0),
    Color(0xFFBD3EFF),
    Color(0xFFFF6B00),
  ];

  /// WhatsApp's two greens, light stop first.
  static const whatsAppGradient = [whatsApp, Color(0xFF128C7E)];

  // ── Streak tiers ─────────────────────────────────────────────────────────
  //
  // Bronze → Silver → Gold → Diamond, by consecutive days. These are the
  // metals, not brand hues: they are recognisable precisely because they are
  // the colours everyone already expects a medal to be.
  static const tierBronze = Color(0xFFCD7F32);
  static const tierSilver = Color(0xFFC0C0C0);
  static const tierGold = Color(0xFFFFD700);
  static const tierDiamond = Color(0xFF89CFF0);

  // ── Elevated dark surfaces ───────────────────────────────────────────────
  //
  // The second stop of a dark gradient. Near-black, but not [ink]: a gradient
  // from ink to ink is a flat fill.
  static const inkRaised = Color(0xFF151515);
  static const inkRaisedAlt = Color(0xFF171717);
  static const inkElevated = Color(0xFF1E1E1E);
  static const inkElevatedAlt = Color(0xFF2C2C2C);

  /// The warm stop paired with [accent] in an outgoing chat bubble.
  static const accentGlow = Color(0xFFFFD54F);

  /// The violet a capture is tinted with when it carries no colour of its own.
  static const captureGradient = [Color(0xFF8E2DE2), Color(0xFF4A00E0)];

  /// The default memory gradient, for a memory the server sent no colours for.
  static const memoryFallbackGradient = [Color(0xFFFF826E), amber, mint];

  /// Milestone confetti. Deliberately loud, and deliberately not the brand:
  /// a milestone card is the one place Memory is allowed to shout.
  static const celebration = [
    Color(0xFFFF1493), // hot pink
    Color(0xFFBD3EFF), // electric purple
    Color(0xFF00F5FF), // electric cyan
    Color(0xFF39FF14), // neon lime
    Color(0xFFFF5E00), // vivid orange
    accentWarm, // gold yellow
    Color(0xFFFF3366), // coral red
    Color(0xFF6C5DD3), // retro lavender
  ];

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
