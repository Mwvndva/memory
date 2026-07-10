import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_spacing.dart';

/// Memory's only spinner.
///
/// Understated: it never fills the screen, and it never blocks a surface the
/// user could still read.
class MemoryLoading extends StatelessWidget {
  const MemoryLoading({super.key, this.size = 18, this.color});

  /// Sized to sit inside a button by default.
  final double size;
  final Color? color;

  /// A centred spinner with breathing room, for a section that is loading.
  const MemoryLoading.block({super.key, this.color}) : size = 24;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MemorySpacing.section),
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: color ?? MemoryColors.accent,
          ),
        ),
      ),
    );
  }
}
