import 'package:flutter/material.dart';

import 'package:memory_app/core/playful.dart';
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

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: BouncyTap(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTouchTarget,
            minHeight: minTouchTarget,
          ),
          child: Center(child: visual),
        ),
      ),
    );
  }
}
