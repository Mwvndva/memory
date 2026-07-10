import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/design_system/design_system.dart';

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
    } catch (e) {
      // Surfacing this matters: swallowing it leaves the user staring at an
      // empty conversation with no indication that loading failed.
      if (mounted) showAppError(context, 'Could not load messages: $e');
    }
    if (!mounted) return;
    setState(() => _loadingHistory = false);
    // scroll to bottom after loading
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    try {
      ref.read(chatProvider.notifier).exitConversation();
    } catch (e) {
      // The container can already be torn down during dispose; nothing to
      // surface to the user at this point, but don't lose the reason.
      debugPrint('[ChatInbox] exitConversation during dispose failed: $e');
    }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: MemorySpacing.md,
                  vertical: MemorySpacing.md,
                ),
                decoration: BoxDecoration(
                  color: MemoryColors.ink,
                  borderRadius: BorderRadius.circular(MemoryRadius.xl),
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
                    MemoryIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticLabel: 'Back',
                      color: Colors.white,
                      iconSize: 18,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: MemorySpacing.xs),
                    MemoryAvatar(
                      radius: 18,
                      dark: dark,
                      imageUrl:
                          contactMember.avatarUrl == null ||
                              contactMember.avatarUrl!.isEmpty
                          ? null
                          : formatImageUrl(contactMember.avatarUrl!),
                      initial: contactMember.firstName.isNotEmpty
                          ? contactMember.firstName
                          : contactMember.username,
                      background: MemoryColors.accent,
                    ),
                    const SizedBox(width: MemorySpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.contactName,
                            style: MemoryTypography.emptyTitle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: MemorySpacing.xxs),
                          Text(
                            isAccepted
                                ? 'Circle Member'
                                : (isPendingRequest
                                      ? 'Wants to share'
                                      : 'Not in Circle'),
                            style: MemoryTypography.sectionLabel.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
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
                          patternColor: (dark ? Colors.white : MemoryColors.ink)
                              .withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    if (_loadingHistory)
                      MemoryLoading.block(
                        color: dark ? MemoryColors.accent : MemoryColors.ink,
                      )
                    else if (messages.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'No messages yet',
                              style: MemoryTypography.heading.copyWith(
                                color: MemoryColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: MemorySpacing.sm),
                            Text(
                              'Say hello to start the conversation!',
                              textAlign: TextAlign.center,
                              style: MemoryTypography.body.copyWith(
                                color: MemoryColors.charcoal.withValues(
                                  alpha: 0.6,
                                ),
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
                            padding: const EdgeInsets.symmetric(
                              vertical: MemorySpacing.gutter,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, i) {
                              if (i == messages.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: MemorySpacing.xl,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 36),
                                        Text(
                                          '${widget.contactName} is typing...',
                                          style: MemoryTypography.caption
                                              .copyWith(
                                                color:
                                                    (dark
                                                            ? Colors.white
                                                            : MemoryColors
                                                                  .charcoal)
                                                        .withValues(alpha: 0.6),
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
        padding: const EdgeInsets.all(MemorySpacing.gutter),
        decoration: BoxDecoration(
          color: MemoryColors.ink,
          borderRadius: BorderRadius.circular(MemoryRadius.lg),
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
              style: MemoryTypography.bodyStrong.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: MemorySpacing.xs),
            Text(
              'Accept to start messaging and sharing memories.',
              textAlign: TextAlign.center,
              style: MemoryTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: MemorySpacing.xxl),
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
                        borderRadius: BorderRadius.circular(MemoryRadius.pill),
                      ),
                      child: Text(
                        'Ignore',
                        style: MemoryTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: MemorySpacing.xl),
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
                        color: MemoryColors.accent,
                        borderRadius: BorderRadius.circular(MemoryRadius.pill),
                      ),
                      child: Text(
                        'Accept',
                        style: MemoryTypography.button.copyWith(
                          color: MemoryColors.ink,
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
        padding: const EdgeInsets.all(MemorySpacing.gutter),
        decoration: BoxDecoration(
          color: MemoryColors.ink,
          borderRadius: BorderRadius.circular(MemoryRadius.lg),
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
              style: MemoryTypography.bodyStrong.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: MemorySpacing.xs),
            Text(
              'You can only message after a circle request is accepted.',
              textAlign: TextAlign.center,
              style: MemoryTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: MemorySpacing.xxl),
            GestureDetector(
              onTap: () {
                if (mounted) context.pop();
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(MemoryRadius.pill),
                ),
                child: Text(
                  'Back',
                  style: MemoryTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 52,
        padding: const EdgeInsets.only(
          left: MemorySpacing.sheet,
          right: MemorySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: MemoryColors.ink,
          borderRadius: BorderRadius.circular(MemoryRadius.pill),
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
                style: MemoryTypography.bodyStrong.copyWith(
                  color: Colors.white,
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
            const SizedBox(width: MemorySpacing.md),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MemorySpacing.sheet,
                  vertical: MemorySpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: MemoryColors.accent,
                  borderRadius: BorderRadius.circular(MemoryRadius.pill),
                ),
                child: Text(
                  'Send',
                  style: MemoryTypography.bodySmall.copyWith(
                    color: MemoryColors.ink,
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

  Widget _inboxBubble(Message msg, CircleMember member, bool dark) =>
      InboxBubble(
        msg: msg,
        member: member,
        dark: dark,
        contactName: widget.contactName,
      );

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
    color: dark ? MemoryColors.ink : MemoryColors.cream,
    gradient: LinearGradient(
      colors: dark
          ? const [MemoryColors.ink, MemoryColors.charcoal]
          : const [MemoryColors.accent, MemoryColors.accent],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
  );
}

// Painter moved to widgets/chat_widgets.dart
