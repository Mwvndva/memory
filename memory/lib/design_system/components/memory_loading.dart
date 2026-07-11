import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_spacing.dart';

/// Memory's only spinner.
///
/// Understated: it never fills the screen, and it never blocks a surface the
/// user could still read.
///
/// The default constructor is bare — no centring, no padding — so it can sit
/// inside a button, a text field suffix, or a chat bubble without pushing its
/// neighbours around. Use [MemoryLoading.block] for a section that is loading
/// and needs the spinner centred with breathing room.
class MemoryLoading extends StatelessWidget {
  const MemoryLoading({super.key, this.size = 18, this.color, this.value})
    : _block = false;

  /// A centred spinner with breathing room, for a section that is loading.
  const MemoryLoading.block({super.key, this.color, this.value})
    : size = 24,
      _block = true;

  /// Sized to sit inside a button by default.
  final double size;
  final Color? color;

  /// Progress from 0 to 1. Null spins indeterminately.
  ///
  /// Prefer a real value whenever one exists: an upload that reports progress
  /// feels bounded, and one that only spins feels stuck.
  final double? value;

  final bool _block;

  @override
  Widget build(BuildContext context) {
    // Stroke scales with the dot so a 10px inline spinner does not read as a
    // solid disc and a 24px one does not look hairline.
    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: (size / 8).clamp(1.2, 3.0),
        color: color ?? MemoryColors.accent,
      ),
    );

    if (!_block) return spinner;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MemorySpacing.section),
        child: spinner,
      ),
    );
  }
}
