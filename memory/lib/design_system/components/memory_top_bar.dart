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

/// A transparent app bar for a [Scaffold].
///
/// Memory's screens carry their own background — a gradient, a photo, the
/// accent — so the bar never paints one of its own, and never casts a shadow
/// onto the surface it floats over.
///
/// Exists so feature code does not reach for [AppBar] and re-decide
/// elevation, background, and title weight on every screen.
class MemoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MemoryAppBar({
    super.key,
    required this.title,
    required this.dark,
    this.leading,
    this.actions = const [],
    this.foreground,
  });

  final String title;
  final bool dark;
  final Widget? leading;
  final List<Widget> actions;

  /// Overrides the title's colour, for a bar sitting on a photo rather than
  /// on a surface.
  final Color? foreground;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: leading,
      actions: actions,
      title: Text(
        title,
        style: foreground == null
            ? MemoryTypography.onSurface(MemoryTypography.headlineMedium, dark)
            : MemoryTypography.headlineMedium.copyWith(color: foreground),
      ),
    );
  }
}
