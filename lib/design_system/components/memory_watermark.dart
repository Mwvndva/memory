import 'package:flutter/material.dart';

/// The tilted "M" ghosted into the background of a surface.
///
/// It is a mark, not text: it is never read, it carries no semantics, and its
/// size is a composition choice rather than a step on the type scale. Keeping
/// it out of [MemoryTypography] is the point — a 50pt and an 80pt "M" would
/// otherwise look like two missing scale steps.
class MemoryWatermark extends StatelessWidget {
  const MemoryWatermark({
    super.key,
    required this.size,
    required this.angle,
    required this.opacity,
    this.color = Colors.white,
  });

  /// Height of the letter, in logical pixels.
  final double size;

  /// Rotation, in radians.
  final double angle;

  /// How faint. These sit at a few percent: felt, not seen.
  final double opacity;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Text(
            'M',
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
