import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_typography.dart';
import 'memory_icon_button.dart';

/// Memory's screen header.
///
/// A centred title flanked by optional actions. No AppBar, no elevation, no
/// divider: the title floats over the content it belongs to.
class MemoryTopBar extends StatelessWidget {
  const MemoryTopBar({
    super.key,
    required this.title,
    required this.dark,
    this.onBack,
    this.trailing,
  });

  final String title;
  final bool dark;

  /// When null, no back affordance is shown and the title stays centred.
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Reserved so the title stays optically centred when one side is empty.
  static const double _sideWidth = 40;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _sideWidth,
          child: onBack == null
              ? null
              : MemoryIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: onBack,
                  semanticLabel: 'Back',
                  iconSize: 18,
                  visualSize: 28,
                  color: MemoryColors.foregroundOn(dark),
                ),
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: MemoryTypography.onSurface(
                MemoryTypography.displayLarge,
                dark,
              ),
            ),
          ),
        ),
        SizedBox(
          width: _sideWidth,
          child: trailing == null
              ? null
              : Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }
}

/// A pill-shaped floating action. Memory never uses a circular FAB.
class MemoryFloatingActionButton extends StatelessWidget {
  const MemoryFloatingActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    required this.dark,
    this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool dark;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: dark ? MemoryColors.accent : MemoryColors.ink,
        foregroundColor: dark ? MemoryColors.ink : MemoryColors.accent,
        elevation: 0,
        highlightElevation: 0,
        icon: Icon(icon, size: 18),
        label: Text(label ?? semanticLabel, style: MemoryTypography.button),
      ),
    );
  }
}
