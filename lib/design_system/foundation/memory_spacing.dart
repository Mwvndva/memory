/// Memory's spacing scale.
///
/// A 2px base with a 4px rhythm. Screens use these instead of bare numbers so
/// vertical rhythm stays consistent when a component's padding changes.
abstract final class MemorySpacing {
  /// 2 — hairline gaps, icon nudges.
  static const double xxs = 2;

  /// 4 — between a label and its value.
  static const double xs = 4;

  /// 6 — inside chips and badges.
  static const double sm = 6;

  /// 8 — the default gap between siblings.
  static const double md = 8;

  /// 10 — chip padding.
  static const double lg = 10;

  /// 12 — between cards in a list.
  static const double xl = 12;

  /// 14 — card padding.
  static const double xxl = 14;

  /// 16 — screen gutters.
  static const double gutter = 16;

  /// 18 — sheet padding.
  static const double sheet = 18;

  /// 20 — section breaks.
  static const double section = 20;

  /// 28 — a generous break before a screen's primary action, where a section
  /// gap reads as too tight to separate a form from its buttons.
  static const double xxxl = 28;
}
