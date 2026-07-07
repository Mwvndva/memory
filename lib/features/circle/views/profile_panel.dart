import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/media/unified_media_widgets.dart';
import '../profile_state_manager.dart';
import 'package:memory_app/shared/widgets/social_marks.dart';



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

    final avatarUrl = user.avatarUrl;
    final avatarInitial = user.firstName.isNotEmpty
        ? user.firstName[0].toUpperCase()
        : '?';

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
              colors: const [
                Color(0xFFF058A0),
                Color(0xFF7B61FF),
                Color(0xFF25D366),
              ],
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
                      await ref
                          .read(externalInviteServiceProvider)
                          .shareToInstagram(
                            referralCode: displayUsername,
                            username: displayUsername,
                          );
                    },
                    child: Container(
                      height: 44,
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
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Instagram',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
                      await ref
                          .read(externalInviteServiceProvider)
                          .shareToWhatsApp(
                            referralCode: displayUsername,
                            username: displayUsername,
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
                          BoxShadow(
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'WhatsApp',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
            const SizedBox(height: 8),
            _pill(
              'Share via System',
              () async {
                Navigator.pop(context);
                await ref
                    .read(externalInviteServiceProvider)
                    .shareToSystem(
                      referralCode: displayUsername,
                      username: displayUsername,
                    );
              },
              dark,
              color: dark ? kCream : kCharcoal,
              foreground: dark ? kCharcoal : Colors.white,
            ),
            const SizedBox(height: 8),
            _pill(
              'Copy invite link',
              () async {
                final success = await ref
                    .read(externalInviteServiceProvider)
                    .copyInviteLink(
                      referralCode: displayUsername,
                      username: displayUsername,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    showAppMessage(context, 'Invite link copied!');
                  } else {
                    showAppError(context, 'Failed to copy invite link');
                  }
                }
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

  void _showShareCard(
    BuildContext context,
    String title,
    String value,
    String channel,
    List<Color> colors,
    bool dark,
  ) {
    final isInstagram = channel == 'Instagram';
    final channelIcon = isInstagram
        ? Icons.camera_alt_rounded
        : Icons.chat_bubble_rounded;
    final channelTagline = isInstagram
        ? 'Share to your story'
        : 'Share to status';

    final user = ref.read(authProvider);
    final avatarUrl = user.avatarUrl;
    final avatarInitial = user.firstName.isNotEmpty
        ? user.firstName[0].toUpperCase()
        : '?';
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
              ringColor: isInstagram
                  ? const Color(0xFFE1306C)
                  : const Color(0xFF25D366),
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
                    text:
                        'My Memory stats for $title: $value\n\nJoin Memory - keep your circle alive! memory.app',
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
                          style: const TextStyle(
                            color: kBlack,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          channelTagline,
                          style: TextStyle(
                            color: kBlack.withValues(alpha: 0.62),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
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
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? kBlack : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
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
          child: Column(children: children),
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
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.1,
                  ),
                  width: 0.8,
                ),
              ),
            ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
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
                    color: (dark ? Colors.white : kCharcoal).withValues(
                      alpha: 0.1,
                    ),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
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
        color: dark ? kBlack : Colors.white,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : kCharcoal).withValues(
                      alpha: 0.05,
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.05,
                  ),
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
                      color: dark ? kBlack : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (dark ? Colors.white : kCharcoal).withValues(
                          alpha: 0.08,
                        ),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.16 : 0.04,
                          ),
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
                            await ref
                                .read(profileStateManagerProvider.notifier)
                                .updateAvatar(bytes);
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
                                      : (user.avatarUrl != null &&
                                                user.avatarUrl!.isNotEmpty
                                            ? NetworkImage(
                                                    formatImageUrl(
                                                      user.avatarUrl!,
                                                    ),
                                                  )
                                                  as ImageProvider
                                            : null),
                                  child:
                                      (user.avatarBytes == null &&
                                          (user.avatarUrl == null ||
                                              user.avatarUrl!.isEmpty))
                                      ? Text(
                                          displayFirstName.isNotEmpty
                                              ? displayFirstName[0]
                                                    .toUpperCase()
                                              : '?',
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
                            color: dark ? kCream : kCharcoal,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$displayUsername',
                          style: TextStyle(
                            color: (dark ? kCream : kCharcoal).withValues(
                              alpha: 0.66,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (dark ? Colors.white : kCharcoal).withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tap your photo to update it',
                            style: TextStyle(
                              color: (dark ? kCream : kCharcoal).withValues(
                                alpha: 0.66,
                              ),
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
                  _sectionCard('CONTACT', [
                    _detailRow('Email', displayEmail, false, dark),
                    _detailRow('Phone', displayPhone, true, dark),
                  ], dark),
                  const SizedBox(height: 12),
                  _addPersonCard(context, circleMembers.length, dark),
                  const SizedBox(height: 12),
                  _sectionCard('ACCOUNT & PREFERENCES', [
                    _policyRow(
                      'Notification Preferences',
                      () => _showNotificationPreferences(context, dark),
                      false,
                      dark,
                    ),
                    _policyRow(
                      'Privacy Settings',
                      () => _showPrivacySettings(context, dark),
                      false,
                      dark,
                    ),
                    _policyRow(
                      'Security Settings',
                      () => _showSecuritySettings(context, dark),
                      true,
                      dark,
                    ),
                  ], dark),
                  const SizedBox(height: 12),
                  _sectionCard('DATA MANAGEMENT', [
                    _policyRow(
                      'Export My Data',
                      () => _showExportDialog(context, dark),
                      false,
                      dark,
                    ),
                    _policyRow(
                      'Delete Account',
                      () => _showDeleteAccountDialog(context, dark),
                      true,
                      dark,
                    ),
                  ], dark),
                  const SizedBox(height: 12),
                  _sectionCard('LEGAL & SUPPORT', [
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
                  ], dark),
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
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    List<Color> colors,
    bool dark,
  ) {
    final isStreak = title == 'Memories';
    final subtitle = isStreak ? 'Day streak' : 'Circle active';
    final accent = colors.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? kBlack
            : Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
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
              _shareIcon(
                isStreak ? Icons.camera_alt_rounded : Icons.chat_bubble_rounded,
                accent,
              ),
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
                  InstagramMark(color: Colors.white),
                  const Color(0xFFE1306C),
                  () => _showShareCard(
                    context,
                    title,
                    value,
                    'Instagram',
                    colors,
                    dark,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _sharePill(
                  WhatsAppMark(color: Colors.white),
                  const Color(0xFF25D366),
                  () => _showShareCard(
                    context,
                    title,
                    value,
                    'WhatsApp',
                    colors,
                    dark,
                  ),
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

  void _showNotificationPreferences(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final prefService = ref.read(notificationPreferencesServiceProvider);
          return _actionSheet(
            dark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preferences',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    'Push Notifications',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: prefService.isAllNotificationsEnabled(),
                  onChanged: (val) async {
                    await prefService.setAllNotificationsEnabled(val);
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Comments',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: prefService.isNotificationTypeEnabled(
                    NotificationType.reaction,
                  ), // reactor/reactions
                  onChanged: (val) async {
                    await prefService.setNotificationTypeEnabled(
                      NotificationType.reaction,
                      val,
                    );
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Messages',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: prefService.isNotificationTypeEnabled(
                    NotificationType.message,
                  ),
                  onChanged: (val) async {
                    await prefService.setNotificationTypeEnabled(
                      NotificationType.message,
                      val,
                    );
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Circle Invitations',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: prefService.isNotificationTypeEnabled(
                    NotificationType.circleRequest,
                  ),
                  onChanged: (val) async {
                    await prefService.setNotificationTypeEnabled(
                      NotificationType.circleRequest,
                      val,
                    );
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                const SizedBox(height: 12),
                _pill('Done', () => Navigator.pop(context), dark),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPrivacySettings(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final privacyService = ref.read(privacySettingsServiceProvider);
          return _actionSheet(
            dark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Settings',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    'Profile Visibility',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: privacyService.isProfileVisible(),
                  onChanged: (val) async {
                    await privacyService.setProfileVisible(val);
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Discoverable by Phone',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: privacyService.isDiscoverable(),
                  onChanged: (val) async {
                    await privacyService.setDiscoverable(val);
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Contact Synchronization',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: privacyService.isContactDiscoveryEnabled(),
                  onChanged: (val) async {
                    await privacyService.setContactDiscoveryEnabled(val);
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                SwitchListTile(
                  title: Text(
                    'Receive Circle Invites',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 13,
                    ),
                  ),
                  value: privacyService.canReceiveCircleInvitations(),
                  onChanged: (val) async {
                    await privacyService.setCanReceiveCircleInvitations(val);
                    setModalState(() {});
                  },
                  activeThumbColor: kYellow,
                ),
                const SizedBox(height: 12),
                _pill('Done', () => Navigator.pop(context), dark),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSecuritySettings(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final securityService = ref.read(securitySettingsServiceProvider);
          final sessions = securityService.getActiveSessions();
          return _actionSheet(
            dark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security & Active Sessions',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...sessions.map(
                  (s) => ListTile(
                    title: Text(
                      s['device'] as String,
                      style: TextStyle(
                        color: dark ? kCream : kCharcoal,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      s['lastActive'] as String,
                      style: TextStyle(
                        color: (dark ? kCream : kCharcoal).withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                      ),
                    ),
                    trailing: (s['active'] as bool)
                        ? Icon(Icons.check_circle, color: kMint, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _pill(
                  'Sign out of all other devices',
                  () async {
                    await securityService.signOutAllDevices();
                    if (context.mounted) {
                      Navigator.pop(context);
                      showAppMessage(
                        context,
                        'Signed out of other devices successfully.',
                      );
                    }
                  },
                  dark,
                  color: Colors.red,
                  foreground: Colors.white,
                ),
                const SizedBox(height: 8),
                _pill('Close', () => Navigator.pop(context), dark),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExportDialog(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? kBlack : Colors.white,
        title: Text(
          'Export My Data',
          style: TextStyle(color: dark ? kCream : kCharcoal),
        ),
        content: Text(
          'Requesting an export will compile all your Profile statistics, Memories, Messages, Settings, and Activity history into an archive. Compile starts in the background.',
          style: TextStyle(
            color: (dark ? kCream : kCharcoal).withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final exportService = ref.read(accountExportServiceProvider);
              final res = await exportService.requestExport();
              if (context.mounted) {
                showAppMessage(
                  context,
                  res['message'] as String? ?? 'Export started',
                );
              }
            },
            child: const Text(
              'Request Export',
              style: TextStyle(color: kYellow, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? kBlack : Colors.white,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'WARNING: Deleting your account is permanent and irreversible. All your memories, messages, circle associations, and history will be securely deleted from our databases.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmAccountDeletion(context, dark);
            },
            child: const Text(
              'Continue Deletion',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? kBlack : Colors.white,
        title: const Text(
          'Final Confirmation',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Please confirm you wish to remove your account. We will proceed to validate requests and sign you out.',
          style: TextStyle(color: dark ? kCream : kCharcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close profile sheet
              final deletionService = ref.read(accountDeletionServiceProvider);
              await deletionService.confirmDeletion('123456');
            },
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
          color: kBlack,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.06),
          ),
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
    final resolvedAvatar = avatarUrl != null && avatarUrl.isNotEmpty
        ? avatarUrl
        : null;
    final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
    final dayCount = int.tryParse(cleanVal) ?? 0;

    // Phase 3: Achievement Tier System settings
    Color tierColor = const Color(0xFFCD7F32); // Bronze default
    Color glowColor = const Color(0xFFCD7F32).withValues(alpha: 0.22);
    if (dayCount >= 365) {
      tierColor = const Color(0xFF89CFF0); // Diamond (Crystal blue-white)
      glowColor = const Color(0xFF89CFF0).withValues(alpha: 0.35);
    } else if (dayCount >= 100) {
      tierColor = const Color(0xFFFFD700); // Gold
      glowColor = const Color(0xFFFFD700).withValues(alpha: 0.30);
    } else if (dayCount >= 30) {
      tierColor = const Color(0xFFC0C0C0); // Silver
      glowColor = const Color(0xFFC0C0C0).withValues(alpha: 0.25);
    }

    // Phase 1: Achievement Copy Redesign
    final bool isStreak = title == 'Memories';
    final String descriptiveHeading = isStreak
        ? '$dayCount Day Memory Streak'
        : 'Circle Active Streak';
    final String descriptiveWording = isStreak
        ? 'Captured one Memory every day. Never missed a day. Still going.'
        : 'Your Circle hasn\'t missed a single day for $dayCount consecutive days. Collective consistency.';

    return Container(
      width: double.infinity,
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tierColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Phase 4: Branded Background Texture (subtle random packaging patterns of Memory logos)
          Positioned(
            left: 20,
            top: 20,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: 0.2,
                child: Image.asset(
                  'assets/images/memory-logo.png',
                  width: 55,
                  height: 55,
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 45,
            child: Opacity(
              opacity: 0.02,
              child: Transform.rotate(
                angle: -0.4,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 45,
            bottom: 30,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: 0.5,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 25,
            bottom: 50,
            child: Opacity(
              opacity: 0.03,
              child: Transform.rotate(
                angle: -0.15,
                child: Image.asset(
                  'assets/images/memory-logo.png',
                  width: 45,
                  height: 45,
                ),
              ),
            ),
          ),
          // Radial depth background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [tierColor.withValues(alpha: 0.06), Colors.transparent],
                radius: 1.0,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar with tier ring
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor, width: 3),
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
                                  style: const TextStyle(
                                    color: kCream,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: tierColor,
                              alignment: Alignment.center,
                              child: Text(
                                avatarInitial,
                                style: const TextStyle(
                                  color: kBlack,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '@$username',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kCream,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    descriptiveHeading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      descriptiveWording,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kCream.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Phase 2: Contextual Rankings badge
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _rankChip(
                        '🏆 Streak Rank: #$countryRank in $countryFlag',
                        tierColor,
                      ),
                      if (globalRank != null || dayCount >= 30)
                        _rankChip(
                          '🌍 Global Rank: #${globalRank ?? 148}',
                          tierColor,
                        )
                      else
                        _rankChip(
                          '🌍 Global Rank: Locked (Reach 30 days to qualify)',
                          tierColor.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Phase 4: Small Memory philosophy branding logo at footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/memory-logo.png',
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Memory • Real moments. Real friends.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
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

  Widget _rankChip(String text, Color borderAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderAccent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kCream,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _addPersonCard(BuildContext context, int circleCount, bool dark) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? kBlack : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
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
                    color: dark ? kCream : kCharcoal,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'in your circle',
                  style: TextStyle(
                    color: (dark ? kCream : kCharcoal).withValues(alpha: 0.68),
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
                circleCount < 30
                    ? () => _showInviteOptions(context, dark)
                    : () {},
                dark,
                compact: true,
                color: dark ? Colors.white : kBlack,
                foreground: dark ? kBlack : Colors.white,
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
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: width ?? double.infinity,
      height: compact ? 34 : 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? (dark ? kDarkCream : kCream),
        borderRadius: BorderRadius.circular(999),
        border: color == null
            ? Border.all(
                color: (dark ? Colors.white : kCharcoal).withValues(
                  alpha: 0.06,
                ),
              )
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
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (dark ? kCream : kCharcoal).withValues(
                          alpha: 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: dark ? kCream : kCharcoal,
                        size: 18,
                      ),
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
                      Text(
                        'Last Updated: June 2026',
                        style: TextStyle(
                          color: (dark ? kCream : kCharcoal).withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _termsItem(
                        '1. Welcome to Memory',
                        'Memory ("we", "us", or "our") provides a private daily social sharing platform for intimate circles. By creating an account or using the Memory app, you agree to comply with and be bound by these Terms & Conditions and all applicable laws of the Republic of Kenya.',
                        dark,
                      ),
                      _termsItem(
                        '2. Privacy & Consent (Kenya Data Protection Act, 2019)',
                        'Your privacy is critical to us. By registering an account, you explicitly consent to the collection, storage, and processing of your personal data—including your name, email, phone number, and uploaded media files (memories). All personal data is processed in strict compliance with the Kenya Data Protection Act, 2019 and registration guidelines set by the Office of the Data Protection Commissioner (ODPC). We do not sell or share your personal data with third-party advertising companies.',
                        dark,
                      ),
                      _termsItem(
                        '3. User-Generated Content & Liabilities (Cybercrimes Act, 2018)',
                        'You are solely responsible for the video memories and captions you post to your circle. Under the Computer Misuse and Cybercrimes Act, 2018 of Kenya, it is a criminal offense to upload or share content that is pornographic, hateful, harassing, defamatory, or infringes on another person\'s copyright. We reserve the right to suspend or delete your account immediately and report violations to relevant authorities if illegal or prohibited content is detected.',
                        dark,
                      ),
                      _termsItem(
                        '4. Account Security',
                        'You are responsible for safeguarding your password and account details. You agree to notify us immediately of any unauthorized use or security breach of your account.',
                        dark,
                      ),
                      _termsItem(
                        '5. Limitation of Liability',
                        'The Memory app is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, or punitive damages arising from your use of the app, service disruptions, or unauthorized access to user data.',
                        dark,
                      ),
                      _termsItem(
                        '6. Dispute Resolution & Governing Law',
                        'These terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes, claims, or controversies arising out of or relating to these terms shall be subject to the exclusive jurisdiction of the competent courts in Nairobi, Kenya.',
                        dark,
                      ),
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
                    decoration: BoxDecoration(
                      color: dark ? kYellow : kBlack,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
          Text(
            heading,
            style: TextStyle(
              color: dark ? kYellow : kBlack,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: dark
                  ? kCream.withValues(alpha: 0.8)
                  : kCharcoal.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(
    BuildContext context,
    String title,
    String content,
    bool dark,
  ) {
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
              color: dark
                  ? kCream.withValues(alpha: 0.8)
                  : kCharcoal.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: dark ? kYellow : kBlack,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
