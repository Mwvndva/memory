import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/structured_logger.dart';
import 'package:memory_app/core/app_providers.dart'; // contains sharedPreferencesProvider
import 'package:memory_app/features/auth/auth.dart'; // contains sessionProvider

// 1. AvatarUploadService
class AvatarUploadService {
  final Ref _ref;

  AvatarUploadService(this._ref);

  Future<void> upload(Uint8List bytes) async {
    await _ref.read(sessionProvider.notifier).updateAvatar(bytes);
  }
}

// 2. PrivacySettingsService
//
// These are device-local preferences: the backend exposes no privacy settings
// endpoints, so they are not synchronised across a user's devices.
class PrivacySettingsService {
  final SharedPreferences _prefs;
  static const String _prefix = 'privacy_';

  PrivacySettingsService(this._prefs);

  bool isProfileVisible() =>
      _prefs.getBool('${_prefix}profile_visible') ?? true;
  Future<void> setProfileVisible(bool val) =>
      _prefs.setBool('${_prefix}profile_visible', val);

  bool isDiscoverable() => _prefs.getBool('${_prefix}discoverable') ?? true;
  Future<void> setDiscoverable(bool val) =>
      _prefs.setBool('${_prefix}discoverable', val);

  bool isContactDiscoveryEnabled() =>
      _prefs.getBool('${_prefix}contact_discovery') ?? true;
  Future<void> setContactDiscoveryEnabled(bool val) =>
      _prefs.setBool('${_prefix}contact_discovery', val);

  bool canReceiveCircleInvitations() =>
      _prefs.getBool('${_prefix}receive_invitations') ?? true;
  Future<void> setCanReceiveCircleInvitations(bool val) =>
      _prefs.setBool('${_prefix}receive_invitations', val);

  bool isActivityVisible() =>
      _prefs.getBool('${_prefix}activity_visible') ?? true;
  Future<void> setActivityVisible(bool val) =>
      _prefs.setBool('${_prefix}activity_visible', val);

  String getDefaultMemoryVisibility() =>
      _prefs.getString('${_prefix}default_visibility') ?? 'circle';
  Future<void> setDefaultMemoryVisibility(String val) =>
      _prefs.setString('${_prefix}default_visibility', val);
}

/// One active refresh session, as reported by `GET /auth/sessions`.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.device,
    required this.isCurrent,
    required this.lastActive,
  });

  final String id;
  final String device;

  /// True for the session backing this app instance — it survives
  /// [SecuritySettingsService.signOutAllDevices].
  final bool isCurrent;
  final String lastActive;

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['jti'] as String? ?? '',
      device: _prettifyDevice(json['device'] as String?),
      isCurrent: json['current'] as bool? ?? false,
      lastActive: _relativeTime(json['lastSeenAt']),
    );
  }

  /// User agents are long; show the leading product token.
  static String _prettifyDevice(String? userAgent) {
    if (userAgent == null || userAgent.trim().isEmpty) return 'Unknown device';
    final firstToken = userAgent.split(' ').first;
    return firstToken.isEmpty ? userAgent : firstToken;
  }

  static String _relativeTime(dynamic unixSeconds) {
    if (unixSeconds is! num) return 'Unknown';
    final seen = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds.toInt() * 1000,
    );
    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// 3. SecuritySettingsService
class SecuritySettingsService {
  final SharedPreferences _prefs;
  final Dio _dio;
  static const String _prefix = 'security_';

  SecuritySettingsService(this._prefs, this._dio);

  /// Live refresh sessions for the signed-in user.
  Future<List<ActiveSession>> fetchActiveSessions() async {
    final response = await _dio.get('/auth/sessions');
    final raw =
        (response.data as Map<String, dynamic>)['sessions'] as List? ??
        const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ActiveSession.fromJson)
        .toList();
  }

  /// Revokes every other refresh session; this device stays signed in.
  /// Returns the number of sessions that were revoked.
  Future<int> signOutAllDevices() async {
    final response = await _dio.post('/auth/sessions/revoke-others');
    final body = response.data as Map<String, dynamic>? ?? const {};
    return (body['revoked'] as num?)?.toInt() ?? 0;
  }

  // Device-local: the backend has no two-factor implementation yet.
  bool isTwoFactorEnabled() => _prefs.getBool('${_prefix}2fa_enabled') ?? false;
  Future<void> setTwoFactorEnabled(bool val) =>
      _prefs.setBool('${_prefix}2fa_enabled', val);
}

// 4. AccountExportService — GDPR right to data portability.
class AccountExportService {
  final Dio _dio;

  AccountExportService(this._dio);

  /// Fetches the caller's full data export and writes it to a JSON file.
  ///
  /// The backend builds the archive synchronously, so this returns once the
  /// data is on disk. Returns `message` for display and `path` when the file
  /// was written.
  Future<Map<String, dynamic>> requestExport() async {
    final response = await _dio.get('/users/me/export');
    final data = response.data as Map<String, dynamic>;

    final memories = (data['memories'] as List?)?.length ?? 0;
    final messages = (data['messages'] as List?)?.length ?? 0;

    final path = await _writeExportFile(data);
    if (path == null) {
      return {
        'ok': true,
        'message':
            'Export ready: $memories memories, $messages messages. Could not save it to this device.',
      };
    }

    return {
      'ok': true,
      'path': path,
      'message':
          'Export saved: $memories memories, $messages messages → ${path.split(Platform.pathSeparator).last}',
    };
  }

  /// Returns the file path, or null if this device has no writable documents
  /// directory (the export itself already succeeded, so this is not fatal).
  Future<String?> _writeExportFile(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(
        '${dir.path}${Platform.pathSeparator}memory-export-$stamp.json',
      );
      await file.writeAsString(jsonEncode(data));
      return file.path;
    } catch (e) {
      StructuredLogger.log(
        'Failed to write export file: $e',
        category: 'AccountExportService',
      );
      return null;
    }
  }
}

// 5. AccountDeletionService — GDPR right to erasure.
class AccountDeletionService {
  final Ref _ref;
  final Dio _dio;

  AccountDeletionService(this._ref, this._dio);

  /// Permanently deletes the account, then signs out.
  ///
  /// The backend anonymizes the profile and soft-deletes every memory,
  /// message and circle membership inside one transaction. This is
  /// irreversible; callers must confirm with the user first.
  Future<bool> confirmDeletion() async {
    await _dio.delete('/users/me');
    await _ref.read(sessionProvider.notifier).logout();
    return true;
  }
}

// Providers
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  return AvatarUploadService(ref);
});

final privacySettingsServiceProvider = Provider<PrivacySettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrivacySettingsService(prefs);
});

final securitySettingsServiceProvider = Provider<SecuritySettingsService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecuritySettingsService(prefs, ref.watch(apiClientProvider));
});

final accountExportServiceProvider = Provider<AccountExportService>((ref) {
  return AccountExportService(ref.watch(apiClientProvider));
});

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(ref, ref.watch(apiClientProvider));
});
