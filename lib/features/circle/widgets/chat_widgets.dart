import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/design_system/design_system.dart';

class InboxBubble extends ConsumerWidget {
  final Message msg;
  final CircleMember member;
  final bool dark;
  final String contactName;

  const InboxBubble({
    super.key,
    required this.msg,
    required this.member,
    required this.dark,
    required this.contactName,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = msg.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine) ...[
              MemoryAvatar(
                radius: 14,
                dark: dark,
                imageUrl: member.avatarUrl == null || member.avatarUrl!.isEmpty
                    ? null
                    : formatImageUrl(member.avatarUrl!),
                initial: member.firstName.isNotEmpty
                    ? member.firstName
                    : member.username,
              ),
              const SizedBox(width: MemorySpacing.md),
            ],
            if (mine && msg.isFailed)
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: kCharcoal,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Retry sending',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref
                                  .read(chatProvider.notifier)
                                  .retryMessage(contactName, msg.id);
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            title: const Text(
                              'Delete message',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref
                                  .read(chatProvider.notifier)
                                  .deleteMessageOptimistic(contactName, msg.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              constraints: const BoxConstraints(maxWidth: 240),
              decoration: BoxDecoration(
                gradient: mine
                    ? LinearGradient(
                        colors: dark
                            ? const [kYellow, Color(0xFFFFD54F)]
                            : const [kBlack, Color(0xFF2C2C2C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: dark
                            ? const [kBlack, Color(0xFF1E1E1E)]
                            : const [Colors.white, kCream],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: mine
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: mine
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: mine
                          ? (dark ? kBlack : Colors.white)
                          : (dark ? kCream : kCharcoal),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          color:
                              (mine
                                      ? (dark ? kBlack : Colors.white)
                                      : (dark ? kCream : kCharcoal))
                                  .withValues(alpha: 0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        if (msg.isPending)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: kYellow,
                            ),
                          )
                        else
                          Icon(
                            msg.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 11,
                            color: dark
                                ? kBlack.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPatternPainter extends CustomPainter {
  final Color patternColor;
  ChatPatternPainter({required this.patternColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = patternColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double spacing = 40.0;

    // Diagonal lines top-left to bottom-right
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    // Diagonal lines top-right to bottom-left
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        paint,
      );
    }

    // Small intersection dots
    final dotPaint = Paint()
      ..color = patternColor.withValues(alpha: patternColor.a * 1.5)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatPatternPainter oldDelegate) {
    return oldDelegate.patternColor != patternColor;
  }
}
