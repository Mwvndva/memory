import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/auth/repositories/auth_repository.dart';

import '../repositories/circles_repository.dart';
import '../services/external_invite_service.dart';
import '../widgets/profile_widgets.dart';

// The sheets below deliberately close over the caller's [context] rather than
// their own builder context: the caller (the profile panel) outlives the sheet,
// so it is still mounted for the snackbars shown after the sheet is popped.

/// Bottom sheet offering the ways to invite someone into the circle.
void showInviteOptions(BuildContext context, bool dark) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Consumer(
      builder: (_, ref, _) {
        final circleMembers = ref.watch(circlesProvider);
        final user = ref.watch(authProvider);
        final displayUsername = user.username.isNotEmpty
            ? user.username
            : 'user';

        final avatarUrl = user.avatarUrl;
        final avatarInitial = user.firstName.isNotEmpty
            ? user.firstName[0].toUpperCase()
            : '?';

        final inviteService = ref.read(externalInviteServiceProvider);

        return MemoryBottomSheet(
          dark: dark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileFunCard(
                title: 'Join my circle',
                value:
                    '${circleMembers.length} / ${ProfileAddPersonCard.maxCircleSize}',
                avatarUrl: avatarUrl,
                avatarInitial: avatarInitial,
              ),
              const SizedBox(height: MemorySpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: MemoryShareButton(
                      brand: MemoryShareBrand.instagram,
                      onPressed: () async {
                        Navigator.pop(context);
                        await inviteService.shareToInstagram(
                          referralCode: displayUsername,
                          username: displayUsername,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: MemorySpacing.md),
                  Expanded(
                    child: MemoryShareButton(
                      brand: MemoryShareBrand.whatsApp,
                      onPressed: () async {
                        Navigator.pop(context);
                        await inviteService.shareToWhatsApp(
                          referralCode: displayUsername,
                          username: displayUsername,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MemorySpacing.md),
              MemoryButton(
                label: 'Share via System',
                onPressed: () async {
                  Navigator.pop(context);
                  await inviteService.shareToSystem(
                    referralCode: displayUsername,
                    username: displayUsername,
                  );
                },
                dark: dark,
                background: dark ? MemoryColors.cream : MemoryColors.charcoal,
                foreground: dark ? MemoryColors.charcoal : Colors.white,
              ),
              const SizedBox(height: MemorySpacing.md),
              MemoryButton(
                label: 'Copy invite link',
                onPressed: () async {
                  final success = await inviteService.copyInviteLink(
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
                dark: dark,
                background: dark ? MemoryColors.cream : MemoryColors.charcoal,
                foreground: dark ? MemoryColors.charcoal : Colors.white,
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Bottom sheet previewing a shareable stat card for [channel].
void showShareCard(
  BuildContext context, {
  required String title,
  required String value,
  required String channel,
  required bool dark,
}) {
  final isInstagram = channel == 'Instagram';
  final channelIcon = isInstagram
      ? Icons.camera_alt_rounded
      : Icons.chat_bubble_rounded;
  final channelTagline = isInstagram
      ? 'Share to your story'
      : 'Share to status';

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Consumer(
      builder: (_, ref, _) {
        final user = ref.watch(authProvider);
        final avatarInitial = user.firstName.isNotEmpty
            ? user.firstName[0].toUpperCase()
            : '?';
        final displayUsername = user.username.isNotEmpty
            ? user.username
            : 'user';

        String flag = 'KE';
        if (user.phone.isNotEmpty) {
          final runes = user.phone.runes.toList();
          if (runes.length >= 2 && runes[0] >= 127462 && runes[0] <= 127487) {
            flag = String.fromCharCodes(runes.take(2));
          }
        }

        return MemoryBottomSheet(
          dark: dark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileFunCard(
                title: title,
                value: value,
                avatarUrl: user.avatarUrl,
                avatarBytes: user.avatarBytes,
                avatarInitial: avatarInitial,
                username: displayUsername,
                countryFlag: flag,
                countryRank: user.countryRank,
                globalRank: user.globalRank,
              ),
              const SizedBox(height: MemorySpacing.xxl),
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
                    color: MemoryColors.accent,
                    borderRadius: BorderRadius.circular(MemoryRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: MemoryColors.accent.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(channelIcon, color: MemoryColors.ink, size: 18),
                      const SizedBox(width: MemorySpacing.md),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send to $channel',
                            style: MemoryTypography.bodyLarge.copyWith(
                              color: MemoryColors.ink,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            channelTagline,
                            style: MemoryTypography.buttonCompact.copyWith(
                              color: MemoryColors.ink.withValues(alpha: 0.62),
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
        );
      },
    ),
  );
}
