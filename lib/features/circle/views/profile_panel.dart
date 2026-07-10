import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/feed/feed.dart';

import '../models/user_profile.dart';
import '../profile_state_manager.dart';
import '../repositories/circles_repository.dart';
import '../widgets/profile_stat_cards.dart';
import '../widgets/profile_widgets.dart';
import 'profile_account_actions.dart';
import 'profile_legal_sheets.dart';
import 'profile_settings_sheets.dart';
import 'profile_share_card.dart';

const String _privacyPolicyBody =
    'Your privacy matters to us. Memory App is built to share moments only with '
    'your chosen circle. We do not sell or share your data with advertisers. All '
    'uploaded memories are encrypted and visible only to the members of your '
    'active circle. You can delete your memories or close your account at any time.';

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

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref.read(profileStateManagerProvider.notifier).updateAvatar(bytes);
  }

  /// The user's phone number may be prefixed with a regional-indicator flag.
  static String _flagFrom(String phone) {
    if (phone.isNotEmpty) {
      final runes = phone.runes.toList();
      if (runes.length >= 2 && runes[0] >= 127462 && runes[0] <= 127487) {
        return String.fromCharCodes(runes.take(2));
      }
    }
    return '🇰🇪';
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

    final flag = _flagFrom(user.phone);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: dark ? MemoryColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: (dark ? Colors.white : MemoryColors.charcoal).withValues(
            alpha: 0.06,
          ),
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
              color: (dark ? Colors.white : MemoryColors.charcoal).withValues(
                alpha: 0.12,
              ),
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
                    color: (dark ? Colors.white : MemoryColors.charcoal)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Close',
                    style: MemoryTypography.body.copyWith(
                      color: dark ? MemoryColors.cream : MemoryColors.charcoal,
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
                  color: (dark ? Colors.white : MemoryColors.charcoal)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Text(flag, style: MemoryTypography.button),
                    const SizedBox(width: 6),
                    Text(
                      '#${user.countryRank}',
                      style: MemoryTypography.buttonCompact.copyWith(
                        color: dark
                            ? MemoryColors.cream
                            : MemoryColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user.globalRank != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.public_rounded,
                        color: dark
                            ? MemoryColors.cream
                            : MemoryColors.charcoal,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '#${user.globalRank}',
                        style: MemoryTypography.caption.copyWith(
                          color: dark
                              ? MemoryColors.cream
                              : MemoryColors.charcoal,
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
                      color: dark ? MemoryColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (dark ? Colors.white : MemoryColors.charcoal)
                            .withValues(alpha: 0.08),
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
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dark
                                      ? MemoryColors.accent
                                      : MemoryColors.ink,
                                ),
                                child: MemoryAvatar(
                                  radius: 34,
                                  dark: dark,
                                  bytes: user.avatarBytes,
                                  imageUrl:
                                      user.avatarUrl == null ||
                                          user.avatarUrl!.isEmpty
                                      ? null
                                      : formatImageUrl(user.avatarUrl!),
                                  initial: displayFirstName,
                                  background: dark
                                      ? MemoryColors.ink
                                      : Colors.white,
                                  foreground: MemoryColors.accent,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: MemoryColors.ink,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dark
                                          ? MemoryColors.accent
                                          : MemoryColors.ink,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: dark
                                        ? MemoryColors.accent
                                        : MemoryColors.ink,
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
                          style: MemoryTypography.title.copyWith(
                            color: dark
                                ? MemoryColors.cream
                                : MemoryColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$displayUsername',
                          style: MemoryTypography.bodySmall.copyWith(
                            color:
                                (dark
                                        ? MemoryColors.cream
                                        : MemoryColors.charcoal)
                                    .withValues(alpha: 0.66),
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
                            color: (dark ? Colors.white : MemoryColors.charcoal)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tap your photo to update it',
                            style: MemoryTypography.caption.copyWith(
                              color:
                                  (dark
                                          ? MemoryColors.cream
                                          : MemoryColors.charcoal)
                                      .withValues(alpha: 0.66),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ProfileStatCards(dark: dark),
                  const SizedBox(height: 12),
                  MemorySection(
                    title: 'CONTACT',
                    dark: dark,
                    children: [
                      MemoryListTile(
                        label: 'Email',
                        value: displayEmail,
                        isLast: false,
                        dark: dark,
                      ),
                      MemoryListTile(
                        label: 'Phone',
                        value: displayPhone,
                        isLast: true,
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ProfileAddPersonCard(
                    circleCount: circleMembers.length,
                    dark: dark,
                    onAddPerson: () => showInviteOptions(context, dark),
                  ),
                  const SizedBox(height: 12),
                  MemorySection(
                    title: 'ACCOUNT & PREFERENCES',
                    dark: dark,
                    children: [
                      MemoryActionTile(
                        title: 'Notification Preferences',
                        onTap: () => showNotificationPreferences(context, dark),
                        isLast: false,
                        dark: dark,
                      ),
                      MemoryActionTile(
                        title: 'Privacy Settings',
                        onTap: () => showPrivacySettings(context, dark),
                        isLast: false,
                        dark: dark,
                      ),
                      MemoryActionTile(
                        title: 'Security Settings',
                        onTap: () => showSecuritySettings(context, dark),
                        isLast: true,
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MemorySection(
                    title: 'DATA MANAGEMENT',
                    dark: dark,
                    children: [
                      MemoryActionTile(
                        title: 'Export My Data',
                        onTap: () => showExportDialog(context, dark),
                        isLast: false,
                        dark: dark,
                      ),
                      MemoryActionTile(
                        title: 'Delete Account',
                        onTap: () => showDeleteAccountDialog(context, dark),
                        isLast: true,
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MemorySection(
                    title: 'LEGAL & SUPPORT',
                    dark: dark,
                    children: [
                      MemoryActionTile(
                        title: 'Privacy Policy',
                        onTap: () => showPolicyDialog(
                          context,
                          'Privacy Policy',
                          _privacyPolicyBody,
                          dark,
                        ),
                        isLast: false,
                        dark: dark,
                      ),
                      MemoryActionTile(
                        title: 'Terms & Conditions',
                        onTap: () => showFullTermsSheet(context, dark),
                        isLast: true,
                        dark: dark,
                      ),
                    ],
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
                      child: Row(
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
                            style: MemoryTypography.body.copyWith(
                              color: Colors.white,
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
}
