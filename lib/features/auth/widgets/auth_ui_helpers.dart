import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memory_app/design_system/design_system.dart';

TextStyle headlineStyle(Color color) =>
    MemoryTypography.displayLarge.copyWith(color: color);

TextStyle smallStyle(Color color) => MemoryTypography.caption.copyWith(
  color: color,
  fontWeight: FontWeight.w900,
);

Widget authStatusIndicator(String text, bool ok) => Padding(
  padding: const EdgeInsets.only(top: MemorySpacing.sm),
  child: Text(
    text,
    style: MemoryTypography.buttonCompact.copyWith(
      color: ok ? MemoryColors.success : MemoryColors.ink,
    ),
  ),
);

Widget authInputField(
  String label,
  TextEditingController controller,
  String hint,
  bool dark, {
  bool obscure = false,
  TextInputType? keyboard,
  VoidCallback? onToggleObscure,
}) {
  // The auth surfaces invert: a solid slab behind bright text, rather than the
  // translucent well a field sits in everywhere else.
  final fill = dark ? MemoryColors.accent : MemoryColors.ink;
  final ink = dark ? MemoryColors.ink : Colors.white;

  return MemoryTextField(
    controller: controller,
    hint: hint,
    dark: dark,
    label: label,
    obscureText: obscure,
    keyboardType: keyboard,
    background: fill,
    foreground: ink,
    inputFormatters: keyboard == TextInputType.phone
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    suffix: onToggleObscure == null
        ? null
        : MemoryIconButton(
            icon: obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            semanticLabel: obscure ? 'Show password' : 'Hide password',
            color: ink.withValues(alpha: 0.8),
            onPressed: onToggleObscure,
          ),
  );
}

Widget passwordValidationIndicator(String pass, String confirm) {
  final lengthOk = pass.length >= 8;
  final upper = RegExp(r'[A-Z]').hasMatch(pass);
  final lower = RegExp(r'[a-z]').hasMatch(pass);
  final digit = RegExp(r'\d').hasMatch(pass);
  final special = RegExp(
    r'[!@#\$%\^&*(),.?":{}|<>~`_\-\\/\[\];\+=]',
  ).hasMatch(pass);

  Widget row(bool ok, String text) => Padding(
    padding: const EdgeInsets.only(top: MemorySpacing.xs),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: ok ? MemoryColors.success : MemoryColors.ink,
        ),
        const SizedBox(width: MemorySpacing.md),
        Text(
          text,
          style: MemoryTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: MemoryColors.ink,
          ),
        ),
      ],
    ),
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      row(lengthOk, 'At least 8 characters'),
      row(upper, 'Contains an uppercase letter'),
      row(lower, 'Contains a lowercase letter'),
      row(digit, 'Contains a number'),
      row(special, 'Contains a special character'),
      if (pass.isNotEmpty || confirm.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: MemorySpacing.sm),
          child: Text(
            pass == confirm ? 'Passwords match' : 'Passwords do not match',
            style: MemoryTypography.bodySmall.copyWith(
              color: pass == confirm ? MemoryColors.success : MemoryColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

Widget passwordRequirements(String pass, String confirm) {
  return passwordValidationIndicator(pass, confirm);
}
