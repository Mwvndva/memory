import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';

/// Serves the four backend endpoints the profile screen depends on.
class _ProfileApiInterceptor extends Interceptor {
  static int deleteMeCalls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    if (path == '/auth/sessions' && options.method == 'GET') {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'sessions': [
              {
                'jti': 'jti-current',
                'device': 'MemoryApp/1.0 (Android 14)',
                'lastSeenAt': now,
                'current': true,
              },
              {
                'jti': 'jti-other',
                'device': 'Chrome/120.0',
                'lastSeenAt': now - 7200,
                'current': false,
              },
            ],
          },
        ),
      );
      return;
    }

    if (path == '/auth/sessions/revoke-others' && options.method == 'POST') {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'revoked': 3},
        ),
      );
      return;
    }

    if (path == '/users/me/export' && options.method == 'GET') {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'profile': {'id': 'u1', 'username': 'amara'},
            'memories': [
              {'id': 'm1'},
              {'id': 'm2'},
            ],
            'messages': [
              {'id': 'msg1'},
            ],
          },
        ),
      );
      return;
    }

    if (path == '/users/me' && options.method == 'DELETE') {
      deleteMeCalls++;
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'message': 'Account deleted'},
        ),
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        error: 'Unexpected request: ${options.method} $path',
      ),
    );
  }
}

Dio _mockDio() =>
    Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..interceptors.add(_ProfileApiInterceptor());

class FakeSessionManager extends StateNotifier<SessionState>
    implements SessionManager {
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
    _ProfileApiInterceptor.deleteMeCalls = 0;
  });

  test('PrivacySettingsService sets and gets values properly', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
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

  test(
    'SecuritySettingsService keeps two-factor preference on device',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          apiClientProvider.overrideWithValue(_mockDio()),
        ],
      );

      final securityService = container.read(securitySettingsServiceProvider);

      expect(securityService.isTwoFactorEnabled(), false);
      await securityService.setTwoFactorEnabled(true);
      expect(securityService.isTwoFactorEnabled(), true);
    },
  );

  test(
    'SecuritySettingsService lists live sessions and flags the current one',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          apiClientProvider.overrideWithValue(_mockDio()),
        ],
      );

      final sessions = await container
          .read(securitySettingsServiceProvider)
          .fetchActiveSessions();

      expect(sessions.length, 2);
      expect(sessions[0].id, 'jti-current');
      expect(sessions[0].isCurrent, true);
      expect(sessions[0].device, 'MemoryApp/1.0');
      expect(sessions[1].isCurrent, false);
    },
  );

  test(
    'SecuritySettingsService signOutAllDevices reports revoked count',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          apiClientProvider.overrideWithValue(_mockDio()),
        ],
      );

      final revoked = await container
          .read(securitySettingsServiceProvider)
          .signOutAllDevices();

      expect(revoked, 3);
    },
  );

  test('AccountExportService fetches the export and summarises it', () async {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_mockDio())],
    );

    final res = await container
        .read(accountExportServiceProvider)
        .requestExport();

    expect(res['ok'], true);
    // path_provider has no platform channel under `flutter test`, so the file
    // write degrades gracefully and only the summary is asserted here.
    expect(res['message'], contains('2 memories'));
    expect(res['message'], contains('1 messages'));
  });

  test('AccountDeletionService deletes the account, then logs out', () async {
    final fakeSessionManager = FakeSessionManager();
    final dio = _mockDio();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => fakeSessionManager),
        apiClientProvider.overrideWithValue(dio),
      ],
    );

    final deletionService = container.read(accountDeletionServiceProvider);

    expect(await deletionService.confirmDeletion(), true);
    // The DELETE must reach the backend — logging out alone is not deletion.
    expect(_ProfileApiInterceptor.deleteMeCalls, 1);
    expect(fakeSessionManager.state.isAuthenticated, false);
  });

  test('AvatarUploadService uploads the bytes through the session', () async {
    final fakeSessionManager = FakeSessionManager();
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith((ref) => fakeSessionManager)],
    );

    final avatarService = container.read(avatarUploadServiceProvider);
    final bytes = Uint8List.fromList([10, 20, 30]);

    await avatarService.upload(bytes);

    expect(fakeSessionManager.uploadedAvatarBytes, bytes);
  });
}
