import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';

/// The container every Memory bottom sheet is presented in.
///
/// Sheets float: they inset from the screen edges rather than docking to the
/// bottom, and they clear the home indicator themselves.
class MemoryBottomSheet extends StatelessWidget {
  const MemoryBottomSheet({super.key, required this.dark, required this.child});

  final bool dark;
  final Widget child;

  /// Present [builder] as a Memory sheet on the root navigator.
  ///
  /// Centralised so no screen has to remember `backgroundColor: transparent`
  /// or `useRootNavigator`.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(MemorySpacing.sheet),
        padding: const EdgeInsets.all(MemorySpacing.sheet),
        decoration: BoxDecoration(
          color: MemoryColors.ink,
          borderRadius: MemoryRadius.allSheet,
          border: Border.all(
            color: MemoryColors.hairline(
              dark,
              alpha: MemoryColors.alphaHairline,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
