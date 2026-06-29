import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/error_handler.dart';
import '../core/router.dart';
import '../core/api_config.dart';
import '../models/user_profile.dart';
import '../models/dto/auth_dtos.dart';
import '../services/auth_service.dart';
import '../media/cache_coordinator.dart';
import 'session_repository.dart';
import 'circles_repository.dart';
import 'package:dio/dio.dart';

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

class SessionManager extends StateNotifier<SessionState> {
  SessionManager(this._ref) : super(SessionState.empty()) {
    restoreSession();
  }

  final Ref _ref;

  /// Asynchronous session restoration on app startup
  Future<void> restoreSession() async {
    state = state.copyWith(isRestoring: true);
    try {
      final sessionRepo = _ref.read(sessionRepositoryProvider);
      final accessToken = await sessionRepo.getAccessToken();
      final refreshToken = await sessionRepo.getRefreshToken();

      if (accessToken != null && accessToken.isNotEmpty &&
          refreshToken != null && refreshToken.isNotEmpty) {
        
        final cachedUser = await sessionRepo.getCachedUserProfile() ?? UserProfile.empty();

        // Optimistically set the cached state to avoid screen flicker
        state = SessionState(
          isAuthenticated: cachedUser.isAuthenticated,
          user: cachedUser,
          accessToken: accessToken,
          refreshToken: refreshToken,
          isRestoring: true,
        );

        // Validate the session with a fresh profile request
        try {
          final authService = _ref.read(authServiceProvider);
          final validatedUser = await authService.fetchProfile();

          state = SessionState(
            isAuthenticated: true,
            user: validatedUser,
            accessToken: accessToken,
            refreshToken: refreshToken,
            isRestoring: false,
          );
          await sessionRepo.saveCachedUserProfile(validatedUser);
        } catch (e, stack) {
          // If validation fails, attempt to refresh the session immediately
          try {
            final authService = _ref.read(authServiceProvider);
            final tokenDto = await authService.refreshTokens();

            await sessionRepo.saveTokens(tokenDto.accessToken, tokenDto.refreshToken);
            updateTokens(tokenDto.accessToken, tokenDto.refreshToken);

            final validatedUser = await authService.fetchProfile();

            state = SessionState(
              isAuthenticated: true,
              user: validatedUser,
              accessToken: tokenDto.accessToken,
              refreshToken: tokenDto.refreshToken,
              isRestoring: false,
            );
            await sessionRepo.saveCachedUserProfile(validatedUser);
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
    _ref.read(sessionRepositoryProvider).saveCachedUserProfile(profile);
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    return _ref.read(authServiceProvider).checkUsername(username);
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
    try {
      final request = RegisterRequestDto(
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        phone: phone,
        password: password,
        acceptedTerms: acceptedTerms,
      );

      final authService = _ref.read(authServiceProvider);
      final responseDto = await authService.register(request);

      final user = UserProfile(
        firstName: responseDto.user.firstName,
        lastName: responseDto.user.lastName,
        username: responseDto.user.username,
        email: responseDto.user.email,
        phone: responseDto.user.phone,
        avatarUrl: responseDto.user.avatarUrl,
        isAuthenticated: false, // still needs avatar upload
      );

      if (responseDto.tokens != null) {
        final sessionRepo = _ref.read(sessionRepositoryProvider);
        await sessionRepo.saveTokens(
          responseDto.tokens!.accessToken,
          responseDto.tokens!.refreshToken,
        );
        state = SessionState(
          isAuthenticated: false,
          user: user,
          accessToken: responseDto.tokens!.accessToken,
          refreshToken: responseDto.tokens!.refreshToken,
        );
      } else {
        state = SessionState(
          isAuthenticated: false,
          user: user,
        );
      }

      return {'ok': true, 'message': responseDto.message.isNotEmpty ? responseDto.message : 'Registered'};
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      return {
        'ok': false,
        'message': mapped.message,
        'status': e is DioException ? e.response?.statusCode : null,
      };
    }
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    state = state.copyWith(user: state.user.copyWith(avatarBytes: bytes));
    if (kUseMockBackend) return;
    try {
      final authService = _ref.read(authServiceProvider);
      await authService.updateAvatar(bytes);
      await fetchProfile();
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      throw mapped;
    }
  }

  Future<bool> login(String id, String password) async {
    try {
      final request = LoginRequestDto(identity: id, password: password);
      final authService = _ref.read(authServiceProvider);
      final responseDto = await authService.login(request);

      if (responseDto.tokens != null) {
        final sessionRepo = _ref.read(sessionRepositoryProvider);
        await sessionRepo.saveTokens(
          responseDto.tokens!.accessToken,
          responseDto.tokens!.refreshToken,
        );

        final user = UserProfile(
          firstName: responseDto.user.firstName,
          lastName: responseDto.user.lastName,
          username: responseDto.user.username,
          email: responseDto.user.email,
          phone: responseDto.user.phone,
          avatarUrl: responseDto.user.avatarUrl,
          isAuthenticated: true,
        );

        state = SessionState(
          isAuthenticated: true,
          user: user,
          accessToken: responseDto.tokens!.accessToken,
          refreshToken: responseDto.tokens!.refreshToken,
        );
        await sessionRepo.saveCachedUserProfile(user);
        return true;
      }
      return false;
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      throw mapped;
    }
  }

  Future<void> fetchProfile() async {
    if (kUseMockBackend) return;
    try {
      final authService = _ref.read(authServiceProvider);
      final validatedUser = await authService.fetchProfile(avatarBytes: state.user.avatarBytes);
      state = state.copyWith(user: validatedUser);
      await _ref.read(sessionRepositoryProvider).saveCachedUserProfile(validatedUser);
    } catch (e, stack) {
    }
  }

  Future<List<CircleMember>> syncContacts(List<String> phones) async {
    try {
      final authService = _ref.read(authServiceProvider);
      return await authService.syncContacts(phones);
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to sync contacts: $mapped');
      return const [];
    }
  }

  void authenticate() {
    state = state.copyWith(
      isAuthenticated: true,
      user: state.user.copyWith(isAuthenticated: true),
    );
    _ref.read(sessionRepositoryProvider).saveCachedUserProfile(state.user);
  }

  Future<void> logoutSession() async {
    state = SessionState.empty();
    try {
      await _ref.read(sessionRepositoryProvider).clearSession();
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
}

/// Centralized session state provider
final sessionProvider = StateNotifierProvider<SessionManager, SessionState>((ref) {
  return SessionManager(ref);
});

/// Derived provider to preserve the existing authProvider interface contract
final authProvider = Provider<UserProfile>((ref) {
  return ref.watch(sessionProvider).user;
});

final authRepositoryProvider = Provider<SessionManager>((ref) {
  return ref.read(sessionProvider.notifier);
});
