import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// Memory's text input.
///
/// No outline. The field is a filled, soft-cornered surface; focus is shown by
/// a hairline in the accent, not by a heavy border.
class MemoryTextField extends StatelessWidget {
  const MemoryTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.dark,
    this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
    this.prefix,
    this.maxLength,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.inputFormatters,
    this.background,
    this.foreground,
  });

  final TextEditingController controller;
  final String hint;
  final bool dark;

  /// Rendered above the field, not inside it: a floating label competes with
  /// the value for the same space.
  final String? label;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  /// Escape hatches for the auth screens, whose fields invert the surface:
  /// solid ink behind white text. Prefer the defaults everywhere else.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? MemoryColors.foregroundOn(dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: MemoryTypography.mutedOnSurface(
              MemoryTypography.caption.copyWith(fontWeight: FontWeight.w700),
              dark,
            ),
          ),
          const SizedBox(height: MemorySpacing.sm),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          // A password field must opt out of the keyboard's help. With
          // suggestions and autocorrect left on, Gboard and Samsung's keyboard
          // treat the hidden value as a word to complete and rewrite it as you
          // type, so the password you send is not the one you keyed. Obscured
          // fields also want the password keyboard, never an autofilling text
          // one.
          autocorrect: !obscureText,
          enableSuggestions: !obscureText,
          keyboardType:
              keyboardType ??
              (obscureText ? TextInputType.visiblePassword : null),
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: MemoryTypography.bodyMedium.copyWith(color: fg),
          cursorColor: MemoryColors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: MemoryTypography.bodyMedium.copyWith(
              color: fg.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
            counterText: '',
            errorText: errorText,
            errorStyle: MemoryTypography.caption.copyWith(
              color: MemoryColors.danger,
            ),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor:
                background ?? fg.withValues(alpha: MemoryColors.alphaBorder),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MemorySpacing.gutter,
              vertical: MemorySpacing.xxl,
            ),
            border: const OutlineInputBorder(
              borderRadius: MemoryRadius.allLg,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: MemoryRadius.allLg,
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: MemoryRadius.allLg,
              borderSide: BorderSide(color: MemoryColors.accent, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

/// A text field that hides its value, with a reveal toggle.
class MemoryPasswordField extends StatefulWidget {
  const MemoryPasswordField({
    super.key,
    required this.controller,
    required this.hint,
    required this.dark,
    this.label,
    this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final bool dark;
  final String? label;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<MemoryPasswordField> createState() => _MemoryPasswordFieldState();
}

class _MemoryPasswordFieldState extends State<MemoryPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return MemoryTextField(
      controller: widget.controller,
      hint: widget.hint,
      dark: widget.dark,
      label: widget.label,
      obscureText: _obscured,
      onChanged: widget.onChanged,
      errorText: widget.errorText,
      suffix: Semantics(
        button: true,
        label: _obscured ? 'Show password' : 'Hide password',
        child: IconButton(
          icon: Icon(
            _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: MemoryColors.muted(widget.dark),
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// A rounded search input.
class MemorySearchField extends StatelessWidget {
  const MemorySearchField({
    super.key,
    required this.controller,
    required this.dark,
    this.hint = 'Search',
    this.onChanged,
  });

  final TextEditingController controller;
  final bool dark;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MemoryTextField(
      controller: controller,
      hint: hint,
      dark: dark,
      onChanged: onChanged,
      prefix: Icon(
        Icons.search_rounded,
        size: 18,
        color: MemoryColors.muted(dark),
      ),
    );
  }
}

/// A text input with no chrome at all: no fill, no border, no counter.
///
/// For places where the surface already frames the input — a chat composer, a
/// comment box, a caption typed straight onto a photo. A boxed field there
/// would draw a rectangle around something that is already inside one.
class MemoryInlineField extends StatelessWidget {
  const MemoryInlineField({
    super.key,
    required this.controller,
    required this.hint,
    required this.style,
    this.hintColor,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;

  /// The typed text's style. Callers pass a token; a caption over a photo is
  /// not set at the same size as a chat message.
  final TextStyle style;

  /// Defaults to the typed text's colour, faded.
  final Color? hintColor;

  final TextAlign textAlign;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hintTint =
        hintColor ??
        (style.color ?? MemoryColors.mutedOnDark).withValues(alpha: 0.4);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      textAlign: textAlign,
      style: style,
      cursorColor: MemoryColors.accent,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: style.copyWith(color: hintTint),
      ),
    );
  }
}
