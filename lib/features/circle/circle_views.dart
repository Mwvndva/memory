import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../feed/streak_milestones.dart';
import '../../models/user_profile.dart';
import '../../core/api_config.dart';
import '../../core/theme.dart';
import '../../core/error_handler.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/circles_repository.dart';

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
    final circleMembers = ref.watch(circlesProvider);

    return Scaffold(
      body: Container(
        padding: EdgeInsets.fromLTRB(
          22,
          74,
          22,
          94 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: _softBackground(dark),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Chats',
                            style: TextStyle(
                              color: dark ? kYellow : kBlack,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Your circle',
                            style: TextStyle(
                              color: dark ? kCream : kCharcoal,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showProfileSheet(context),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: dark ? kYellow : kBlack,
                        backgroundImage: user.avatarBytes != null
                            ? MemoryImage(user.avatarBytes!)
                            : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? NetworkImage(_formatImageUrl(user.avatarUrl!)) as ImageProvider
                                : null),
                        child: (user.avatarBytes == null && (user.avatarUrl == null || user.avatarUrl!.isEmpty))
                            ? Text(
                                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'R',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (ref.watch(pendingRequestsProvider).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
                          child: Text(
                            'SHARE REQUESTS',
                            style: TextStyle(
                              color: dark ? kYellow : kBlack,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        ...ref.watch(pendingRequestsProvider).map((req) => _requestRow(context, req, dark, ref)),
                        const SizedBox(height: 18),
                      ],
                      if (circleMembers.isEmpty && ref.watch(pendingRequestsProvider).isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              'No members in your circle yet.\nTap your profile to add someone!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: dark ? kCream.withValues(alpha: 0.6) : kCharcoal.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? kBlack : kYellow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kBlack.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '@${req.username}',
                  style: TextStyle(
                    color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => ref.read(pendingRequestsProvider.notifier).acceptRequest(req.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                                colors: [dark ? kYellow : kBlack, kAmber],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: kBlack.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => ref.read(pendingRequestsProvider.notifier).declineRequest(req.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ignore',
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
        ],
      ),
    );
  }

  Widget _chatRow(BuildContext context, CircleMember member, bool dark, WidgetRef ref) {
    final name = member.firstName.isNotEmpty ? member.firstName : member.username;
    // Use username (not display name) as the key so WebSocket routing works
    final chatKey = member.username;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? kBlack : kYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(chatProvider.notifier).decrementNotifications();
                context.push('/chat/$chatKey');
              },
              child: Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: dark ? kCream : kCharcoal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Sent a memory',
                          style: _small(
                            dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: dark ? kBlack : kYellow,
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
                await ref.read(circlesProvider.notifier).removeMember(member.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
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
        color: dark ? kDarkCream : kCream,
        gradient: LinearGradient(
          colors: dark
              ? const [kDarkCream, kCharcoal]
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
  }

  Future<void> _loadHistory() async {
    if (kUseMockBackend) return;
    setState(() => _loadingHistory = true);
    try {
      await ref.read(chatProvider.notifier).loadConversation(widget.contactName);
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: _softBackground(dark),
        child: Column(
          children: [
            // Black header with Back, avatar and username
            Container(
              width: double.infinity,
              color: kBlack,
              padding: EdgeInsets.fromLTRB(12, 24, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  // avatar lookup from circles provider
                  Builder(builder: (ctx) {
                    final members = ref.watch(circlesProvider);
                    final match = members.firstWhere(
                      (m) => m.username == widget.contactName,
                      orElse: () => CircleMember(
                        id: widget.contactName,
                        username: widget.contactName,
                        firstName: widget.contactName,
                      ),
                    );
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: kYellow,
                      backgroundImage: (match.avatarUrl != null && match.avatarUrl!.isNotEmpty)
                          ? NetworkImage(_formatImageUrl(match.avatarUrl!)) as ImageProvider
                          : null,
                      child: (match.avatarUrl == null || match.avatarUrl!.isEmpty)
                          ? Text(
                              match.firstName.isNotEmpty ? match.firstName[0].toUpperCase() : widget.contactName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                            )
                          : null,
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.contactName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_loadingHistory)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator(color: dark ? kYellow : kBlack)),
              )
            else
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background logo centered at 30% opacity, half the inbox
                    Center(
                      child: Opacity(
                        opacity: 0.3,
                        child: Image.asset(
                          'assets/images/memory-logo.png',
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: MediaQuery.of(context).size.width * 0.5,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    return _inboxBubble(msg.sender, msg.text, msg.isMine, dark);
                  },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: dark ? kBlack : kBlack,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.contactName}',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 56,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inboxBubble(String from, String text, bool mine, bool dark) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: mine ? (dark ? kYellow : kBlack) : (dark ? kBlack : kYellow),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: mine ? Colors.white : (dark ? kCream : kCharcoal),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ...existing code...


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
      ref.read(authProvider.notifier).fetchProfile();
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
    final channelGradient = isInstagram
        ? const [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)]
        : const [Color(0xFF25D366), Color(0xFF128C7E)];
    final channelIcon = isInstagram ? Icons.camera_alt_rounded : Icons.chat_bubble_rounded;
    final channelTagline = isInstagram ? 'Share to your story ✨' : 'Send to a chat 💬';

    // Platform-specific card colors
    final cardColors = isInstagram
  ? const [Color(0xFFE1306C), Color(0xFFF77737), Color(0xFFFADA5E)]
        : const [Color(0xFF25D366), Color(0xFF128C7E), Color(0xFF075E54)];

    final user = ref.read(authProvider);
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
            // Rich share card preview with platform colors
            _funCard(
              title: title,
              value: value,
              label: 'Memory is alive',
              colors: cardColors,
              icon: channelIcon,
              avatarUrl: avatarUrl,
              avatarInitial: avatarInitial,
            ),
            const SizedBox(height: 14),
            // Platform-branded send button
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'My Memory stats for $title: $value 🔥\n\nJoin Memory — keep your circle alive! memory.app',
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: channelGradient),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: channelGradient.first.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(channelIcon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send to $channel',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1),
                        ),
                        Text(
                          channelTagline,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2),
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
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: kBlack,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? kDarkCream : kCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.05),
              width: 1,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
            ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 13,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
              ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final user = ref.watch(authProvider);
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
      height: MediaQuery.sizeOf(context).height * 0.82,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: dark ? kBlack : kYellow,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dark ? kDarkCream : kCream,
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
                        fontSize: 11,
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
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Hero Card with subtle gradient and borders
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? null : Colors.white,
                      gradient: dark
                          ? LinearGradient(
                              colors: [
                                (kYellow).withValues(alpha: 0.12),
                                kAmber.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (dark ? kYellow : kBlack).withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
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
                            await ref.read(authProvider.notifier).updateAvatar(bytes);
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [dark ? kYellow : kBlack, kAmber],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: dark ? kBlack : kYellow,
                                  backgroundImage: user.avatarBytes != null
                                      ? MemoryImage(user.avatarBytes!)
                                      : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                          ? NetworkImage(_formatImageUrl(user.avatarUrl!)) as ImageProvider
                                          : null),
                                  child: (user.avatarBytes == null && (user.avatarUrl == null || user.avatarUrl!.isEmpty))
                                      ? Text(
                                          displayFirstName.isNotEmpty ? displayFirstName[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: dark ? kYellow : kBlack,
                                            fontSize: 28,
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
                                    color: dark ? kYellow : kBlack,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dark ? kBlack : kYellow,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: dark ? kBlack : kYellow,
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
                            color: dark ? kCream : kCharcoal,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$displayUsername',
                          style: TextStyle(
                            color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                        ),
                      ),
                      const SizedBox(height: 16),
                  // Stats Cards
                  _statCards(context, dark),
                  const SizedBox(height: 12),
                  // Details Section Cards
                  _sectionCard(
                    'CONTACT',
                    [
                      _detailRow('Email', displayEmail, false, dark),
                      _detailRow('Phone', displayPhone, true, dark),
                    ],
                    dark,
                  ),
                  const SizedBox(height: 12),
                  // Circle Card
                  _addPersonCard(context, circleMembers.length, dark),
                  const SizedBox(height: 12),
                  // Legal Section
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
                  const SizedBox(height: 24),
                  // Danger Zone Logout Button with red-bordered styling
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(() {
                        ref.read(authProvider.notifier).logout();
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kBlack.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kBlack.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: kBlack, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: TextStyle(
                              color: kBlack,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bottom safe area so logout button is above nav bar
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
    final emoji = isStreak ? '🔥' : '💫';
    final subtitle = isStreak ? 'Day streak' : 'Circle active';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _sharePill(
                  '📸 Instagram',
                  const Color(0xFFE1306C),
                  () => _showShareCard(context, title, value, 'Instagram', colors, dark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _sharePill(
                  '💬 WhatsApp',
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

  Widget _sharePill(String text, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
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
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _actionSheet(bool dark, {required Widget child}) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: dark ? kBlack : kYellow,
          borderRadius: BorderRadius.circular(26),
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
    String avatarInitial = '?',
  }) {
    final resolvedAvatar = avatarUrl != null && avatarUrl.isNotEmpty
        ? avatarUrl
        : null;

    return Container(
      width: double.infinity,
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background circles for depth
          Positioned(
            right: -36,
            top: -36,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Sparkle dots
          const Positioned(right: 22, top: 55, child: Text('✦', style: TextStyle(color: Colors.white54, fontSize: 10))),
          const Positioned(right: 55, top: 28, child: Text('✦', style: TextStyle(color: Colors.white38, fontSize: 6))),
          const Positioned(left: 120, top: 18, child: Text('✦', style: TextStyle(color: Colors.white38, fontSize: 7))),
          // Content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const Spacer(),
                    // User avatar (top-right)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      child: ClipOval(
                        child: resolvedAvatar != null
                            ? Image.network(
                                resolvedAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Center(
                                  child: Text(
                                    avatarInitial,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  avatarInitial,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPersonCard(BuildContext context, int circleCount, bool dark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? kDarkCream : kCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$circleCount / 30',
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'in your circle',
                  style: TextStyle(
                    color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 120,
              child: _pill(
                'Add someone',
                circleCount < 30 ? () => _showInviteOptions(context, dark) : () {},
                dark,
                compact: true,
                color: dark ? kYellow : kBlack,
                foreground: Colors.white,
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
