import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/memory_interactions.dart';
import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';

/// Memory's icon-only control.
///
/// Renders at [visualSize] but always presents a 48dp hit target, so a compact
/// glyph never becomes an unreachable tap.
class MemoryIconButton extends StatelessWidget {
  const MemoryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color,
    this.iconSize = 20,
    this.visualSize = 36,
    this.filled = false,
    this.background,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Required: an icon with no label is invisible to a screen reader.
  final String semanticLabel;

  final Color? color;
  final double iconSize;
  final double visualSize;

  /// Gives the glyph a tinted disc behind it.
  final bool filled;
  final Color? background;

  /// The minimum comfortable touch target.
  static const double minTouchTarget = 48;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: iconSize, color: color);

    final visual = filled
        ? Container(
            width: visualSize,
            height: visualSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? MemoryColors.ink.withValues(alpha: 0.35),
              borderRadius: MemoryRadius.allPill,
            ),
            child: glyph,
          )
        : SizedBox(
            width: visualSize,
            height: visualSize,
            child: Center(child: glyph),
          );

    // A fixed square, not a min-size box. A ConstrainedBox with only a minimum
    // lets the inner Center grow to whatever maximum width it is offered. In a
    // Row that maximum is unbounded, so it shrink-wraps and all is well — but as
    // a TextField's suffixIcon, InputDecorator offers it the whole field width,
    // and the button swells to cover the input, so the field can never be typed
    // in. Sizing to a definite side keeps the hit target at 48dp everywhere.
    final side = math.max(visualSize, minTouchTarget);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: BouncyTap(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: side,
          child: Center(child: visual),
        ),
      ),
    );
  }
}
