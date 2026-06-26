import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
          firstName: prefs.getString('user_first_name') ?? '',
          lastName: prefs.getString('user_last_name') ?? '',
          username: prefs.getString('user_username') ?? '',
          email: prefs.getString('user_email') ?? '',
          phone: prefs.getString('user_phone') ?? '',
          avatarUrl: prefs.getString('user_avatar_url'),
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
    // Adopt a stricter policy similar to major platforms:
    // - at least 8 characters
    // - at least one uppercase letter
    // - at least one lowercase letter
    // - at least one digit
    // - at least one special character
    if (pass.length < 8) {
      return {'message': 'Use at least 8 characters.', 'ok': false};
    }

    if (!RegExp(r'[A-Z]').hasMatch(pass)) {
      return {'message': 'Use at least one uppercase letter.', 'ok': false};
    }

    if (!RegExp(r'[a-z]').hasMatch(pass)) {
      return {'message': 'Use at least one lowercase letter.', 'ok': false};
    }

    if (!RegExp(r'\d').hasMatch(pass)) {
      return {'message': 'Use at least one number.', 'ok': false};
    }

    if (!RegExp(r'[!@#\$%\^&*(),.?":{}|<>~`_\-\\/\[\];\+=]').hasMatch(pass)) {
      return {'message': 'Use at least one special character.', 'ok': false};
    }

    if (pass != confirm) {
      return {'message': 'Passwords do not match.', 'ok': false};
    }

    return {'message': 'Passwords match.', 'ok': true};
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
      state = UserProfile(
        firstName: firstName,
        lastName: lastName,
        username: cleanUsername,
        email: email,
        phone: phone,
        isAuthenticated: false,
      );
      return {'ok': true, 'message': 'Registered (mock)'};
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
          'accepted_terms': acceptedTerms,
        });

        final tokens = response.data['tokens'] as Map<String, dynamic>?;
        final token = tokens != null ? tokens['access_token'] as String? : null;
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
        return {'ok': true, 'message': response.data['message'] ?? 'Registered'};
      } on DioException catch (e) {
        // Parse common backend error responses and return friendly messages.
        final status = e.response?.statusCode;
        String msg = 'Registration failed.';
        if (status == 409) {
          // Conflict (e.g., username or email already exists)
          try {
            final data = e.response?.data;
            if (data is Map && data['message'] != null) {
              msg = data['message'].toString();
            } else if (data is String && data.isNotEmpty) {
              msg = data;
            } else {
              msg = 'Username or email already exists.';
            }
          } catch (_) {
            msg = 'Username or email already exists.';
          }
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          msg = 'Network timeout. Please try again.';
        } else if (e.response != null && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data['message'] != null) msg = data['message'].toString();
        } else {
          msg = e.message ?? 'An unexpected error occurred.';
        }
        return {'ok': false, 'message': msg, 'status': status};
      } catch (e) {
        return {'ok': false, 'message': e.toString()};
      }
    }
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    state = state.copyWith(avatarBytes: bytes);
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
    } catch (_) {}
  }

  Future<bool> login(String id, String password) async {
    final cleanId = id.trim().replaceFirst('@', '').toLowerCase();

    if (kUseMockBackend) {
      final matchLocal = (cleanId == state.username.toLowerCase() || cleanId == state.email.toLowerCase());
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

        final tokens = response.data['tokens'] as Map<String, dynamic>?;
        final token = tokens != null ? tokens['access_token'] as String? : null;
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
            avatarUrl: userJson['avatar_url'] as String?,
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

  Future<void> fetchProfile() async {
    if (kUseMockBackend) return;
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/users/me');
      final data = response.data as Map<String, dynamic>;
      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      state = UserProfile(
        firstName: data['firstName'] as String? ?? '',
        lastName:  data['lastName'] as String? ?? '',
        username:  data['username'] as String? ?? '',
        email:     data['email'] as String? ?? '',
        phone:     data['phone'] as String? ?? '',
        avatarBytes: state.avatarBytes,
        avatarUrl: data['avatarUrl'] as String?,
        isAuthenticated: true,
        streakDays: stats['streakDays'] as int? ?? 0,
        circlePulseDays: stats['circlePulseDays'] as int? ?? 0,
        countryRank: stats['countryRank'] as int? ?? 1,
        globalRank: stats['globalRank'] as int?,
      );
      _saveSession();
    } catch (_) {}
  }

  void authenticate() {
    state = state.copyWith(isAuthenticated: true);
    _saveSession();
  }

  Future<void> logout() async {
    state = UserProfile.empty();
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await _ref.read(secureStorageProvider).delete(key: 'auth_token');
      await prefs.remove('is_logged_in');
      await prefs.remove('user_first_name');
      await prefs.remove('user_last_name');
      await prefs.remove('user_username');
      await prefs.remove('user_email');
      await prefs.remove('user_phone');
      await prefs.remove('user_avatar_url');
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
      if (state.avatarUrl != null) {
        prefs.setString('user_avatar_url', state.avatarUrl!);
      } else {
        prefs.remove('user_avatar_url');
      }
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile>((ref) {
  return AuthNotifier(ref);
});
