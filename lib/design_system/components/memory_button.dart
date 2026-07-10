import 'package:flutter/material.dart';

import '../foundation/memory_interactions.dart';
import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_typography.dart';

/// How prominent a [MemoryButton] is.
enum MemoryButtonVariant {
  /// Filled with the accent. One per screen, ideally.
  primary,

  /// A quiet surface with a hairline edge. Everything else.
  secondary,

  /// Destructive. Reserved for irreversible actions.
  danger,
}

/// Two heights. Compact is for buttons that sit inside a card.
enum MemoryButtonSize { regular, compact }

/// Memory's pill button.
///
/// Replaces the two divergent implementations that existed before: the
/// `pill()` helper used by auth, and `ProfilePill` used by the profile sheets.
/// Both are expressible as variants, and both now share the same press
/// feedback ([BouncyTap]) — previously only auth buttons had it.
class MemoryButton extends StatelessWidget {
  const MemoryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.dark,
    this.variant = MemoryButtonVariant.primary,
    this.size = MemoryButtonSize.regular,
    this.width,
    this.isLoading = false,
    this.background,
    this.foreground,
  });

  final String label;

  /// Null disables the button. A disabled button never reports a press.
  final VoidCallback? onPressed;
  final bool dark;
  final MemoryButtonVariant variant;
  final MemoryButtonSize size;

  /// Defaults to filling the available width.
  final double? width;
  final bool isLoading;

  /// Escape hatches for the share sheet's brand-coloured buttons. Prefer
  /// [variant] — reach for these only when a third-party brand demands it.
  final Color? background;
  final Color? foreground;

  bool get _disabled => onPressed == null || isLoading;
  bool get _compact => size == MemoryButtonSize.compact;

  Color _resolveBackground() {
    if (_disabled) {
      return dark
          ? MemoryColors.ink.withValues(alpha: MemoryColors.alphaScrim)
          : MemoryColors.charcoal.withValues(alpha: MemoryColors.alphaHairline);
    }
    if (background != null) return background!;
    return switch (variant) {
      MemoryButtonVariant.primary =>
        dark ? MemoryColors.accent : MemoryColors.ink,
      MemoryButtonVariant.secondary =>
        dark ? MemoryColors.ink : MemoryColors.cream,
      MemoryButtonVariant.danger => MemoryColors.danger,
    };
  }

  Color _resolveForeground() {
    if (foreground != null) return foreground!;
    return switch (variant) {
      MemoryButtonVariant.primary =>
        dark ? MemoryColors.ink : MemoryColors.accent,
      MemoryButtonVariant.secondary => MemoryColors.foregroundOn(dark),
      MemoryButtonVariant.danger => Colors.white,
    };
  }

  /// Only the quiet variant carries an edge, and only when it is not tinted.
  BoxBorder? _resolveBorder() {
    final isPlainSecondary =
        variant == MemoryButtonVariant.secondary && background == null;
    if (!isPlainSecondary) return null;
    return Border.all(
      color: MemoryColors.hairline(dark, alpha: MemoryColors.alphaHairline),
    );
  }

  @override
  Widget build(BuildContext context) {
    // BouncyTap is a GestureDetector; without this a screen reader announces
    // the label as plain text rather than as a button.
    return Semantics(
      button: true,
      enabled: !_disabled,
      label: label,
      child: BouncyTap(
        onTap: _disabled ? null : onPressed,
        child: Container(
          width: width ?? double.infinity,
          height: _compact ? 34 : 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _resolveBackground(),
            borderRadius: MemoryRadius.allPill,
            border: _resolveBorder(),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isLoading ? 0 : 1,
                child: Text(
                  label,
                  style:
                      (_compact
                              ? MemoryTypography.buttonCompact
                              : MemoryTypography.button)
                          .copyWith(color: _resolveForeground()),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
