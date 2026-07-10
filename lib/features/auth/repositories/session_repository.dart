import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/secure_storage.dart';
import 'package:memory_app/core/theme.dart'; // contains sharedPreferencesProvider
import 'package:memory_app/features/circle/circle.dart';

class SessionRepository {
  final Ref _ref;

  SessionRepository(this._ref);

  /// Key names for storage
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _firstNameKey = 'user_first_name';
  static const String _lastNameKey = 'user_last_name';
  static const String _usernameKey = 'user_username';
  static const String _emailKey = 'user_email';
  static const String _phoneKey = 'user_phone';
  static const String _avatarUrlKey = 'user_avatar_url';

  /// Reads cached access token from secure storage.
  Future<String?> getAccessToken() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      return await storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Failed to read access token from secure storage: $e');
      return null;
    }
  }

  /// Reads cached refresh token from secure storage.
  Future<String?> getRefreshToken() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      return await storage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('Failed to read refresh token from secure storage: $e');
      return null;
    }
  }

  /// Writes access and refresh tokens into secure storage.
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      final storage = _ref.read(secureStorageProvider);
      await storage.write(key: _tokenKey, value: accessToken);
      await storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (e) {
      debugPrint('Failed to write tokens to secure storage: $e');
    }
  }

  /// Clears tokens from secure storage.
  Future<void> clearTokens() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      await storage.delete(key: _tokenKey);
      await storage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('Failed to clear tokens from secure storage: $e');
    }
  }

  /// Retrieves user profile cached in SharedPreferences.
  Future<UserProfile?> getCachedUserProfile() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      if (!isLoggedIn) return null;

      return UserProfile(
        firstName: prefs.getString(_firstNameKey) ?? '',
        lastName: prefs.getString(_lastNameKey) ?? '',
        username: prefs.getString(_usernameKey) ?? '',
        email: prefs.getString(_emailKey) ?? '',
        phone: prefs.getString(_phoneKey) ?? '',
        avatarUrl: prefs.getString(_avatarUrlKey),
        isAuthenticated: true,
      );
    } catch (e) {
      debugPrint('Failed to retrieve user profile from SharedPreferences: $e');
      return null;
    }
  }

  /// Caches the user profile to SharedPreferences.
  Future<void> saveCachedUserProfile(UserProfile profile) async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_firstNameKey, profile.firstName);
      await prefs.setString(_lastNameKey, profile.lastName);
      await prefs.setString(_usernameKey, profile.username);
      await prefs.setString(_emailKey, profile.email);
      await prefs.setString(_phoneKey, profile.phone);

      if (profile.avatarUrl != null) {
        await prefs.setString(_avatarUrlKey, profile.avatarUrl!);
      } else {
        await prefs.remove(_avatarUrlKey);
      }
    } catch (e) {
      debugPrint('Failed to save user profile to SharedPreferences: $e');
    }
  }

  /// Completely clears tokens and user preferences/flags.
  Future<void> clearSession() async {
    try {
      await clearTokens();
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_firstNameKey);
      await prefs.remove(_lastNameKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_phoneKey);
      await prefs.remove(_avatarUrlKey);
    } catch (e) {
      debugPrint('Failed to clear session from SharedPreferences: $e');
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref);
});
