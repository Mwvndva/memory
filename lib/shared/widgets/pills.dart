import 'package:flutter/material.dart';

import 'package:memory_app/design_system/design_system.dart';

/// Legacy pill button.
///
/// The implementation is gone: this is now a thin adapter over [MemoryButton],
/// so exactly one pill exists in the app. Call sites are migrated screen by
/// screen; when the last one is gone, delete this file.
///
/// Migration: `pill('Go', onTap, dark, color: x, foreground: y)` becomes
/// `MemoryButton(label: 'Go', onPressed: onTap, dark: dark, background: x,
/// foreground: y)`.
///
/// Note the default when `color` is null differs by variant, so a call site
/// that relied on the old default must pass `background:` explicitly or opt
/// into `MemoryButtonVariant.primary` — which is what the old default was.
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
}) => MemoryButton(
  label: text,
  onPressed: disabled ? null : onTap,
  dark: dark,
  background: color,
  foreground: foreground,
  size: compact ? MemoryButtonSize.compact : MemoryButtonSize.regular,
  width: width,
  isLoading: isLoading,
);
