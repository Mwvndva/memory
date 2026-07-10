import 'package:flutter/material.dart';

import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/notification/models/notification_item.dart';

/// One notification in the list.
///
/// Read and unread are distinguished by weight and a single accent dot — not
/// by a heavier border or a louder background. An already-read notification
/// should recede, not disappear.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.dark,
    required this.onTap,
  });

  final NotificationItem item;
  final bool dark;
  final VoidCallback onTap;

  /// The glyph and hue for each kind of notification.
  static (IconData, Color) _glyphFor(NotificationType type) => switch (type) {
    NotificationType.message => (
      Icons.chat_bubble_outline_rounded,
      MemoryColors.accent,
    ),
    NotificationType.reaction => (
      Icons.favorite_outline_rounded,
      MemoryColors.danger,
    ),
    NotificationType.memory => (Icons.camera_alt_outlined, MemoryColors.sky),
    NotificationType.circleRequest => (
      Icons.group_add_outlined,
      MemoryColors.mint,
    ),
    NotificationType.circleMilestone => (
      Icons.celebration_outlined,
      MemoryColors.amber,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _glyphFor(item.type);
    final unread = !item.isRead;

    return Semantics(
      button: true,
      label: '${item.title}. ${item.body}${unread ? '. Unread' : ''}',
      child: BouncyTap(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: MemoryDurations.slow,
          curve: MemoryCurves.standard,
          margin: const EdgeInsets.only(bottom: MemorySpacing.xl),
          padding: const EdgeInsets.symmetric(
            horizontal: MemorySpacing.gutter,
            vertical: MemorySpacing.xxl,
          ),
          decoration: BoxDecoration(
            // Read rows drop their surface entirely and sit on the page.
            color: unread ? MemoryColors.surface(dark) : Colors.transparent,
            borderRadius: BorderRadius.circular(MemoryRadius.lg),
            border: Border.all(
              color: MemoryColors.hairline(
                dark,
                alpha: unread
                    ? MemoryColors.alphaDivider
                    : MemoryColors.alphaHairline,
              ),
            ),
            boxShadow: unread ? MemoryShadows.card(dark) : MemoryShadows.none,
          ),
          child: Row(
            children: [
              _TypeGlyph(icon: icon, tint: tint),
              const SizedBox(width: MemorySpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: MemoryTypography.onSurface(
                        MemoryTypography.body.copyWith(
                          fontWeight: unread
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                        dark,
                      ),
                    ),
                    const SizedBox(height: MemorySpacing.xxs),
                    Text(
                      item.body,
                      style: MemoryTypography.mutedOnSurface(
                        MemoryTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        dark,
                        alpha: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: MemorySpacing.md),
                MemoryBadge(dark: dark, size: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: MemoryColors.alphaScrim),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: tint, size: 18),
    );
  }
}
