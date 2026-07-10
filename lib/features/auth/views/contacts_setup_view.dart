import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/circle/circle.dart';
import '../../circle/circle_state_manager.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/shared/widgets/pills.dart';

class ContactsSetupView extends ConsumerStatefulWidget {
  const ContactsSetupView({super.key});

  @override
  ConsumerState<ContactsSetupView> createState() => _ContactsSetupViewState();
}

class _ContactsSetupViewState extends ConsumerState<ContactsSetupView> {
  final Set<String> _addedToCircle = {};
  List<CircleMember> _matchedUsers = [];
  bool _isLoading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final granted =
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
      if (granted) {
        final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone, ContactProperty.email},
        );

        List<CircleMember> matched = [];

        if (kUseMockBackend) {
          matched = [
            const CircleMember(
              id: 'mock_amara',
              username: 'amara',
              firstName: 'Amara',
            ),
            const CircleMember(
              id: 'mock_mum',
              username: 'mumsmemories',
              firstName: 'Mum',
            ),
          ];
        } else {
          // Deduplicate and normalize phone numbers locally on the client side
          final normalizedList = contacts
              .expand(
                (c) => c.phones.map(
                  (p) => p.number.replaceAll(RegExp(r'\s+'), ''),
                ),
              )
              .where((phoneNum) => phoneNum.isNotEmpty)
              .toSet() // Deduplicate
              .toList();

          if (normalizedList.isNotEmpty) {
            final authRepo = ref.read(authRepositoryProvider);
            matched = await authRepo.syncContacts(normalizedList);
          }
        }

        // Contact sync is a network round trip; the user can leave this screen
        // while it is in flight.
        if (!mounted) return;
        setState(() {
          _matchedUsers = matched;
          _permissionGranted = true;
          _isLoading = false;
        });

        if (matched.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showInviteSheet(context);
          });
        }
      } else {
        setState(() {
          _permissionGranted = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _permissionGranted = false;
        _isLoading = false;
      });
    }
  }

  void _showInviteSheet(BuildContext context) {
    final dark = ref.read(isDarkProvider);
    final user = ref.read(authProvider);
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    final inviteLink = 'https://memory.app/invite/$displayUsername';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: dark ? kBlack : kYellow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'No contacts on Memory yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Invite your friends to keep your circle alive! ⚡',
                style: TextStyle(
                  fontSize: 12,
                  color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
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
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF058A0),
                              Color(0xFFBD3EFF),
                              Color(0xFFFF6B00),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF058A0,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Instagram',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF25D366,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inviteLink));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied!')),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : kCharcoal).withValues(
                      alpha: 0.08,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: dark ? kCream : kCharcoal,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Copy invite link',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _toggleAdded(String user) {
    setState(() {
      if (_addedToCircle.contains(user)) {
        _addedToCircle.remove(user);
      } else {
        _addedToCircle.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : kCream;
    final fg = dark ? kCream : kCharcoal;

    final List<Widget> listItems = [];

    if (_permissionGranted && _matchedUsers.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            'Contacts already on Memory',
            style: TextStyle(
              color: kBlack,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

      for (final matchedUser in _matchedUsers) {
        final name = '${matchedUser.firstName} ${matchedUser.lastName}'.trim();
        final displayName = name.isNotEmpty ? name : matchedUser.username;
        final initial = matchedUser.firstName.isNotEmpty
            ? matchedUser.firstName[0].toUpperCase()
            : '?';

        listItems.add(
          _contactRow(
            initial: initial,
            name: displayName,
            subtitle: '@${matchedUser.username}',
            color: (dark ? kYellow : kBlack).withValues(alpha: 0.6),
            fg: fg,
            dark: dark,
            isMock: kUseMockBackend,
            userKey: matchedUser.id,
            avatarUrl: matchedUser.avatarUrl,
          ),
        );
      }
    } else if (_permissionGranted && _matchedUsers.isEmpty && !_isLoading) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Text(
            'None of your contacts are on Memory yet. Invite them below!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg.withValues(alpha: .5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (_isLoading) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(color: dark ? kYellow : kBlack),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 52, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Build your circle', style: _headline(fg, 32)),
              const SizedBox(height: 8),
              Text(
                'People from your contacts already on Memory.',
                style: _small(fg.withValues(alpha: .68)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...listItems,
                    const SizedBox(height: 14),
                    _inviteCard(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              pill(
                'Start using Memory',
                () {
                  ref.read(sessionProvider.notifier).authenticate();
                  context.go('/feed');
                },
                dark,
                color: dark ? kYellow : kBlack,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow({
    required String initial,
    required String name,
    required String subtitle,
    required Color color,
    required Color fg,
    required bool dark,
    required bool isMock,
    required String userKey,
    String? avatarUrl,
  }) {
    final isAdded = _addedToCircle.contains(userKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(formatImageUrl(avatarUrl)) as ImageProvider
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    initial,
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
                  style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                ),
                Text(subtitle, style: _small(fg.withValues(alpha: .58))),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 34,
            child: pill(
              isAdded ? 'Requested' : 'Add to circle',
              () async {
                if (isAdded) return;
                if (isMock) {
                  _toggleAdded(userKey);
                } else {
                  final Map<String, dynamic> result = await ref
                      .read(circleStateManagerProvider.notifier)
                      .inviteMember(userKey);
                  final ok = result['ok'] == true;
                  final msg = result['message']?.toString() ?? '';
                  if (ok) {
                    _toggleAdded(userKey);
                    if (mounted) {
                      showAppMessage(
                        context,
                        msg.isNotEmpty ? msg : 'Request sent',
                      );
                    }
                  } else {
                    if (mounted) {
                      showAppError(
                        context,
                        msg.isNotEmpty ? msg : 'Failed to send request',
                      );
                    }
                  }
                }
              },
              dark,
              compact: true,
              color: isAdded
                  ? Colors.grey.withValues(alpha: 0.5)
                  : (dark ? kYellow : kBlack),
              foreground: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ref.watch(isDarkProvider) ? kYellow : kBlack, kAmber],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite to circle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bring in someone who should see the real version of your life.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              await SharePlus.instance.share(
                ShareParams(
                  text: 'Join my circle on Memory! https://memory.app/invite',
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: kBlack, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Invite a Friend',
                    style: TextStyle(
                      color: kBlack,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _headline(Color color, double size) =>
    headlineStyle(color).copyWith(fontSize: size);
TextStyle _small(Color color) => smallStyle(color);
