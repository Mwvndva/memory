import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/services/profile_services.dart';
import 'package:memory_app/repositories/auth_repository.dart';
import 'package:memory_app/models/user_profile.dart';

import 'package:memory_app/repositories/circles_repository.dart';

class FakeSessionManager extends StateNotifier<SessionState> implements SessionManager {
  FakeSessionManager() : super(SessionState.empty());
  Uint8List? uploadedAvatarBytes;


  @override
  Future<void> updateAvatar(Uint8List bytes) async {
    uploadedAvatarBytes = bytes;
  }

  @override
  Future<void> logout() async {
    state = SessionState.empty();
  }

  @override
  Future<void> restoreSession() async {}

  @override
  void updateTokens(String accessToken, String refreshToken) {}

  @override
  void updateProfile(UserProfile profile) {}

  @override
  Future<Map<String, dynamic>> checkUsername(String username) async => {};

  @override
  Map<String, dynamic> checkPassword(String pass, String confirm) => {};

  @override
  Future<Map<String, dynamic>> createAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required bool acceptedTerms,
  }) async => {};

  @override
  Future<bool> login(String id, String password) async => true;

  @override
  Future<void> fetchProfile() async {}

  @override
  Future<List<CircleMember>> syncContacts(List<String> phones) async => [];

  @override
  void authenticate() {}

  @override
  Future<void> logoutSession() async {}

  @override
  Future<void> handleSessionExpired() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PrivacySettingsService sets and gets values properly', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ],
    );

    final privacyService = container.read(privacySettingsServiceProvider);
    
    expect(privacyService.isProfileVisible(), true);
    expect(privacyService.isDiscoverable(), true);
    expect(privacyService.isContactDiscoveryEnabled(), true);
    expect(privacyService.canReceiveCircleInvitations(), true);
    expect(privacyService.isActivityVisible(), true);
    expect(privacyService.getDefaultMemoryVisibility(), 'circle');

    await privacyService.setProfileVisible(false);
    await privacyService.setDiscoverable(false);
    await privacyService.setContactDiscoveryEnabled(false);
    await privacyService.setCanReceiveCircleInvitations(false);
    await privacyService.setActivityVisible(false);
    await privacyService.setDefaultMemoryVisibility('only_me');

    expect(privacyService.isProfileVisible(), false);
    expect(privacyService.isDiscoverable(), false);
    expect(privacyService.isContactDiscoveryEnabled(), false);
    expect(privacyService.canReceiveCircleInvitations(), false);
    expect(privacyService.isActivityVisible(), false);
    expect(privacyService.getDefaultMemoryVisibility(), 'only_me');
  });

  test('SecuritySettingsService active sessions and 2fa', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ],
    );

    final securityService = container.read(securitySettingsServiceProvider);

    expect(securityService.isTwoFactorEnabled(), false);
    await securityService.setTwoFactorEnabled(true);
    expect(securityService.isTwoFactorEnabled(), true);

    final sessions = securityService.getActiveSessions();
    expect(sessions.length, 2);
    expect(sessions[0]['device'], 'This Device (iPhone 15)');

    final history = securityService.getLoginHistory();
    expect(history.length, 1);
    expect(history[0]['location'], 'Nairobi, KE');
  });

  test('AccountExportService simulation', () async {
    final container = ProviderContainer();
    final exportService = container.read(accountExportServiceProvider);

    final res = await exportService.requestExport();
    expect(res['ok'], true);
    expect(res['exportId'], 'export_123');

    final status = await exportService.getExportStatus();
    expect(status['status'], 'completed');

    final data = await exportService.downloadExport('export_123');
    expect(data.length, 4);
  });

  test('AccountDeletionService logs out on confirmation', () async {
    final fakeSessionManager = FakeSessionManager();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => fakeSessionManager),
      ],
    );

    final deletionService = container.read(accountDeletionServiceProvider);
    
    final res = await deletionService.requestDeletion(password: 'secret');
    expect(res['ok'], true);

    final success = await deletionService.confirmDeletion('123456');
    expect(success, true);
  });

  test('AvatarUploadService simulates progress and uploads', () async {
    final fakeSessionManager = FakeSessionManager();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => fakeSessionManager),
      ],
    );

    final avatarService = container.read(avatarUploadServiceProvider);
    final bytes = Uint8List.fromList([10, 20, 30]);

    double lastProgress = 0.0;
    await avatarService.uploadWithProgress(bytes, (progress) {
      lastProgress = progress;
    });

    expect(lastProgress, 1.0);
    expect(fakeSessionManager.uploadedAvatarBytes, bytes);
  });
}
