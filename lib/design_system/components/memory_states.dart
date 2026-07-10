import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_motion.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';
import 'memory_button.dart';

/// A shimmering placeholder shown while real content loads.
///
/// Preferred over a spinner wherever the shape of the incoming content is
/// known: the layout does not jump when the data lands.
class MemorySkeleton extends StatefulWidget {
  const MemorySkeleton({
    super.key,
    required this.dark,
    this.width,
    this.height = 14,
    this.radius = MemoryRadius.sm,
  });

  final bool dark;
  final double? width;
  final double height;
  final double radius;

  @override
  State<MemorySkeleton> createState() => _MemorySkeletonState();
}

class _MemorySkeletonState extends State<MemorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MemoryDurations.shimmer,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = MemoryColors.foregroundOn(widget.dark);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.05 + (_controller.value * 0.05)),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// What Memory shows when something went wrong and the user can retry.
class MemoryErrorState extends StatelessWidget {
  const MemoryErrorState({
    super.key,
    required this.message,
    required this.dark,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final bool dark;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MemorySpacing.section),
      decoration: BoxDecoration(
        color: MemoryColors.surface(dark),
        borderRadius: BorderRadius.circular(MemoryRadius.xl),
        border: Border.all(
          color: MemoryColors.hairline(dark, alpha: MemoryColors.alphaHairline),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: MemoryColors.muted(dark),
            size: 28,
          ),
          const SizedBox(height: MemorySpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: MemoryTypography.onSurface(
              MemoryTypography.emptyTitle,
              dark,
            ),
          ),
          const SizedBox(height: MemorySpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MemoryTypography.bodySmall.copyWith(
              color: MemoryColors.muted(dark),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: MemorySpacing.gutter),
            SizedBox(
              width: 140,
              child: MemoryButton(
                label: 'Try again',
                onPressed: onRetry,
                dark: dark,
                size: MemoryButtonSize.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A determinate progress bar. Uploads, compression, processing.
class MemoryProgressIndicator extends StatelessWidget {
  const MemoryProgressIndicator({
    super.key,
    required this.value,
    required this.dark,
    this.height = 4,
  });

  /// 0.0 → 1.0. Null renders an indeterminate bar.
  final double? value;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MemoryRadius.xs),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: MemoryColors.foregroundOn(
          dark,
        ).withValues(alpha: MemoryColors.alphaScrim),
        valueColor: const AlwaysStoppedAnimation(MemoryColors.accent),
      ),
    );
  }
}
