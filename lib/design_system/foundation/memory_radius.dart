import 'package:flutter/widgets.dart';

/// Memory's corner radii.
///
/// Soft, generous corners — never square, never a perfect circle except for
/// [pill] and avatars.
///
/// Five steps, doubling: 4, 8, 12, 16, 24. The scale used to carry 20, 22, 24,
/// 26, and 28 as separate names, which nobody can tell apart and which
/// guaranteed the next screen would invent a sixth. Anything that used to be
/// 20 or larger is now [xl].
///
/// [pill] is not a step. It is a shape — "round this completely" — and it
/// stays because a pill button's radius must track its own height, not a
/// number on a scale.
abstract final class MemoryRadius {
  /// 4 — progress bars, tiny indicators.
  static const double xs = 4;

  /// 8 — badges, small chips, thumbnails.
  static const double sm = 8;

  /// 12 — inline controls, grid tiles.
  static const double md = 12;

  /// 16 — cards, inline buttons, input fields.
  static const double lg = 16;

  /// 24 — dialogs, bottom sheets, the profile panel, hero surfaces.
  static const double xl = 24;

  /// Fully rounded. Pills, avatars, capsule chips.
  static const double pill = 999;

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));
}
