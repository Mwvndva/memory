import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../feed/streak_milestones.dart';
import '../../models/user_profile.dart';
import '../../models/message.dart';
import '../../core/api_config.dart';
import '../../core/theme.dart';
import '../../core/error_handler.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/circles_repository.dart';
import '../../media/unified_media_widgets.dart';
import 'circle_state_manager.dart';
import 'profile_state_manager.dart';

class CircleChatListView extends ConsumerWidget {
  const CircleChatListView({super.key});

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfilePanel(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(isDarkProvider);
    final user = ref.watch(authProvider);
    final circleMembers = ref.watch(circleStateManagerProvider.select((s) => s.circles));
    final pendingRequests = ref.watch(circleStateManagerProvider.select((s) => s.pendingRequests));
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Container(
        padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 18 + MediaQuery.paddingOf(context).bottom),
        decoration: _softBackground(dark),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => context.go('/capture'),
                      color: dark ? kCream : kCharcoal,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Your circle',
                          style: TextStyle(
                            color: dark ? kCream : kCharcoal,
                            fontSize: 30,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (pendingRequests.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            'SHARE REQUESTS',
                            style: TextStyle(
                              color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...pendingRequests.map((req) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                // Open the chat/inbox for this requester (thread placeholder)
                                context.push('/chat/${req.username}');
                              },
                              child: _requestRow(context, req, dark, ref),
                            )),
                        const SizedBox(height: 18),
                      ],
                      if (circleMembers.isEmpty && pendingRequests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: dark ? kBlack : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: dark ? kYellow : kBlack,
                                  size: 28,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No one is in your circle yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: dark ? kCream : kCharcoal,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Open your profile to add someone and start sharing.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (circleMembers.isNotEmpty)
                          ...circleMembers.map((member) => _chatRow(context, member, dark, ref)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestRow(BuildContext context, CircleMember req, bool dark, WidgetRef ref) {
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
            backgroundImage: (req.avatarUrl != null && req.avatarUrl!.isNotEmpty)
                ? NetworkImage(_formatImageUrl(req.avatarUrl!)) as ImageProvider
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
                    color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
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
              GestureDetector(
                onTap: () async {
                  try {
                    await ref.read(circleStateManagerProvider.notifier).acceptRequest(req.id);
                  } catch (e) {
                    if (context.mounted) {
                      showAppError(context, e.toString());
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              GestureDetector(
                onTap: () async {
                  try {
                    await ref.read(circleStateManagerProvider.notifier).declineRequest(req.id);
                  } catch (e) {
                    if (context.mounted) {
                      showAppError(context, e.toString());
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    'Ignore',
                    style: TextStyle(
                      color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
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

  Widget _chatRow(BuildContext context, CircleMember member, bool dark, WidgetRef ref) {
    final name = member.firstName.isNotEmpty ? member.firstName : member.username;
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
                        backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_formatImageUrl(member.avatarUrl!)) as ImageProvider
                            : null,
                        child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
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
                          final hasUnread = (chatState.unreadCounts[chatKey] ?? 0) > 0;
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
                        Text(
                          name,
                          style: TextStyle(
                            color: dark ? kCream : kCharcoal,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final chatState = ref.watch(chatProvider);
                            final messages = chatState.messagesByContact[chatKey] ?? [];
                            final lastMessage = messages.isNotEmpty ? messages.last.text : 'No messages yet';
                            final hasUnread = (chatState.unreadCounts[chatKey] ?? 0) > 0;
                            return Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _small(
                                hasUnread
                                    ? (dark ? kCream : kCharcoal)
                                    : (dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
                              ).copyWith(
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w500,
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: dark ? kBlack : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: dark ? kCream.withValues(alpha: 0.6) : kCharcoal.withValues(alpha: 0.6),
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
                  await ref.read(circleStateManagerProvider.notifier).removeMember(member.id);
                } catch (e) {
                  if (context.mounted) {
                    showAppError(context, e.toString());
                  }
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.12)),
              ),
              child: Text(
                'Remove',
                style: TextStyle(
                  color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [kDarkCream, Color(0xFF171717)]
              : const [kYellow, kYellow],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      );

  TextStyle _small(Color color) => TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900);
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
        ref.read(chatProvider.notifier).sendTypingIndicator(widget.contactName, text.isNotEmpty);
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.pixels <= 50) {
        ref.read(chatProvider.notifier).loadConversation(widget.contactName, loadMore: true);
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
      await ref.read(chatProvider.notifier).loadConversation(widget.contactName, shouldMarkRead: true);
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
    final isPendingRequest = pending.any((p) => p.username.toLowerCase() == widget.contactName.toLowerCase() || p.id == widget.contactName);
    final isAccepted = circleMembers.any((m) => m.username.toLowerCase() == widget.contactName.toLowerCase() || m.id == widget.contactName);

    final contactMember = circleMembers.firstWhere(
      (m) => m.username.toLowerCase() == widget.contactName.toLowerCase() || m.id == widget.contactName,
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kYellow,
                      backgroundImage: (contactMember.avatarUrl != null && contactMember.avatarUrl!.isNotEmpty)
                          ? NetworkImage(_formatImageUrl(contactMember.avatarUrl!)) as ImageProvider
                          : null,
                      child: (contactMember.avatarUrl == null || contactMember.avatarUrl!.isEmpty)
                          ? Text(
                              contactMember.firstName.isNotEmpty ? contactMember.firstName[0].toUpperCase() : widget.contactName[0].toUpperCase(),
                              style: const TextStyle(color: kBlack, fontWeight: FontWeight.w900, fontSize: 13),
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
                                : (isPendingRequest ? 'Wants to share' : 'Not in Circle'),
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
                          patternColor: (dark ? Colors.white : kBlack).withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    if (_loadingHistory)
                      Center(
                        child: CircularProgressIndicator(color: dark ? kYellow : kBlack),
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
                      Builder(builder: (context) {
                        final isTyping = chatState.typingIndicators[widget.contactName] ?? false;
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
                                          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.6),
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
                      }),
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
                      final id = pending.firstWhere(
                        (p) => p.username == widget.contactName,
                        orElse: () => pending.firstWhere(
                          (p) => p.id == widget.contactName,
                          orElse: () => CircleMember(
                            id: widget.contactName,
                            username: widget.contactName,
                            firstName: widget.contactName,
                          ),
                        ),
                      ).id;
                      await ref.read(pendingRequestsProvider.notifier).declineRequest(id);
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
                      final success = await ref.read(pendingRequestsProvider.notifier).acceptRequest(
                        pending.firstWhere(
                          (p) => p.username == widget.contactName,
                          orElse: () => pending.firstWhere(
                            (p) => p.id == widget.contactName,
                            orElse: () => CircleMember(
                              id: widget.contactName,
                              username: widget.contactName,
                              firstName: widget.contactName,
                            ),
                          ),
                        ).id,
                      );
                      if (success) {
                        await ref.read(chatProvider.notifier).loadConversation(widget.contactName, shouldMarkRead: true);
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: dark ? kYellow : kBlack,
                backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                    ? NetworkImage(_formatImageUrl(member.avatarUrl!)) as ImageProvider
                    : null,
                child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                    ? Text(
                        member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : member.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
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
                            leading: const Icon(Icons.refresh_rounded, color: Colors.white),
                            title: const Text('Retry sending', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref.read(chatProvider.notifier).retryMessage(widget.contactName, msg.id);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            title: const Text('Delete message', style: TextStyle(color: Colors.redAccent)),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref.read(chatProvider.notifier).deleteMessageOptimistic(widget.contactName, msg.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
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
                  bottomLeft: mine ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: mine ? const Radius.circular(4) : const Radius.circular(20),
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
                          color: (mine
                              ? (dark ? kBlack : Colors.white)
                              : (dark ? kCream : kCharcoal)).withValues(alpha: 0.5),
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
                            child: CircularProgressIndicator(strokeWidth: 1.2, color: kYellow),
                          )
                        else
                          Icon(
                            msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 11,
                            color: dark ? kBlack.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
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
          colors: dark
              ? const [kDarkCream, kCharcoal]
              : const [kYellow, kYellow],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      );
}

class ProfilePanel extends ConsumerStatefulWidget {
  const ProfilePanel({super.key});

  @override
  ConsumerState<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends ConsumerState<ProfilePanel> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileStateManagerProvider.notifier).fetchProfile();
    });
  }

  void _showInviteOptions(BuildContext context, bool dark) {
    final circleMembers = ref.read(circlesProvider);
    final user = ref.read(authProvider);
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    final inviteLink = 'https://memory.app/invite/$displayUsername';

    final avatarUrl = user.avatarUrl;
    final avatarInitial = user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _actionSheet(
        dark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _funCard(
              title: 'Join my circle',
              value: '${circleMembers.length} / 30',
              label: 'memory.app/invite/$displayUsername',
              // Mixed pink + green gradient for invite
              colors: const [Color(0xFFF058A0), Color(0xFF7B61FF), Color(0xFF25D366)],
              icon: Icons.favorite_rounded,
              avatarUrl: avatarUrl,
              avatarInitial: avatarInitial,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: 'Join my circle on Memory! $inviteLink',
                        ),
                      );
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFF058A0).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('Instagram', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: 'Join my circle on Memory! $inviteLink',
                        ),
                      );
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _pill(
              'Copy invite link',
              () {
                Clipboard.setData(
                  ClipboardData(text: inviteLink),
                );
                Navigator.pop(context);
                showAppMessage(context, 'Invite link copied!');
              },
              dark,
              color: dark ? kCream : kCharcoal,
              foreground: dark ? kCharcoal : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  void _showShareCard(BuildContext context, String title, String value, String channel, List<Color> colors, bool dark) {
    final isInstagram = channel == 'Instagram';
    final channelIcon = isInstagram ? Icons.camera_alt_rounded : Icons.chat_bubble_rounded;
    final channelTagline = isInstagram ? 'Share to your story' : 'Share to status';

    final user = ref.read(authProvider);
    final avatarUrl = user.avatarUrl;
    final avatarInitial = user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?';
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    String flag = 'KE';
    if (user.phone.isNotEmpty) {
      final runes = user.phone.runes.toList();
      if (runes.length >= 2 && runes[0] >= 127462 && runes[0] <= 127487) {
        flag = String.fromCharCodes(runes.take(2));
      }
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _actionSheet(
        dark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _funCard(
              title: title,
              value: value,
              label: 'Memory is alive',
              colors: const [kYellow, kYellow],
              icon: channelIcon,
              avatarUrl: avatarUrl,
              avatarBytes: user.avatarBytes,
              avatarInitial: avatarInitial,
              username: displayUsername,
              ringColor: isInstagram ? const Color(0xFFE1306C) : const Color(0xFF25D366),
              countryFlag: flag,
              countryRank: user.countryRank,
              globalRank: user.globalRank,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'My Memory stats for $title: $value\n\nJoin Memory - keep your circle alive! memory.app',
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: kYellow.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(channelIcon, color: kBlack, size: 18),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send to $channel',
                          style: const TextStyle(color: kBlack, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1),
                        ),
                        Text(
                          channelTagline,
                          style: TextStyle(color: kBlack.withValues(alpha: 0.62), fontSize: 10, fontWeight: FontWeight.w600, height: 1.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 14),
          child: Text(
            title,
            style: TextStyle(
              color: kCream.withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: kBlack,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, bool isLast, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.8,
                ),
              ),
            ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: kCream.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: kCream,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyRow(String title, VoidCallback onTap, bool isLast, bool dark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.8,
                  ),
                ),
              ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: kCream,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: kCream.withValues(alpha: 0.68),
              size: 11,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final user = ref.watch(profileStateManagerProvider.select((s) => s.user));
    final circleMembers = ref.watch(circlesProvider);

    ref.listen<UserProfile>(authProvider, (previous, next) {
      if (next.isAuthenticated && context.mounted) {
        checkMilestones(context, ref, next.streakDays);
      }
    });

    final displayFirstName = user.firstName.isNotEmpty ? user.firstName : '';
    final displayLastName = user.lastName.isNotEmpty ? user.lastName : '';
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    final displayEmail = user.email.isNotEmpty ? user.email : '';
    final displayPhone = user.phone.isNotEmpty ? user.phone : '';

    String flag = '🇰🇪';
    if (user.phone.isNotEmpty) {
      final runes = user.phone.runes.toList();
      if (runes.length >= 2 && runes[0] >= 127462 && runes[0] <= 127487) {
        flag = String.fromCharCodes(runes.take(2));
      }
    }

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Text(
                      flag,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${user.countryRank}',
                      style: TextStyle(
                        color: dark ? kCream : kCharcoal,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user.globalRank != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.public_rounded,
                        color: dark ? kCream : kCharcoal,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '#${user.globalRank}',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: kBlack,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: dark ? 0.16 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final file = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 82,
                            );
                            if (file == null) return;
                            final bytes = await file.readAsBytes();
                            await ref.read(profileStateManagerProvider.notifier).updateAvatar(bytes);
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dark ? kYellow : kBlack,
                                ),
                                child: CircleAvatar(
                                  radius: 34,
                                  backgroundColor: dark ? kBlack : Colors.white,
                                  backgroundImage: user.avatarBytes != null
                                      ? MemoryImage(user.avatarBytes!)
                                      : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                          ? NetworkImage(_formatImageUrl(user.avatarUrl!)) as ImageProvider
                                          : null),
                                  child: (user.avatarBytes == null && (user.avatarUrl == null || user.avatarUrl!.isEmpty))
                                      ? Text(
                                          displayFirstName.isNotEmpty ? displayFirstName[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: kYellow,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                      color: kBlack,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dark ? kYellow : kBlack,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: dark ? kYellow : kBlack,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$displayFirstName $displayLastName',
                          style: TextStyle(
                            color: kCream,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$displayUsername',
                          style: TextStyle(
                            color: kCream.withValues(alpha: 0.66),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tap your photo to update it',
                            style: TextStyle(
                              color: kCream.withValues(alpha: 0.66),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                _statCards(context, dark),
                const SizedBox(height: 12),
                _sectionCard(
                  'CONTACT',
                  [
                    _detailRow('Email', displayEmail, false, dark),
                    _detailRow('Phone', displayPhone, true, dark),
                  ],
                  dark,
                ),
                const SizedBox(height: 12),
                _addPersonCard(context, circleMembers.length, dark),
                const SizedBox(height: 12),
                _sectionCard(
                  'LEGAL & SUPPORT',
                  [
                    _policyRow(
                      'Privacy Policy',
                      () => _showPolicyDialog(
                        context,
                        'Privacy Policy',
                        'Your privacy matters to us. Memory App is built to share moments only with your chosen circle. We do not sell or share your data with advertisers. All uploaded memories are encrypted and visible only to the members of your active circle. You can delete your memories or close your account at any time.',
                        dark,
                      ),
                      false,
                      dark,
                    ),
                    _policyRow(
                      'Terms & Conditions',
                      () => _showFullTermsSheet(context, dark),
                      true,
                      dark,
                    ),
                  ],
                  dark,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      ref.read(sessionProvider.notifier).logout();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 4),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  

  Widget _statCards(BuildContext context, bool dark) {
    final user = ref.watch(authProvider);

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            'Memories',
            '${user.streakDays} days',
            const [kYellow, kAmber],
            dark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            'Circle Pulse',
            '${user.circlePulseDays} days',
            const [kMint, kSky],
            dark,
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String title, String value, List<Color> colors, bool dark) {
    final isStreak = title == 'Memories';
    final subtitle = isStreak ? 'Day streak' : 'Circle active';
    final accent = colors.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kBlack : Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shareIcon(isStreak ? Icons.camera_alt_rounded : Icons.chat_bubble_rounded, accent),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _sharePill(
                  _InstagramMark(color: Colors.white),
                  const Color(0xFFE1306C),
                  () => _showShareCard(context, title, value, 'Instagram', colors, dark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _sharePill(
                  _WhatsAppMark(color: Colors.white),
                  const Color(0xFF25D366),
                  () => _showShareCard(context, title, value, 'WhatsApp', colors, dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sharePill(Widget logo, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox(width: 17, height: 17, child: logo),
      ),
    );
  }

  Widget _shareIcon(IconData icon, Color accent) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accent, size: 16),
    );
  }
  Widget _actionSheet(bool dark, {required Widget child}) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06)),
        ),
        child: child,
      ),
    );
  }

  Widget _funCard({
    required String title,
    required String value,
    required String label,
    required List<Color> colors,
    required IconData icon,
    String? avatarUrl,
    Uint8List? avatarBytes,
    String avatarInitial = '?',
    String username = 'user',
    Color ringColor = kBlack,
    String countryFlag = 'KE',
    int countryRank = 1,
    int? globalRank,
  }) {
    final resolvedAvatar = avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null;

    return Container(
      width: double.infinity,
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
                color: kBlack,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kYellow, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: kYellow.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 4),
                    ),
                    child: ClipOval(
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : resolvedAvatar != null
                              ? UnifiedImageWidget(
                                  imageUrl: resolvedAvatar,
                                  fit: BoxFit.cover,
                                  fallbackWidget: Center(
                                    child: Text(
                                      avatarInitial,
                                      style: const TextStyle(color: kCream, fontSize: 28, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: kYellow,
                                  alignment: Alignment.center,
                                  child: Text(
                                    avatarInitial,
                                    style: const TextStyle(color: kBlack, fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kCream,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$value $title',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kCream.withValues(alpha: 0.76),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _rankChip('$countryFlag #$countryRank'),
                      if (globalRank != null) _rankChip('Global #$globalRank'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kYellow,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
  Widget _addPersonCard(BuildContext context, int circleCount, bool dark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? kBlack : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.12 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$circleCount / 30',
                  style: TextStyle(
                    color: kCream,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'in your circle',
                  style: TextStyle(
                    color: kCream.withValues(alpha: 0.68),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 124,
              child: _pill(
                'Add someone',
                circleCount < 30 ? () => _showInviteOptions(context, dark) : () {},
                dark,
                compact: true,
                color: Colors.white,
                foreground: kBlack,
              ),
            ),
          ],
        ),
      );

  Widget _pill(
    String text,
    VoidCallback onTap,
    bool dark, {
    Color? color,
    Color? foreground,
    bool compact = false,
    double? width,
  }) =>
      GestureDetector(
        onTap: onTap,
      child: Container(
          width: width ?? double.infinity,
          height: compact ? 34 : 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? (dark ? kDarkCream : kCream),
            borderRadius: BorderRadius.circular(999),
            border: color == null
                ? Border.all(color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06))
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: foreground ?? (dark ? kCream : kCharcoal),
              fontSize: compact ? 10 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

  void _showFullTermsSheet(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.88,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: dark ? kBlack : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Terms & Conditions', style: TextStyle(color: dark ? kCream : kCharcoal, fontSize: 20, fontWeight: FontWeight.w900)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: (dark ? kCream : kCharcoal).withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: dark ? kCream : kCharcoal, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Updated: June 2026', style: TextStyle(color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      _termsItem('1. Welcome to Memory', 'Memory ("we", "us", or "our") provides a private daily social sharing platform for intimate circles. By creating an account or using the Memory app, you agree to comply with and be bound by these Terms & Conditions and all applicable laws of the Republic of Kenya.', dark),
                      _termsItem('2. Privacy & Consent (Kenya Data Protection Act, 2019)', 'Your privacy is critical to us. By registering an account, you explicitly consent to the collection, storage, and processing of your personal data—including your name, email, phone number, and uploaded media files (memories). All personal data is processed in strict compliance with the Kenya Data Protection Act, 2019 and registration guidelines set by the Office of the Data Protection Commissioner (ODPC). We do not sell or share your personal data with third-party advertising companies.', dark),
                      _termsItem('3. User-Generated Content & Liabilities (Cybercrimes Act, 2018)', 'You are solely responsible for the video memories and captions you post to your circle. Under the Computer Misuse and Cybercrimes Act, 2018 of Kenya, it is a criminal offense to upload or share content that is pornographic, hateful, harassing, defamatory, or infringes on another person\'s copyright. We reserve the right to suspend or delete your account immediately and report violations to relevant authorities if illegal or prohibited content is detected.', dark),
                      _termsItem('4. Account Security', 'You are responsible for safeguarding your password and account details. You agree to notify us immediately of any unauthorized use or security breach of your account.', dark),
                      _termsItem('5. Limitation of Liability', 'The Memory app is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, or punitive damages arising from your use of the app, service disruptions, or unauthorized access to user data.', dark),
                      _termsItem('6. Dispute Resolution & Governing Law', 'These terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes, claims, or controversies arising out of or relating to these terms shall be subject to the exclusive jurisdiction of the competent courts in Nairobi, Kenya.', dark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: dark ? kYellow : kBlack, borderRadius: BorderRadius.circular(999)),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _termsItem(String heading, String body, bool dark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: TextStyle(color: dark ? kYellow : kBlack, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8), fontSize: 12.5, height: 1.45)),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content, bool dark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? kBlack : kYellow,
        title: Text(
          title,
          style: TextStyle(
            color: dark ? kCream : kCharcoal,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(
              color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: dark ? kYellow : kBlack, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

String _formatImageUrl(String url) {
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    return uri.replace(host: baseUri.host, port: baseUri.port).toString();
  }
  return url;
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

class _InstagramMark extends StatelessWidget {
  const _InstagramMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _InstagramMarkPainter(color));
}

class _InstagramMarkPainter extends CustomPainter {
  const _InstagramMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(size.width * 0.12), Radius.circular(size.width * 0.26)),
      stroke,
    );
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.18, stroke);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.28), size.width * 0.045, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _InstagramMarkPainter oldDelegate) => oldDelegate.color != color;
}

class _WhatsAppMark extends StatelessWidget {
  const _WhatsAppMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WhatsAppMarkPainter(color));
}

class _WhatsAppMarkPainter extends CustomPainter {
  const _WhatsAppMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width * 0.5, size.height * 0.45);
    canvas.drawCircle(center, size.width * 0.35, stroke);
    final tail = Path()
      ..moveTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(size.width * 0.18, size.height * 0.88)
      ..lineTo(size.width * 0.40, size.height * 0.76)
      ..close();
    canvas.drawPath(tail, fill);
    final phone = Path()
      ..moveTo(size.width * 0.38, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.62, size.width * 0.67, size.height * 0.56);
    canvas.drawPath(phone, stroke);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppMarkPainter oldDelegate) => oldDelegate.color != color;
}

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

