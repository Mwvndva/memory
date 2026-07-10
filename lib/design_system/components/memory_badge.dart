import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';

/// The unread dot.
///
/// A count is deliberately not shown: Memory tells you *that* something is
/// waiting, not how far behind you are.
class MemoryBadge extends StatelessWidget {
  const MemoryBadge({super.key, required this.dark, this.size = 14});

  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Unread',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: MemoryColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: MemoryColors.surface(dark), width: 2),
        ),
      ),
    );
  }
}

/// A small capsule of text: a role, a rank, a status.
class MemoryChip extends StatelessWidget {
  const MemoryChip({
    super.key,
    required this.label,
    required this.dark,
    this.leading,
    this.trailing,
    this.onTap,
    this.background,
    this.foreground,
  });

  final String label;
  final bool dark;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? MemoryColors.foregroundOn(dark);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            background ??
            MemoryColors.hairline(dark, alpha: MemoryColors.alphaHairline),
        borderRadius: MemoryRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
