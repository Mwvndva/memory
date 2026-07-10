import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_elevation.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';

/// Memory's surface primitive.
///
/// A soft rounded rectangle with a single subtle shadow and a hairline edge —
/// never a heavy border. Everything that reads as "a card" in Memory is one of
/// these, so radius and depth stay consistent across the app.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.dark,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MemorySpacing.xxl,
      vertical: MemorySpacing.xxs,
    ),
    this.radius = MemoryRadius.xl,
    this.shadow,
    this.showEdge = true,
  });

  final bool dark;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Defaults to [MemoryShadows.card].
  final List<BoxShadow>? shadow;

  /// The hairline. Off for cards that sit on their own coloured ground.
  final bool showEdge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: MemoryColors.surface(dark),
        borderRadius: BorderRadius.circular(radius),
        border: showEdge
            ? Border.all(color: MemoryColors.hairline(dark), width: 1)
            : null,
        boxShadow: shadow ?? MemoryShadows.card(dark),
      ),
      child: child,
    );
  }
}
