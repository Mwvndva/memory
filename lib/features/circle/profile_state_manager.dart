import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';

class ProfileState {
  const ProfileState({
    required this.user,
    this.viewedProfile,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile user;
  final UserProfile? viewedProfile;
  final bool isLoading;
  final String? errorMessage;

  ProfileState copyWith({
    UserProfile? user,
    UserProfile? viewedProfile,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      user: user ?? this.user,
      viewedProfile: viewedProfile ?? this.viewedProfile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileStateManager extends StateNotifier<ProfileState> {
  ProfileStateManager(this._ref)
      : super(ProfileState(user: _ref.read(authProvider))) {
    _ref.listen<UserProfile>(authProvider, (previous, next) {
      state = state.copyWith(user: next);
    });
  }

  final Ref _ref;

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(sessionProvider.notifier).fetchProfile();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(sessionProvider.notifier).updateAvatar(bytes);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final profileStateManagerProvider =
    StateNotifierProvider<ProfileStateManager, ProfileState>((ref) {
  return ProfileStateManager(ref);
});
