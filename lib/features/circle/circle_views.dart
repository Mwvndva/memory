import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_config.dart';
import '../../core/theme.dart';
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
                              color: kCoralDark,
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
                        backgroundColor: kCoral,
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
                if (circleMembers.isEmpty)
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
                else
                  ...circleMembers.map((member) => _chatRow(context, member, dark, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatRow(BuildContext context, CircleMember member, bool dark, WidgetRef ref) {
    final name = member.firstName.isNotEmpty ? member.firstName : member.username;
    // Use username (not display name) as the key so WebSocket routing works
    final chatKey = member.username;
    return GestureDetector(
      onTap: () {
        ref.read(chatProvider.notifier).decrementNotifications();
        context.push('/chat/$chatKey');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? kDarkPaper : kPaper,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: kCoral,
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
            const Text(
              '8m',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: kCoralDark,
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
              : const [Color(0xFFFFF4E4), Color(0xFFEFFFF8)],
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
          64,
          22,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: _softBackground(dark),
        child: Column(
          children: [
            Row(
              children: [
                _smallClose(() => context.pop(), dark),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: kCoral,
                  child: Text(widget.contactName[0]),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.contactName,
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator(color: kCoral)),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    return _inboxBubble(msg.sender, msg.text, msg.isMine, dark);
                  },
                ),
              ),
            const SizedBox(height: 10),
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: dark ? kDarkPaper : kPaper,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: dark ? kCream : kCharcoal,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.contactName}',
                        hintStyle: TextStyle(
                          color: dark ? kCream.withValues(alpha: 0.5) : kCharcoal.withValues(alpha: 0.5),
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
                        color: kCoral,
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
          color: mine ? kCoral : (dark ? kDarkPaper : kPaper),
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

  Widget _smallClose(VoidCallback onTap, bool dark) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dark ? kDarkCream : kCream,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            color: dark ? kCream : kCharcoal,
            size: 18,
          ),
        ),
      );

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
        color: dark ? kDarkCream : kCream,
        gradient: LinearGradient(
          colors: dark
              ? const [kDarkCream, kCharcoal]
              : const [Color(0xFFFFF4E4), Color(0xFFEFFFF8)],
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

    showModalBottomSheet(
      context: context,
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
              colors: const [kCoral, kAmber],
              icon: Icons.favorite_rounded,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _pill(
                    'Instagram',
                    () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: 'Join my circle on Memory! $inviteLink',
                        ),
                      );
                    },
                    dark,
                    compact: true,
                    color: const Color(0xFFE1306C),
                    foreground: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pill(
                    'WhatsApp',
                    () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: 'Join my circle on Memory! $inviteLink',
                        ),
                      );
                    },
                    dark,
                    compact: true,
                    color: const Color(0xFF25D366),
                    foreground: Colors.white,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link copied!')),
                );
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
    showModalBottomSheet(
      context: context,
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
              colors: colors,
              icon: channel == 'Instagram' ? Icons.camera_alt_rounded : Icons.chat_bubble_rounded,
            ),
            const SizedBox(height: 14),
            _pill(
              'Send to $channel',
              () async {
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'My Memory stats for $title: $value. Memory is alive!',
                  ),
                );
              },
              dark,
              color: kCoral,
              foreground: Colors.white,
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
              color: kCoralDark,
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
        color: dark ? kDarkPaper : kPaper,
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
                      gradient: LinearGradient(
                        colors: [
                          kCoral.withValues(alpha: 0.12),
                          kAmber.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: kCoral.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
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
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [kCoral, kAmber],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: dark ? kDarkPaper : kPaper,
                                  backgroundImage: user.avatarBytes != null
                                      ? MemoryImage(user.avatarBytes!)
                                      : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                          ? NetworkImage(_formatImageUrl(user.avatarUrl!)) as ImageProvider
                                          : null),
                                  child: (user.avatarBytes == null && (user.avatarUrl == null || user.avatarUrl!.isEmpty))
                                      ? Text(
                                          displayFirstName.isNotEmpty ? displayFirstName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: kCoral,
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
                                    color: kCoral,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dark ? kDarkPaper : kPaper,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
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
                  // Theme Selector Grouped
                  _themePicker(ref, dark),
                  const SizedBox(height: 12),
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
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.pop(context);
                        context.go('/login');
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kCoralDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kCoralDark.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: kCoralDark, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: TextStyle(
                              color: kCoralDark,
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

  Widget _themePicker(WidgetRef ref, bool dark) {
    final themeChoice = ref.watch(themeChoiceProvider);

    return _sectionCard(
      'PREFERENCES',
      [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'Theme',
                style: TextStyle(
                  color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF191716) : const Color(0xFFFFF8EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ThemeChoice.values.map((choice) {
                    final active = choice == themeChoice;
                    final icon = choice == ThemeChoice.system
                        ? Icons.brightness_auto_rounded
                        : choice == ThemeChoice.dark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded;
                    return GestureDetector(
                      onTap: () {
                        ref.read(themeChoiceProvider.notifier).setTheme(choice);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? kCoral : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: active ? Colors.white : (dark ? kCream : kCharcoal),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
      dark,
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
            const [kCoral, kAmber],
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
          color: dark ? kDarkPaper : kPaper,
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
  }) =>
      Container(
        width: double.infinity,
        height: 230,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

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
                    color: kCoralDark,
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
                color: kCoral,
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
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.88,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: dark ? kDarkPaper : Colors.white,
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
                    decoration: BoxDecoration(color: kCoral, borderRadius: BorderRadius.circular(999)),
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
          Text(heading, style: const TextStyle(color: kCoralDark, fontSize: 13, fontWeight: FontWeight.w800)),
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
        backgroundColor: dark ? kDarkPaper : kPaper,
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
            child: const Text('Close', style: TextStyle(color: kCoral, fontWeight: FontWeight.bold)),
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
