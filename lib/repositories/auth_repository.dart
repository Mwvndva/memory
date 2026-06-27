import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/theme.dart';
import '../core/api_config.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import '../core/error_handler.dart';
import '../core/router.dart';
import '../media/cache_coordinator.dart';

/// Centralized Session State
class SessionState {
  final bool isAuthenticated;
  final UserProfile user;
  final String? accessToken;
  final String? refreshToken;
  final bool isRestoring;

  SessionState({
    required this.isAuthenticated,
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.isRestoring = false,
  });

  factory SessionState.empty() => SessionState(
        isAuthenticated: false,
        user: UserProfile.empty(),
      );

  SessionState copyWith({
    bool? isAuthenticated,
    UserProfile? user,
    String? accessToken,
    String? refreshToken,
    bool? isRestoring,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

/// Centralized Session Lifecycle Manager
class SessionManager extends StateNotifier<SessionState> {
  SessionManager(this._ref) : super(SessionState.empty()) {
    restoreSession();
  }

  final Ref _ref;
  static const _unavailableUsernames = {
    'admin', 'administrator', 'root', 'support', 'help',
    'memory', 'circle', 'feed', 'chat', 'dev', 'system',
  };

  /// Asynchronous session restoration on app startup
  Future<void> restoreSession() async {
    state = state.copyWith(isRestoring: true);
    try {
      final storage = _ref.read(secureStorageProvider);
      final accessToken = await storage.read(key: 'auth_token');
      final refreshToken = await storage.read(key: 'refresh_token');

      if (accessToken != null && accessToken.isNotEmpty &&
          refreshToken != null && refreshToken.isNotEmpty) {
        
        final prefs = _ref.read(sharedPreferencesProvider);
        final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
        
        UserProfile cachedUser = UserProfile.empty();
        if (isLoggedIn) {
          cachedUser = UserProfile(
            firstName: prefs.getString('user_first_name') ?? '',
            lastName: prefs.getString('user_last_name') ?? '',
            username: prefs.getString('user_username') ?? '',
            email: prefs.getString('user_email') ?? '',
            phone: prefs.getString('user_phone') ?? '',
            avatarUrl: prefs.getString('user_avatar_url'),
            isAuthenticated: true,
          );
        }

        // Optimistically set the cached state to avoid screen flicker
        state = SessionState(
          isAuthenticated: isLoggedIn,
          user: cachedUser,
          accessToken: accessToken,
          refreshToken: refreshToken,
          isRestoring: true,
        );

        // Validate the session with a fresh profile request
        try {
          final dio = _ref.read(apiClientProvider);
          final response = await dio.get('/users/me');
          final data = response.data as Map<String, dynamic>;
          final stats = data['stats'] as Map<String, dynamic>? ?? {};

          final validatedUser = UserProfile(
            firstName: data['firstName'] as String? ?? '',
            lastName:  data['lastName'] as String? ?? '',
            username:  data['username'] as String? ?? '',
            email:     data['email'] as String? ?? '',
            phone:     data['phone'] as String? ?? '',
            avatarUrl: data['avatarUrl'] as String?,
            isAuthenticated: true,
            streakDays: stats['streakDays'] as int? ?? 0,
            circlePulseDays: stats['circlePulseDays'] as int? ?? 0,
            countryRank: stats['countryRank'] as int? ?? 1,
            globalRank: stats['globalRank'] as int?,
          );

          state = SessionState(
            isAuthenticated: true,
            user: validatedUser,
            accessToken: accessToken,
            refreshToken: refreshToken,
            isRestoring: false,
          );
          _saveSession();
        } catch (e, stack) {
          // If validation fails, attempt to refresh the session immediately
          try {
            final dio = _ref.read(apiClientProvider);
            final response = await dio.post('/auth/refresh');
            final tokens = response.data['tokens'] as Map<String, dynamic>?;
            final newAccessToken = tokens != null ? tokens['access_token'] as String? : null;
            final newRefreshToken = tokens != null ? tokens['refresh_token'] as String? : null;

            if (newAccessToken != null && newRefreshToken != null) {
              await storage.write(key: 'auth_token', value: newAccessToken);
              await storage.write(key: 'refresh_token', value: newRefreshToken);

              final profileResponse = await dio.get('/users/me');
              final profileData = profileResponse.data as Map<String, dynamic>;
              final stats = profileData['stats'] as Map<String, dynamic>? ?? {};

              final validatedUser = UserProfile(
                firstName: profileData['firstName'] as String? ?? '',
                lastName:  profileData['lastName'] as String? ?? '',
                username:  profileData['username'] as String? ?? '',
                email:     profileData['email'] as String? ?? '',
                phone:     profileData['phone'] as String? ?? '',
                avatarUrl: profileData['avatarUrl'] as String?,
                isAuthenticated: true,
                streakDays: stats['streakDays'] as int? ?? 0,
                circlePulseDays: stats['circlePulseDays'] as int? ?? 0,
                countryRank: stats['countryRank'] as int? ?? 1,
                globalRank: stats['globalRank'] as int?,
              );

              state = SessionState(
                isAuthenticated: true,
                user: validatedUser,
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                isRestoring: false,
              );
              _saveSession();
            } else {
              await logoutSession();
            }
          } catch (_) {
            await logoutSession();
          }
        }
      } else {
        await logoutSession();
      }
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to restore session: $mapped');
      await logoutSession();
    } finally {
      state = state.copyWith(isRestoring: false);
    }
  }

  /// Atomic update to tokens state, triggered by AUTH-001 refresh interceptors
  void updateTokens(String accessToken, String refreshToken) {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Explicit profile updates (e.g. updating streak count on dynamic uploads)
  void updateProfile(UserProfile profile) {
    state = state.copyWith(user: profile);
    _saveSession();
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    if (kUseMockBackend) {
      final value = username.trim().replaceFirst('@', '').toLowerCase();
      if (value.length < 3) {
        return {'message': 'Use at least 3 characters.', 'ok': false};
      } else if (value.length > 30) {
        return {'message': 'Use 30 characters or fewer.', 'ok': false};
      } else if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
        return {'message': 'Only letters, numbers, periods, and underscores.', 'ok': false};
      } else if (value.startsWith('.') || value.endsWith('.') || value.contains('..')) {
        return {'message': 'Periods cannot start, end, or repeat.', 'ok': false};
      } else if (_unavailableUsernames.contains(value)) {
        return {'message': '@$value is taken.', 'ok': false};
      } else {
        return {'message': '@$value is available.', 'ok': true};
      }
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.get(
          '/auth/username-check',
          queryParameters: {'username': username},
          options: Options(extra: {'anonymous': true}),
        );
        return {
          'message': response.data['message'] ?? 'Username checked.',
          'ok': response.data['ok'] ?? false,
        };
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        return {'message': mapped.message, 'ok': false};
      }
    }
  }

  Map<String, dynamic> checkPassword(String pass, String confirm) {
    if (pass.length < 8) {
      return {'message': 'Use at least 8 characters.', 'ok': false};
    }
    return {'message': 'Looks strong.', 'ok': true};
  }

  Future<Map<String, dynamic>> createAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required bool acceptedTerms,
  }) async {
    final cleanUsername = username.replaceFirst('@', '');
    if (kUseMockBackend) {
      final mockUser = UserProfile(
        firstName: firstName,
        lastName: lastName,
        username: cleanUsername,
        email: email,
        phone: phone,
        isAuthenticated: false,
      );
      state = SessionState(
        isAuthenticated: false,
        user: mockUser,
      );
      return {'ok': true, 'message': 'Registered (mock)'};
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.post(
          '/auth/register',
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'username': cleanUsername,
            'email': email,
            'phone': phone,
            'password': password,
            'accepted_terms': acceptedTerms,
          },
          options: Options(extra: {'anonymous': true}),
        );

        final tokens = response.data['tokens'] as Map<String, dynamic>?;
        final accessToken = tokens != null ? tokens['access_token'] as String? : null;
        final refreshToken = tokens != null ? tokens['refresh_token'] as String? : null;
        final userJson = response.data['user'] as Map<String, dynamic>? ?? {};

        final user = UserProfile(
          firstName: userJson['first_name'] ?? firstName,
          lastName:  userJson['last_name']  ?? lastName,
          username:  userJson['username']   ?? cleanUsername,
          email:     userJson['email']      ?? email,
          phone:     userJson['phone']      ?? phone,
          isAuthenticated: false, // still needs avatar upload
        );

        if (accessToken != null && refreshToken != null) {
          final storage = _ref.read(secureStorageProvider);
          await storage.write(key: 'auth_token', value: accessToken);
          await storage.write(key: 'refresh_token', value: refreshToken);
        }

        state = SessionState(
          isAuthenticated: false,
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        return {'ok': true, 'message': response.data['message'] ?? 'Registered'};
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        return {
          'ok': false,
          'message': mapped.message,
          'status': e is DioException ? e.response?.statusCode : null,
        };
      }
    }
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    state = state.copyWith(user: state.user.copyWith(avatarBytes: bytes));
    if (kUseMockBackend) return;
    try {
      final dio = _ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'avatar.jpg',
        ),
      });
      await dio.post('/users/me/avatar', data: formData);
      await fetchProfile();
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      throw mapped;
    }
  }

  Future<bool> login(String id, String password) async {
    final cleanId = id.trim().replaceFirst('@', '').toLowerCase();

    if (kUseMockBackend) {
      final matchLocal = (cleanId == state.user.username.toLowerCase() || cleanId == state.user.email.toLowerCase());
      final matchDefault = (cleanId == 'roykeepsmemories' || cleanId == 'roy@memory.app');

      if (matchLocal || matchDefault) {
        UserProfile mockUser;
        if (state.user.username.isEmpty) {
          mockUser = const UserProfile(
            firstName: 'Roy',
            lastName: 'Nthiga',
            username: 'roykeepsmemories',
            email: 'roy@memory.app',
            phone: '+254 712 345 678',
            isAuthenticated: true,
          );
        } else {
          mockUser = state.user.copyWith(isAuthenticated: true);
        }

        state = SessionState(
          isAuthenticated: true,
          user: mockUser,
          accessToken: 'mock_access_token',
          refreshToken: 'mock_refresh_token',
        );

        _saveSession();
        return true;
      }
      return false;
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.post(
          '/auth/login',
          data: {
            'identity': cleanId,
            'password': password,
          },
          options: Options(extra: {'anonymous': true}),
        );

        final tokens = response.data['tokens'] as Map<String, dynamic>?;
        final accessToken = tokens != null ? tokens['access_token'] as String? : null;
        final refreshToken = tokens != null ? tokens['refresh_token'] as String? : null;
        final userJson = response.data['user'] as Map<String, dynamic>?;

        if (accessToken != null && refreshToken != null && userJson != null) {
          final storage = _ref.read(secureStorageProvider);
          await storage.write(key: 'auth_token', value: accessToken);
          await storage.write(key: 'refresh_token', value: refreshToken);

          final user = UserProfile(
            firstName: userJson['first_name'] ?? '',
            lastName:  userJson['last_name']  ?? '',
            username:  userJson['username']   ?? '',
            email:     userJson['email']      ?? '',
            phone:     userJson['phone']      ?? '',
            avatarUrl: userJson['avatar_url'] as String?,
            isAuthenticated: true,
          );

          state = SessionState(
            isAuthenticated: true,
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          _saveSession();
          return true;
        }
        return false;
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        throw mapped;
      }
    }
  }

  Future<void> fetchProfile() async {
    if (kUseMockBackend) return;
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/users/me');
      final data = response.data as Map<String, dynamic>;
      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      final validatedUser = UserProfile(
        firstName: data['firstName'] as String? ?? '',
        lastName:  data['lastName'] as String? ?? '',
        username:  data['username'] as String? ?? '',
        email:     data['email'] as String? ?? '',
        phone:     data['phone'] as String? ?? '',
        avatarBytes: state.user.avatarBytes,
        avatarUrl: data['avatarUrl'] as String?,
        isAuthenticated: true,
        streakDays: stats['streakDays'] as int? ?? 0,
        circlePulseDays: stats['circlePulseDays'] as int? ?? 0,
        countryRank: stats['countryRank'] as int? ?? 1,
        globalRank: stats['globalRank'] as int?,
      );

      state = state.copyWith(user: validatedUser);
      _saveSession();
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to fetch profile: $mapped');
    }
  }

  void authenticate() {
    state = state.copyWith(isAuthenticated: true, user: state.user.copyWith(isAuthenticated: true));
    _saveSession();
  }

  Future<void> logoutSession() async {
    state = SessionState.empty();
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final storage = _ref.read(secureStorageProvider);
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'refresh_token');
      await prefs.remove('is_logged_in');
      await prefs.remove('user_first_name');
      await prefs.remove('user_last_name');
      await prefs.remove('user_username');
      await prefs.remove('user_email');
      await prefs.remove('user_phone');
      await prefs.remove('user_avatar_url');
      _ref.read(cacheCoordinatorProvider).clearAll();
    } catch (e) {
      debugPrint('Error clearing secure storage/shared preferences: $e');
    }
  }

  Future<void> logout() => logoutSession();

  Future<void> handleSessionExpired() async {
    await logoutSession();
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      showAppError(context, 'Your session has expired. Please sign in again.');
    }
  }

  void _saveSession() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      prefs.setBool('is_logged_in', true);
      prefs.setString('user_first_name', state.user.firstName);
      prefs.setString('user_last_name', state.user.lastName);
      prefs.setString('user_username', state.user.username);
      prefs.setString('user_email', state.user.email);
      prefs.setString('user_phone', state.user.phone);
      if (state.user.avatarUrl != null) {
        prefs.setString('user_avatar_url', state.user.avatarUrl!);
      } else {
        prefs.remove('user_avatar_url');
      }
    } catch (e) {
      debugPrint('Failed to save session to SharedPreferences: $e');
    }
  }
}

/// Centralized session state provider
final sessionProvider = StateNotifierProvider<SessionManager, SessionState>((ref) {
  return SessionManager(ref);
});

/// Derived provider to preserve the existing authProvider interface contract
final authProvider = Provider<UserProfile>((ref) {
  return ref.watch(sessionProvider).user;
});
