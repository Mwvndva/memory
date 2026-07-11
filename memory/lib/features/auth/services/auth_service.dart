import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/circle/circle.dart';

class AuthenticationService {
  final Dio _dio;

  AuthenticationService(this._dio);

  static const _unavailableUsernames = {
    'admin',
    'administrator',
    'root',
    'support',
    'help',
    'memory',
    'circle',
    'feed',
    'chat',
    'dev',
    'system',
  };

  /// Validates availability of a username on the backend.
  Future<Map<String, dynamic>> checkUsername(String username) async {
    final value = username.trim().replaceFirst('@', '').toLowerCase();

    if (kUseMockBackend) {
      if (value.length < 3) {
        return {'message': 'Use at least 3 characters.', 'ok': false};
      } else if (value.length > 30) {
        return {'message': 'Use 30 characters or fewer.', 'ok': false};
      } else if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
        return {
          'message': 'Only letters, numbers, periods, and underscores.',
          'ok': false,
        };
      } else if (value.startsWith('.') ||
          value.endsWith('.') ||
          value.contains('..')) {
        return {
          'message': 'Periods cannot start, end, or repeat.',
          'ok': false,
        };
      } else if (_unavailableUsernames.contains(value)) {
        return {'message': '@$value is taken.', 'ok': false};
      } else {
        return {'message': '@$value is available.', 'ok': true};
      }
    }

    try {
      final response = await _dio.get(
        '/auth/username-check',
        queryParameters: {'username': value},
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

  /// Sends register request to the backend.
  Future<AuthResponseDto> register(RegisterRequestDto request) async {
    if (kUseMockBackend) {
      return AuthResponseDto(
        message: 'Registered (mock)',
        user: UserDto(
          firstName: request.firstName,
          lastName: request.lastName,
          username: request.username,
          email: request.email,
          phone: request.phone,
        ),
        tokens: TokenDto(
          accessToken: 'mock_access_token',
          refreshToken: 'mock_refresh_token',
        ),
      );
    }

    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
        options: Options(extra: {'anonymous': true}),
      );
      return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  /// Sends login request to the backend.
  Future<AuthResponseDto> login(LoginRequestDto request) async {
    if (kUseMockBackend) {
      return AuthResponseDto(
        message: 'Logged in (mock)',
        user: UserDto(
          firstName: 'Roy',
          lastName: 'Nthiga',
          username: 'roykeepsmemories',
          email: 'roy@memory.app',
          phone: '+254 712 345 678',
        ),
        tokens: TokenDto(
          accessToken: 'mock_access_token',
          refreshToken: 'mock_refresh_token',
        ),
      );
    }

    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
        options: Options(extra: {'anonymous': true}),
      );
      return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  /// Refreshes access and refresh tokens.
  Future<TokenDto> refreshTokens() async {
    if (kUseMockBackend) {
      return TokenDto(
        accessToken: 'mock_access_token',
        refreshToken: 'mock_refresh_token',
      );
    }

    try {
      final response = await _dio.post('/auth/refresh');
      final tokens = response.data['tokens'] as Map<String, dynamic>?;
      if (tokens == null) {
        throw AuthenticationException('Invalid tokens response from server.');
      }
      return TokenDto.fromJson(tokens);
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  /// Updates user avatar on the backend.
  Future<void> updateAvatar(Uint8List bytes) async {
    if (kUseMockBackend) return;

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'avatar.jpg'),
      });
      await _dio.post('/users/me/avatar', data: formData);
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  /// Fetches current user profile details from backend.
  Future<UserProfile> fetchProfile({Uint8List? avatarBytes}) async {
    if (kUseMockBackend) {
      return const UserProfile(
        firstName: 'Roy',
        lastName: 'Nthiga',
        username: 'roykeepsmemories',
        email: 'roy@memory.app',
        phone: '+254 712 345 678',
        isAuthenticated: true,
      );
    }

    try {
      final response = await _dio.get('/users/me');
      final data = response.data as Map<String, dynamic>;
      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      return UserProfile(
        firstName:
            data['firstName'] as String? ?? data['first_name'] as String? ?? '',
        lastName:
            data['lastName'] as String? ?? data['last_name'] as String? ?? '',
        username: data['username'] as String? ?? '',
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        avatarBytes: avatarBytes,
        avatarUrl:
            data['avatarUrl'] as String? ?? data['avatar_url'] as String?,
        isAuthenticated: true,
        streakDays:
            stats['streakDays'] as int? ?? stats['streak_days'] as int? ?? 0,
        circlePulseDays:
            stats['circlePulseDays'] as int? ??
            stats['circle_pulse_days'] as int? ??
            0,
        countryRank:
            stats['countryRank'] as int? ?? stats['country_rank'] as int? ?? 1,
        globalRank: stats['globalRank'] as int? ?? stats['global_rank'] as int?,
      );
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  /// Sends contacts sync request to the backend.
  Future<List<CircleMember>> syncContacts(List<String> phones) async {
    if (kUseMockBackend) {
      return const [
        CircleMember(id: 'mock_amara', username: 'amara', firstName: 'Amara'),
        CircleMember(
          id: 'mock_mum',
          username: 'mumsmemories',
          firstName: 'Mum',
        ),
      ];
    }

    try {
      final response = await _dio.post(
        '/users/sync-contacts',
        data: {'phones': phones},
      );
      final rawList = response.data as List? ?? [];
      return rawList
          .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }
}

final authServiceProvider = Provider<AuthenticationService>((ref) {
  final dio = ref.read(apiClientProvider);
  return AuthenticationService(dio);
});
