import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/chat_repository.dart';

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

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.fromLTRB(22, 74, 22, 94),
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
                        backgroundImage: user.avatarBytes == null ? null : MemoryImage(user.avatarBytes!),
                        child: user.avatarBytes == null
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
                ...['Amara', 'Mum', 'Leo', 'Nia'].map((name) => _chatRow(context, name, dark, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatRow(BuildContext context, String name, bool dark, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(chatProvider.notifier).decrementNotifications();
        context.push('/chat/$name');
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
              child: Text(
                name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
      body: Container(
        padding: const EdgeInsets.fromLTRB(22, 64, 22, 40),
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
  final int _circleCount = 12;

  void _showInviteOptions(BuildContext context, bool dark) {
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
              value: '12 / 30',
              label: 'memory.app/invite/roy',
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
                          text: 'Join my circle on Memory! https://memory.app/invite/roy',
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
                          text: 'Join my circle on Memory! https://memory.app/invite/roy',
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
                  const ClipboardData(text: 'https://memory.app/invite/roy'),
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

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final user = ref.watch(authProvider);

    final displayFirstName = user.firstName.isNotEmpty ? user.firstName : 'Roy';
    final displayLastName = user.lastName.isNotEmpty ? user.lastName : 'Nthiga';
    final displayUsername = user.username.isNotEmpty ? user.username : 'roykeepsmemories';
    final displayEmail = user.email.isNotEmpty ? user.email : 'roy@memory.app';
    final displayPhone = user.phone.isNotEmpty ? user.phone : '+254 712 345 678';

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? kDarkPaper : kPaper,
        borderRadius: BorderRadius.circular(30),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: dark ? kDarkCream : kCream,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '🇰🇪',
                        style: TextStyle(
                          color: kCoral,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '12',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.public_rounded,
                        color: dark ? kCream : kCharcoal,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '428',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            CircleAvatar(
              radius: 29,
              backgroundColor: kCoral,
              backgroundImage: user.avatarBytes == null ? null : MemoryImage(user.avatarBytes!),
              child: user.avatarBytes == null
                  ? Text(
                      displayFirstName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              '$displayFirstName $displayLastName',
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '@$displayUsername',
              style: _small(dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
            ),
            const SizedBox(height: 12),
            _themePicker(ref, dark),
            const SizedBox(height: 8),
            _statCards(context, dark),
            const SizedBox(height: 8),
            _detail('First name', displayFirstName, dark),
            _detail('Last name', displayLastName, dark),
            _detail('Email', displayEmail, dark),
            _detail('Phone', displayPhone, dark),
            _detail('Username', '@$displayUsername', dark),
            const SizedBox(height: 10),
            _addPersonCard(context, dark),
            const SizedBox(height: 10),
            _policyCard(
              'Privacy Policy',
              () => _showPolicyDialog(
                context,
                'Privacy Policy',
                'Your privacy matters to us. Memory App is built to share moments only with your chosen circle. We do not sell or share your data with advertisers. All uploaded memories are encrypted and visible only to the members of your active circle. You can delete your memories or close your account at any time.',
                dark,
              ),
              dark,
            ),
            _policyCard(
              'Terms & Conditions',
              () => _showPolicyDialog(
                context,
                'Terms & Conditions',
                'By using Memory, you agree to show the real version of your life. Do not upload offensive, illegal, or harmful content. You retain ownership of the content you post, but grant us a license to transmit it to your circle. Violation of circle trust can result in account suspension.',
                dark,
              ),
              dark,
            ),
            const SizedBox(height: 12),
            _pill(
              'Log Out',
              () {
                ref.read(authProvider.notifier).logout();
                Navigator.pop(context);
                context.go('/login');
              },
              dark,
              color: kCoralDark,
              foreground: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _themePicker(WidgetRef ref, bool dark) {
    final themeChoice = ref.watch(themeChoiceProvider);

    return Container(
      width: 236,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: dark ? kDarkCream : kCream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ThemeChoice.values.map((choice) {
          final label = choice == ThemeChoice.system
              ? 'Device'
              : choice.name[0].toUpperCase() + choice.name.substring(1);
          final active = choice == themeChoice;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(themeChoiceProvider.notifier).setTheme(choice);
              },
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? kCoral : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : (dark ? kCream : kCharcoal),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statCards(BuildContext context, bool dark) {
    return Column(
      children: [
        _statCard(context, 'Memories', '14 days', const [kCoral, kAmber], dark),
        const SizedBox(height: 8),
        _statCard(context, 'Circle Pulse', '8 days', const [kMint, kSky], dark),
      ],
    );
  }

  Widget _statCard(BuildContext context, String title, String value, List<Color> colors, bool dark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _sharePill('Instagram', () => _showShareCard(context, title, value, 'Instagram', colors, dark)),
          const SizedBox(width: 5),
          _sharePill('WhatsApp', () => _showShareCard(context, title, value, 'WhatsApp', colors, dark)),
        ],
      ),
    );
  }

  Widget _sharePill(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: kCharcoal,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _actionSheet(bool dark, {required Widget child}) => Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: dark ? kDarkPaper : kPaper,
          borderRadius: BorderRadius.circular(26),
        ),
        child: child,
      );

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

  Widget _detail(String a, String b, bool dark) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: dark ? kDarkCream : kCream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              a,
              style: _small(dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
            ),
            const Spacer(),
            Text(
              b,
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _addPersonCard(BuildContext context, bool dark) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? kDarkCream : kCream,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Text(
              '$_circleCount / 30\nin your circle',
              style: const TextStyle(
                color: kCoralDark,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 116,
              child: _pill(
                'Add someone',
                _circleCount < 30 ? () => _showInviteOptions(context, dark) : () {},
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

  Widget _policyCard(String title, VoidCallback onTap, bool dark) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: dark ? kDarkCream : kCream,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                size: 14,
              ),
            ],
          ),
        ),
      );

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

  TextStyle _small(Color color) => TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900);
}
