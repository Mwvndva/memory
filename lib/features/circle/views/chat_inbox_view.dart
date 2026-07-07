import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/theme.dart';

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class ChatInboxView extends ConsumerStatefulWidget {
  const ChatInboxView({super.key, required this.contactName});

  final String contactName;

  @override
  ConsumerState<ChatInboxView> createState() => _ChatInboxViewState();
}

class _ChatInboxViewState extends ConsumerState<ChatInboxView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _messageController.addListener(() {
      if (mounted) {
        final text = _messageController.text.trim();
        ref
            .read(chatProvider.notifier)
            .sendTypingIndicator(widget.contactName, text.isNotEmpty);
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels <= 50) {
        ref
            .read(chatProvider.notifier)
            .loadConversation(widget.contactName, loadMore: true);
      }
    });
    Future.microtask(() {
      if (mounted) {
        ref.read(chatProvider.notifier).enterConversation(widget.contactName);
        ref.read(chatProvider.notifier).sendReadReceipt(widget.contactName);
      }
    });
  }

  Future<void> _loadHistory() async {
    if (kUseMockBackend) return;
    setState(() => _loadingHistory = true);
    try {
      await ref
          .read(chatProvider.notifier)
          .loadConversation(widget.contactName, shouldMarkRead: true);
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
    // scroll to bottom after loading
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    try {
      ref.read(chatProvider.notifier).exitConversation();
    } catch (_) {}
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(widget.contactName, text);
    _messageController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messagesByContact[widget.contactName] ?? [];
    final pending = ref.watch(pendingRequestsProvider);
    final circleMembers = ref.watch(circlesProvider);
    final isPendingRequest = pending.any(
      (p) =>
          p.username.toLowerCase() == widget.contactName.toLowerCase() ||
          p.id == widget.contactName,
    );
    final isAccepted = circleMembers.any(
      (m) =>
          m.username.toLowerCase() == widget.contactName.toLowerCase() ||
          m.id == widget.contactName,
    );

    final contactMember = circleMembers.firstWhere(
      (m) =>
          m.username.toLowerCase() == widget.contactName.toLowerCase() ||
          m.id == widget.contactName,
      orElse: () => CircleMember(
        id: widget.contactName,
        username: widget.contactName,
        firstName: widget.contactName,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: _softBackground(dark),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: kBlack,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kYellow,
                      backgroundImage:
                          (contactMember.avatarUrl != null &&
                              contactMember.avatarUrl!.isNotEmpty)
                          ? NetworkImage(
                                  formatImageUrl(contactMember.avatarUrl!),
                                )
                                as ImageProvider
                          : null,
                      child:
                          (contactMember.avatarUrl == null ||
                              contactMember.avatarUrl!.isEmpty)
                          ? Text(
                              contactMember.firstName.isNotEmpty
                                  ? contactMember.firstName[0].toUpperCase()
                                  : widget.contactName[0].toUpperCase(),
                              style: const TextStyle(
                                color: kBlack,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.contactName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAccepted
                                ? 'Circle Member'
                                : (isPendingRequest
                                      ? 'Wants to share'
                                      : 'Not in Circle'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ChatPatternPainter(
                          patternColor: (dark ? Colors.white : kBlack)
                              .withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    if (_loadingHistory)
                      Center(
                        child: CircularProgressIndicator(
                          color: dark ? kYellow : kBlack,
                        ),
                      )
                    else if (messages.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                color: kCharcoal,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Say hello to start the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kCharcoal.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final isTyping =
                              chatState.typingIndicators[widget.contactName] ??
                              false;
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: messages.length + (isTyping ? 1 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, i) {
                              if (i == messages.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 36),
                                        Text(
                                          '${widget.contactName} is typing...',
                                          style: TextStyle(
                                            color:
                                                (dark
                                                        ? Colors.white
                                                        : kCharcoal)
                                                    .withValues(alpha: 0.6),
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final msg = messages[i];
                              return _inboxBubble(msg, contactMember, dark);
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _buildComposerOrBanner(
                isPendingRequest,
                isAccepted,
                pending,
                dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerOrBanner(
    bool isPendingRequest,
    bool isAccepted,
    List<CircleMember> pending,
    bool dark,
  ) {
    if (isPendingRequest) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.contactName} wants to share memories',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Accept to start messaging and sharing memories.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final id = pending
                          .firstWhere(
                            (p) => p.username == widget.contactName,
                            orElse: () => pending.firstWhere(
                              (p) => p.id == widget.contactName,
                              orElse: () => CircleMember(
                                id: widget.contactName,
                                username: widget.contactName,
                                firstName: widget.contactName,
                              ),
                            ),
                          )
                          .id;
                      await ref
                          .read(pendingRequestsProvider.notifier)
                          .declineRequest(id);
                      if (!mounted) return;
                      context.pop();
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ignore',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final success = await ref
                          .read(pendingRequestsProvider.notifier)
                          .acceptRequest(
                            pending
                                .firstWhere(
                                  (p) => p.username == widget.contactName,
                                  orElse: () => pending.firstWhere(
                                    (p) => p.id == widget.contactName,
                                    orElse: () => CircleMember(
                                      id: widget.contactName,
                                      username: widget.contactName,
                                      firstName: widget.contactName,
                                    ),
                                  ),
                                )
                                .id,
                          );
                      if (success) {
                        await ref
                            .read(chatProvider.notifier)
                            .loadConversation(
                              widget.contactName,
                              shouldMarkRead: true,
                            );
                      }
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: kBlack,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (!isAccepted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.contactName} is not in your circle',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can only message after a circle request is accepted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                if (mounted) context.pop();
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 52,
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.contactName}',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(
                    color: kBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _inboxBubble(Message msg, CircleMember member, bool dark) {
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
              CircleAvatar(
                radius: 14,
                backgroundColor: dark ? kYellow : kBlack,
                backgroundImage:
                    (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                    ? NetworkImage(formatImageUrl(member.avatarUrl!))
                          as ImageProvider
                    : null,
                child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                    ? Text(
                        member.firstName.isNotEmpty
                            ? member.firstName[0].toUpperCase()
                            : member.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
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
                                  .retryMessage(widget.contactName, msg.id);
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
                                  .deleteMessageOptimistic(
                                    widget.contactName,
                                    msg.id,
                                  );
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

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
    color: dark ? kDarkCream : kCream,
    gradient: LinearGradient(
      colors: dark ? const [kDarkCream, kCharcoal] : const [kYellow, kYellow],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
  );
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
