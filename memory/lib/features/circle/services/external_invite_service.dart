import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ExternalInviteService {
  static const String inviteBaseUrl = 'https://memoryapp.link/invite';

  String _buildInviteMessage(String referralCode, String username) {
    return 'Join my Circle on Memory! Use my referral code: $referralCode. Link: $inviteBaseUrl?ref=$referralCode&user=$username';
  }

  Future<void> shareToWhatsApp({
    required String referralCode,
    required String username,
  }) async {
    final text = _buildInviteMessage(referralCode, username);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> shareToInstagram({
    required String referralCode,
    required String username,
  }) async {
    final text = _buildInviteMessage(referralCode, username);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> shareToSystem({
    required String referralCode,
    required String username,
  }) async {
    final text = _buildInviteMessage(referralCode, username);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<bool> copyInviteLink({
    required String referralCode,
    required String username,
  }) async {
    final link = '$inviteBaseUrl?ref=$referralCode&user=$username';
    try {
      await Clipboard.setData(ClipboardData(text: link));
      return true;
    } catch (e) {
      return false;
    }
  }
}

final externalInviteServiceProvider = Provider<ExternalInviteService>((ref) {
  return ExternalInviteService();
});
