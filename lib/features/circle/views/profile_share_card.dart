import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/theme.dart';
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

        return ProfileActionSheet(
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await inviteService.shareToInstagram(
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
                        await inviteService.shareToWhatsApp(
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
              ProfilePill(
                text: 'Share via System',
                onTap: () async {
                  Navigator.pop(context);
                  await inviteService.shareToSystem(
                    referralCode: displayUsername,
                    username: displayUsername,
                  );
                },
                dark: dark,
                color: dark ? kCream : kCharcoal,
                foreground: dark ? kCharcoal : Colors.white,
              ),
              const SizedBox(height: 8),
              ProfilePill(
                text: 'Copy invite link',
                onTap: () async {
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
                color: dark ? kCream : kCharcoal,
                foreground: dark ? kCharcoal : Colors.white,
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

        return ProfileActionSheet(
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
        );
      },
    ),
  );
}
