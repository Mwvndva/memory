import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/core/error_handler.dart';
import '../circle_state_manager.dart';

class RequestRow extends ConsumerWidget {
  final CircleMember req;
  final bool dark;

  const RequestRow({super.key, required this.req, required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = req.firstName.isNotEmpty ? req.firstName : req.username;
    final fg = dark ? MemoryColors.cream : MemoryColors.charcoal;
    return Container(
      margin: const EdgeInsets.only(bottom: MemorySpacing.lg),
      padding: const EdgeInsets.all(MemorySpacing.xxl),
      decoration: BoxDecoration(
        color: dark ? MemoryColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(MemoryRadius.card),
        border: Border.all(
          color: (dark ? Colors.white : MemoryColors.charcoal).withValues(
            alpha: 0.07,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          MemoryAvatar(
            radius: 22,
            dark: dark,
            imageUrl: req.avatarUrl == null || req.avatarUrl!.isEmpty
                ? null
                : formatImageUrl(req.avatarUrl!),
            initial: name,
          ),
          const SizedBox(width: MemorySpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: MemoryTypography.bodyStrong.copyWith(color: fg),
                ),
                const SizedBox(height: MemorySpacing.xxs),
                Text(
                  '@${req.username}',
                  style: MemoryTypography.caption.copyWith(
                    color: dark
                        ? MemoryColors.mutedOnDark
                        : MemoryColors.mutedOnLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MemorySpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BouncyTap(
                onTap: () async {
                  try {
                    await ref
                        .read(circleStateManagerProvider.notifier)
                        .acceptRequest(req.id);
                  } catch (e) {
                    if (context.mounted) {
                      showAppError(context, e.toString());
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MemorySpacing.xl,
                    vertical: MemorySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: dark ? MemoryColors.accent : MemoryColors.ink,
                    borderRadius: BorderRadius.circular(MemoryRadius.pill),
                  ),
                  child: Text(
                    'Accept',
                    style: MemoryTypography.caption.copyWith(
                      color: dark ? MemoryColors.ink : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MemorySpacing.md),
              BouncyTap(
                onTap: () async {
                  try {
                    await ref
                        .read(circleStateManagerProvider.notifier)
                        .declineRequest(req.id);
                  } catch (e) {
                    if (context.mounted) {
                      showAppError(context, e.toString());
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MemorySpacing.xl,
                    vertical: MemorySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(MemoryRadius.pill),
                    border: Border.all(
                      color: (dark ? Colors.white : MemoryColors.charcoal)
                          .withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    'Ignore',
                    style: MemoryTypography.caption.copyWith(
                      color: dark
                          ? MemoryColors.mutedOnDark
                          : MemoryColors.mutedOnLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatRow extends ConsumerWidget {
  final CircleMember member;
  final bool dark;

  const ChatRow({super.key, required this.member, required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.firstName.isNotEmpty
        ? member.firstName
        : member.username;
    // Use username (not display name) as the key so WebSocket routing works
    final chatKey = member.username;
    return Container(
      margin: const EdgeInsets.only(bottom: MemorySpacing.lg),
      padding: const EdgeInsets.all(MemorySpacing.xxl),
      decoration: BoxDecoration(
        color: dark ? MemoryColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(MemoryRadius.card),
        border: Border.all(
          color: (dark ? Colors.white : MemoryColors.charcoal).withValues(
            alpha: 0.07,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.push('/chat/$chatKey');
              },
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MemoryAvatar(
                        radius: 22,
                        dark: dark,
                        imageUrl:
                            member.avatarUrl == null ||
                                member.avatarUrl!.isEmpty
                            ? null
                            : formatImageUrl(member.avatarUrl!),
                        initial: name,
                      ),
                      Builder(
                        builder: (context) {
                          final chatState = ref.watch(chatProvider);
                          final hasUnread =
                              (chatState.unreadCounts[chatKey] ?? 0) > 0;
                          if (!hasUnread) return const SizedBox.shrink();
                          return Positioned(
                            top: -2,
                            right: -2,
                            child: MemoryBadge(dark: dark),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: MemorySpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: MemoryTypography.bodyStrong.copyWith(
                                color: dark
                                    ? MemoryColors.cream
                                    : MemoryColors.charcoal,
                              ),
                            ),
                            const SizedBox(width: MemorySpacing.sm),
                            Builder(
                              builder: (context) {
                                final myRole = CircleRole
                                    .owner; // Current user is the owner of their circle
                                final targetRole = member.role;
                                final canManageRole =
                                    (myRole == CircleRole.owner) ||
                                    (myRole == CircleRole.admin &&
                                        targetRole != CircleRole.owner &&
                                        targetRole != CircleRole.admin);

                                if (canManageRole) {
                                  return PopupMenuButton<CircleRole>(
                                    initialValue: member.role,
                                    tooltip: 'Change Role',
                                    onSelected: (newRole) async {
                                      ref
                                          .read(circlesProvider.notifier)
                                          .updateMemberRole(member.id, newRole);
                                      showAppMessage(
                                        context,
                                        'Updated ${member.firstName}\'s role to ${newRole.name}',
                                      );
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        CircleRole.values.map((role) {
                                          return PopupMenuItem<CircleRole>(
                                            value: role,
                                            child: Text(
                                              role.name.toUpperCase(),
                                              style: MemoryTypography
                                                  .buttonCompact
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          );
                                        }).toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: MemorySpacing.sm,
                                        vertical: MemorySpacing.xxs,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (dark
                                                    ? MemoryColors.accent
                                                    : MemoryColors.ink)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          MemoryRadius.xs,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            member.role.name.toUpperCase(),
                                            style: MemoryTypography.micro
                                                .copyWith(
                                                  color: dark
                                                      ? MemoryColors.accent
                                                      : MemoryColors.ink,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(
                                            width: MemorySpacing.xxs,
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 10,
                                            color: dark
                                                ? MemoryColors.accent
                                                : MemoryColors.ink,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: MemorySpacing.sm,
                                      vertical: MemorySpacing.xxs,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (dark
                                                  ? MemoryColors.accent
                                                  : MemoryColors.ink)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        MemoryRadius.xs,
                                      ),
                                    ),
                                    child: Text(
                                      member.role.name.toUpperCase(),
                                      style: MemoryTypography.micro.copyWith(
                                        color: dark
                                            ? MemoryColors.accent
                                            : MemoryColors.ink,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: MemorySpacing.xxs),
                        Builder(
                          builder: (context) {
                            final chatState = ref.watch(chatProvider);
                            final messages =
                                chatState.messagesByContact[chatKey] ?? [];
                            final lastMessage = messages.isNotEmpty
                                ? messages.last.text
                                : 'No messages yet';
                            final hasUnread =
                                (chatState.unreadCounts[chatKey] ?? 0) > 0;
                            return Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MemoryTypography.caption.copyWith(
                                color: hasUnread
                                    ? (dark
                                          ? MemoryColors.cream
                                          : MemoryColors.charcoal)
                                    : (dark
                                          ? MemoryColors.mutedOnDark
                                          : MemoryColors.mutedOnLight),
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final myRole =
                  CircleRole.owner; // Current user is the owner of their circle
              final targetRole = member.role;
              final canRemove =
                  (myRole == CircleRole.owner) ||
                  (myRole == CircleRole.admin &&
                      targetRole != CircleRole.owner &&
                      targetRole != CircleRole.admin) ||
                  (myRole == CircleRole.moderator &&
                      targetRole == CircleRole.member);
              if (!canRemove) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: MemorySpacing.lg),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await MemoryDialog.show<bool>(
                        context: context,
                        builder: (ctx) => MemoryDialog(
                          title: 'Remove from Circle',
                          dark: dark,
                          message:
                              'Are you sure you want to remove $name from your circle? You will no longer share memories or chat with each other.',
                          actions: [
                            MemoryDialogAction(
                              label: 'Cancel',
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                            MemoryDialogAction(
                              label: 'Remove',
                              isDestructive: true,
                              onPressed: () => Navigator.of(ctx).pop(true),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ref
                              .read(circleStateManagerProvider.notifier)
                              .removeMember(member.id);
                        } catch (e) {
                          if (context.mounted) {
                            showAppError(context, e.toString());
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MemorySpacing.xl,
                        vertical: MemorySpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(MemoryRadius.pill),
                        border: Border.all(
                          color: (dark ? Colors.white : MemoryColors.charcoal)
                              .withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        'Remove',
                        style: MemoryTypography.caption.copyWith(
                          color: dark
                              ? MemoryColors.mutedOnDark
                              : MemoryColors.mutedOnLight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
