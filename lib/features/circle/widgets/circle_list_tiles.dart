import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/playful.dart';
import 'package:memory_app/core/error_handler.dart';
import '../circle_state_manager.dart';

class RequestRow extends ConsumerWidget {
  final CircleMember req;
  final bool dark;

  const RequestRow({super.key, required this.req, required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = req.firstName.isNotEmpty ? req.firstName : req.username;
    final fg = dark ? kCream : kCharcoal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kBlack : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.07),
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
          CircleAvatar(
            radius: 22,
            backgroundColor: dark ? kYellow : kBlack,
            backgroundImage:
                (req.avatarUrl != null && req.avatarUrl!.isNotEmpty)
                ? NetworkImage(formatImageUrl(req.avatarUrl!)) as ImageProvider
                : null,
            child: (req.avatarUrl == null || req.avatarUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${req.username}',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFC9B8AA)
                        : const Color(0xFF776B62),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: dark ? kYellow : kBlack,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: dark ? kBlack : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (dark ? Colors.white : kCharcoal).withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Text(
                    'Ignore',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFC9B8AA)
                          : const Color(0xFF776B62),
                      fontSize: 11,
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kBlack : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.07),
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
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: dark ? kYellow : kBlack,
                        backgroundImage:
                            (member.avatarUrl != null &&
                                member.avatarUrl!.isNotEmpty)
                            ? NetworkImage(formatImageUrl(member.avatarUrl!))
                                  as ImageProvider
                            : null,
                        child:
                            (member.avatarUrl == null ||
                                member.avatarUrl!.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
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
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: kYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: dark ? kBlack : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: dark ? kCream : kCharcoal,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (dark ? kYellow : kBlack)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            member.role.name.toUpperCase(),
                                            style: TextStyle(
                                              color: dark ? kYellow : kBlack,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 10,
                                            color: dark ? kYellow : kBlack,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (dark ? kYellow : kBlack)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      member.role.name.toUpperCase(),
                                      style: TextStyle(
                                        color: dark ? kYellow : kBlack,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
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
                              style: TextStyle(
                                color: hasUnread
                                    ? (dark ? kCream : kCharcoal)
                                    : (dark
                                          ? const Color(0xFFC9B8AA)
                                          : const Color(0xFF776B62)),
                                fontSize: 11,
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
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: dark ? kBlack : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Remove from Circle',
                            style: TextStyle(
                              color: dark ? kCream : kCharcoal,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to remove $name from your circle? You will no longer share memories or chat with each other.',
                            style: TextStyle(
                              color: dark
                                  ? kCream.withValues(alpha: 0.8)
                                  : kCharcoal.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: dark
                                      ? kCream.withValues(alpha: 0.6)
                                      : kCharcoal.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  color: dark ? kYellow : kBlack,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (dark ? Colors.white : kCharcoal).withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: dark
                              ? const Color(0xFFC9B8AA)
                              : const Color(0xFF776B62),
                          fontSize: 11,
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
