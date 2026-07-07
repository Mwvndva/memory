import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/core/theme.dart'; // contains sharedPreferencesProvider
import 'package:memory_app/features/auth/auth.dart'; // contains sessionProvider

// 1. AvatarUploadService
class AvatarUploadService {
  final Ref _ref;

  AvatarUploadService(this._ref);

  Future<void> upload(Uint8List bytes) async {
    await _ref.read(sessionProvider.notifier).updateAvatar(bytes);
  }

  Future<void> uploadWithProgress(
    Uint8List bytes,
    Function(double progress) onProgress,
  ) async {
    // Simulate upload progress
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress(i / 10.0);
    }
    await upload(bytes);
  }
}

// 2. PrivacySettingsService
class PrivacySettingsService {
  final SharedPreferences _prefs;
  static const String _prefix = 'privacy_';

  PrivacySettingsService(this._prefs);

  bool isProfileVisible() => _prefs.getBool('${_prefix}profile_visible') ?? true;
  Future<void> setProfileVisible(bool val) => _prefs.setBool('${_prefix}profile_visible', val);

  bool isDiscoverable() => _prefs.getBool('${_prefix}discoverable') ?? true;
  Future<void> setDiscoverable(bool val) => _prefs.setBool('${_prefix}discoverable', val);

  bool isContactDiscoveryEnabled() => _prefs.getBool('${_prefix}contact_discovery') ?? true;
  Future<void> setContactDiscoveryEnabled(bool val) => _prefs.setBool('${_prefix}contact_discovery', val);

  bool canReceiveCircleInvitations() => _prefs.getBool('${_prefix}receive_invitations') ?? true;
  Future<void> setCanReceiveCircleInvitations(bool val) => _prefs.setBool('${_prefix}receive_invitations', val);

  bool isActivityVisible() => _prefs.getBool('${_prefix}activity_visible') ?? true;
  Future<void> setActivityVisible(bool val) => _prefs.setBool('${_prefix}activity_visible', val);

  String getDefaultMemoryVisibility() => _prefs.getString('${_prefix}default_visibility') ?? 'circle';
  Future<void> setDefaultMemoryVisibility(String val) => _prefs.setString('${_prefix}default_visibility', val);
}

// 3. SecuritySettingsService
class SecuritySettingsService {
  final SharedPreferences _prefs;
  static const String _prefix = 'security_';

  SecuritySettingsService(this._prefs);

  List<Map<String, dynamic>> getActiveSessions() {
    return [
      {'id': 'session-1', 'device': 'This Device (iPhone 15)', 'active': true, 'lastActive': 'Just now'},
      {'id': 'session-2', 'device': 'Chrome macOS', 'active': false, 'lastActive': '2 hours ago'},
    ];
  }

  Future<void> signOutAllDevices() async {
    // Simulated sign out from all other devices
    await Future.delayed(const Duration(milliseconds: 100));
  }

  bool isTwoFactorEnabled() => _prefs.getBool('${_prefix}2fa_enabled') ?? false;
  Future<void> setTwoFactorEnabled(bool val) => _prefs.setBool('${_prefix}2fa_enabled', val);

  List<Map<String, dynamic>> getLoginHistory() {
    return [
      {'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(), 'ip': '192.168.1.1', 'location': 'Nairobi, KE'},
    ];
  }
}

// 4. AccountExportService
class AccountExportService {
  Future<Map<String, dynamic>> requestExport() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'ok': true, 'exportId': 'export_123', 'status': 'pending', 'message': 'Export started. You will be notified when it is ready.'};
  }

  Future<Map<String, dynamic>> getExportStatus() async {
    return {'status': 'completed', 'downloadUrl': 'https://memory.app/exports/download/123'};
  }

  Future<Uint8List> downloadExport(String exportId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Uint8List.fromList([1, 2, 3, 4]);
  }
}

// 5. AccountDeletionService
class AccountDeletionService {
  final Ref _ref;

  AccountDeletionService(this._ref);

  Future<Map<String, dynamic>> requestDeletion({String? password}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'ok': true, 'message': 'Deletion request submitted. Please confirm.'};
  }

  Future<bool> confirmDeletion(String confirmationCode) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Request deletion success, then log out
    await _ref.read(sessionProvider.notifier).logout();
    return true;
  }

  Future<bool> cancelDeletion() async {
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

final securitySettingsServiceProvider = Provider<SecuritySettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecuritySettingsService(prefs);
});

final accountExportServiceProvider = Provider<AccountExportService>((ref) {
  return AccountExportService();
});

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(ref);
});
