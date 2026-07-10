import 'package:flutter/material.dart';

import '../foundation/memory_interactions.dart';
import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';
import 'memory_loading.dart';

/// How prominent a [MemoryButton] is.
enum MemoryButtonVariant {
  /// Filled with the accent. One per screen, ideally.
  primary,

  /// A quiet surface with a hairline edge. Everything else.
  secondary,

  /// Destructive. Reserved for irreversible actions.
  danger,

  /// No fill, no edge — just the label. For inline links ("Tap to retry") and
  /// top-bar actions, where a filled pill would outweigh what it does.
  text,
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
  bool get _isText => variant == MemoryButtonVariant.text;

  Color _resolveBackground() {
    // A text button has nothing to grey out; it dims its label instead.
    if (_isText && background == null) return Colors.transparent;
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
      MemoryButtonVariant.text => Colors.transparent,
    };
  }

  Color _resolveForeground() {
    if (foreground != null) return foreground!;
    final base = switch (variant) {
      MemoryButtonVariant.primary =>
        dark ? MemoryColors.ink : MemoryColors.accent,
      MemoryButtonVariant.secondary => MemoryColors.foregroundOn(dark),
      MemoryButtonVariant.danger => Colors.white,
      MemoryButtonVariant.text => dark ? MemoryColors.accent : MemoryColors.ink,
    };
    if (_isText && _disabled) {
      return base.withValues(alpha: MemoryColors.alphaMuted);
    }
    return base;
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
          // A text button hugs its label; every other variant fills its slot.
          width: width ?? (_isText ? null : double.infinity),
          height: _compact ? 34 : 46,
          alignment: Alignment.center,
          padding: _isText
              ? const EdgeInsets.symmetric(horizontal: MemorySpacing.xl)
              : null,
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
              // The spinner must take the label's colour, not the ambient
              // theme's: an accent-filled button would otherwise spin in
              // accent-on-accent and show nothing at all.
              if (isLoading)
                MemoryLoading(size: 18, color: _resolveForeground()),
            ],
          ),
        ),
      ),
    );
  }
}
