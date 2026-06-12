import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/api_config.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';

class AuthNotifier extends StateNotifier<UserProfile> {
  AuthNotifier(this._ref) : super(UserProfile.empty()) {
    _loadSession();
  }

  final Ref _ref;
  final _unavailableUsernames = {'roy', 'memory', 'amara', 'leo', 'mum'};

  void _loadSession() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (isLoggedIn) {
        state = UserProfile(
          firstName: prefs.getString('user_first_name') ?? 'Roy',
          lastName: prefs.getString('user_last_name') ?? 'Nthiga',
          username: prefs.getString('user_username') ?? 'roykeepsmemories',
          email: prefs.getString('user_email') ?? 'roy@memory.app',
          phone: prefs.getString('user_phone') ?? '+254 712 345 678',
          isAuthenticated: true,
        );
      }
    } catch (_) {
      // SharedPreferences might not be ready in testing/fallback
    }
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
        final response = await dio.get('/auth/username-check', queryParameters: {'username': username});
        return {
          'message': response.data['message'] ?? 'Username checked.',
          'ok': response.data['ok'] ?? false,
        };
      } catch (e) {
        return {'message': 'Error checking username availability.', 'ok': false};
      }
    }
  }

  Map<String, dynamic> checkPassword(String pass, String confirm) {
    if (pass.length < 8) {
      return {'message': 'Use at least 8 characters.', 'ok': false};
    } else if (!RegExp('[A-Z]').hasMatch(pass) || !RegExp('[a-z]').hasMatch(pass)) {
      return {'message': 'Use uppercase and lowercase letters.', 'ok': false};
    } else if (pass != confirm) {
      return {'message': 'Passwords do not match.', 'ok': false};
    } else {
      return {'message': 'Passwords match.', 'ok': true};
    }
  }

  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanUsername = username.replaceFirst('@', '');
    if (kUseMockBackend) {
      state = UserProfile(
        firstName: firstName,
        lastName: lastName,
        username: cleanUsername,
        email: email,
        phone: phone,
        isAuthenticated: false,
      );
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.post('/auth/register', data: {
          'first_name': firstName,
          'last_name': lastName,
          'username': cleanUsername,
          'email': email,
          'phone': phone,
          'password': password,
        });

        final token = response.data['token'];
        final userJson = response.data['user'] as Map<String, dynamic>? ?? {};
        if (token != null) {
          final storage = _ref.read(secureStorageProvider);
          await storage.write(key: 'auth_token', value: token);
        }

        state = UserProfile(
          firstName: userJson['first_name'] ?? firstName,
          lastName:  userJson['last_name']  ?? lastName,
          username:  userJson['username']   ?? cleanUsername,
          email:     userJson['email']      ?? email,
          phone:     userJson['phone']      ?? phone,
          isAuthenticated: false, // still needs avatar step
        );
      } catch (e) {
        rethrow;
      }
    }
  }

  void updateAvatar(Uint8List bytes) {
    state = state.copyWith(avatarBytes: bytes);
  }

  Future<bool> login(String id, String password) async {
    final cleanId = id.trim().replaceFirst('@', '').toLowerCase();

    if (kUseMockBackend) {
      final matchLocal = (cleanId == state.username || cleanId == state.email.toLowerCase());
      final matchDefault = (cleanId == 'roykeepsmemories' || cleanId == 'roy@memory.app');

      if (matchLocal || matchDefault) {
        if (state.username.isEmpty) {
          state = const UserProfile(
            firstName: 'Roy',
            lastName: 'Nthiga',
            username: 'roykeepsmemories',
            email: 'roy@memory.app',
            phone: '+254 712 345 678',
            isAuthenticated: true,
          );
        } else {
          state = state.copyWith(isAuthenticated: true);
        }

        _saveSession();
        return true;
      }
      return false;
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.post('/auth/login', data: {
          'identity': cleanId,
          'password': password,
        });

        final token = response.data['token'] as String?;
        final userJson = response.data['user'] as Map<String, dynamic>?;

        if (token != null && userJson != null) {
          final storage = _ref.read(secureStorageProvider);
          await storage.write(key: 'auth_token', value: token);

          state = UserProfile(
            firstName: userJson['first_name'] ?? '',
            lastName:  userJson['last_name']  ?? '',
            username:  userJson['username']   ?? '',
            email:     userJson['email']      ?? '',
            phone:     userJson['phone']      ?? '',
            isAuthenticated: true,
          );
          _saveSession();
          return true;
        }
        return false;
      } catch (e) {
        return false;
      }
    }
  }

  void authenticate() {
    state = state.copyWith(isAuthenticated: true);
    _saveSession();
  }

  void logout() {
    state = UserProfile.empty();
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      _ref.read(secureStorageProvider).delete(key: 'auth_token');
      prefs.remove('is_logged_in');
      prefs.remove('user_first_name');
      prefs.remove('user_last_name');
      prefs.remove('user_username');
      prefs.remove('user_email');
      prefs.remove('user_phone');
    } catch (_) {}
  }

  void _saveSession() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      prefs.setBool('is_logged_in', true);
      prefs.setString('user_first_name', state.firstName);
      prefs.setString('user_last_name', state.lastName);
      prefs.setString('user_username', state.username);
      prefs.setString('user_email', state.email);
      prefs.setString('user_phone', state.phone);
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile>((ref) {
  return AuthNotifier(ref);
});
