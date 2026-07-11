import 'package:flutter/material.dart';

import '../foundation/memory_elevation.dart';

/// A diagonal gradient fill, used wherever a memory has no image to show.
///
/// Every memory carries two colours derived from its content. When the photo
/// or video is missing, still loading, or failed, we paint those colours
/// instead of a grey box, so the grid keeps its rhythm and a slow network
/// never reads as a broken screen.
///
/// The gradient always runs top-left to bottom-right. That angle is a brand
/// decision, not a per-call one: a feed of tiles each lit from a different
/// corner looks like a mistake.
class MemoryGradientSurface extends StatelessWidget {
  const MemoryGradientSurface({
    super.key,
    required this.colors,
    this.borderRadius,
    this.shadows,
    this.child,
  });

  /// The memory's colours, light end first. A single colour renders flat.
  final List<Color> colors;

  /// Corner rounding. Null leaves the surface square, for callers that clip.
  final BorderRadius? borderRadius;

  /// Optional lift. Pass [MemoryShadows.none] or omit for a flat surface.
  final List<BoxShadow>? shadows;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.length == 1 ? [colors.first, colors.first] : colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: shadows ?? MemoryShadows.none,
      ),
      child: child,
    );
  }
}
