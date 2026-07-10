import 'package:flutter/widgets.dart';

/// Memory's corner radii.
///
/// Soft, generous corners — never square, never a perfect circle except for
/// [pill] and avatars. Values match the shapes already in use.
abstract final class MemoryRadius {
  /// 4 — progress bars, tiny indicators.
  static const double xs = 4;

  /// 10 — badges, small chips.
  static const double sm = 10;

  /// 16 — inline buttons, small cards.
  static const double md = 16;

  /// 20 — dialogs.
  static const double lg = 20;

  /// 22 — section cards.
  static const double card = 22;

  /// 24 — prominent cards.
  static const double xl = 24;

  /// 26 — bottom sheets.
  static const double sheet = 26;

  /// 28 — the profile panel and hero surfaces.
  static const double xxl = 28;

  /// Fully rounded. Pills, avatars, capsule chips.
  static const double pill = 999;

  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius allSheet = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));
}
