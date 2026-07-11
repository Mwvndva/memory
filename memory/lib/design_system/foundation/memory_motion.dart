import 'package:flutter/animation.dart';

/// Memory's motion vocabulary.
///
/// Understated and spring-flavoured. Nothing announces itself: feedback is
/// felt more than seen. Durations are short enough that the interface never
/// makes the user wait for an animation to finish.
abstract final class MemoryDurations {
  /// 90ms — press-down feedback.
  static const Duration instant = Duration(milliseconds: 90);

  /// 150ms — hover/selection state changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// 220ms — the default: sheets, fades, list insertions.
  static const Duration normal = Duration(milliseconds: 220);

  /// 320ms — page transitions, card expansion.
  static const Duration slow = Duration(milliseconds: 320);

  /// 420ms — celebratory entrances only.
  static const Duration deliberate = Duration(milliseconds: 420);

  /// 900ms — one half-cycle of the skeleton shimmer.
  static const Duration shimmer = Duration(milliseconds: 900);

  /// 1000ms — one half-cycle of the recording pulse.
  static const Duration pulse = Duration(milliseconds: 1000);
}

/// Curves paired with [MemoryDurations].
abstract final class MemoryCurves {
  /// Decelerate. The default for anything entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Accelerate. For anything leaving.
  static const Curve exit = Curves.easeInCubic;

  /// The signature overshoot. Press-release, pop-in, confirmation.
  static const Curve spring = Curves.easeOutBack;

  /// Symmetric. For state changes that are neither entering nor leaving.
  static const Curve standard = Curves.easeInOut;
}

/// How far an element shrinks when pressed.
abstract final class MemoryMotion {
  static const double pressedScale = 0.93;
}
