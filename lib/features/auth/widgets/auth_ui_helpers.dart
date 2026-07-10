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
  padding: const EdgeInsets.only(top: 6),
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
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: MemoryTypography.caption.copyWith(
        color: dark ? MemoryColors.cream : MemoryColors.charcoal,
        fontWeight: FontWeight.w900,
      ),
    ),
    const SizedBox(height: 7),
    TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: MemoryTypography.button.copyWith(
        color: dark ? MemoryColors.ink : Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MemoryTypography.body.copyWith(
          color: (dark ? MemoryColors.ink : Colors.white).withValues(
            alpha: 0.35,
          ),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: dark ? MemoryColors.accent : MemoryColors.ink,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        suffixIcon: onToggleObscure == null
            ? null
            : GestureDetector(
                onTap: onToggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: (dark ? MemoryColors.ink : Colors.white).withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ),
      ),
    ),
  ],
);

Widget passwordValidationIndicator(String pass, String confirm) {
  final lengthOk = pass.length >= 8;
  final upper = RegExp(r'[A-Z]').hasMatch(pass);
  final lower = RegExp(r'[a-z]').hasMatch(pass);
  final digit = RegExp(r'\d').hasMatch(pass);
  final special = RegExp(
    r'[!@#\$%\^&*(),.?":{}|<>~`_\-\\/\[\];\+=]',
  ).hasMatch(pass);

  Widget row(bool ok, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: ok ? MemoryColors.success : MemoryColors.ink,
        ),
        const SizedBox(width: 8),
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
          padding: const EdgeInsets.only(top: 6),
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
