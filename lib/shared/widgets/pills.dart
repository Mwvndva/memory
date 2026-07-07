import 'package:flutter/material.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/playful.dart';

Widget pill(
  String text,
  VoidCallback onTap,
  bool dark, {
  Color? color,
  Color? foreground,
  bool compact = false,
  double? width,
  bool isLoading = false,
  bool disabled = false,
}) => BouncyTap(
  onTap: disabled || isLoading ? null : onTap,
  child: Container(
    width: width ?? double.infinity,
    height: compact ? 34 : 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: disabled || isLoading
          ? (dark
                ? kBlack.withValues(alpha: 0.12)
                : kCharcoal.withValues(alpha: 0.06))
          : (color ?? (dark ? kYellow : kBlack)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: isLoading ? 0 : 1,
          child: Text(
            text,
            style: TextStyle(
              color: foreground ?? (dark ? kBlack : kYellow),
              fontSize: compact ? 10 : 13,
              fontWeight: FontWeight.w900,
            ),
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
);
