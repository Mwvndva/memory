import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';

/// A hairline rule.
///
/// Memory separates rows with a thin line, never with a border around each
/// row. 0.8 logical pixels reads as a true hairline on every density we ship.
class MemoryDivider extends StatelessWidget {
  const MemoryDivider({super.key, required this.dark});

  final bool dark;

  static const double thickness = 0.8;

  /// The rule as a [Border] for callers that decorate their own container.
  static Border bottom(bool dark) => Border(
    bottom: BorderSide(
      color: MemoryColors.hairline(dark, alpha: MemoryColors.alphaDivider),
      width: thickness,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      color: MemoryColors.hairline(dark, alpha: MemoryColors.alphaDivider),
    );
  }
}
