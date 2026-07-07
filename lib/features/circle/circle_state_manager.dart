import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/circle/circle.dart';

class CircleState {
  const CircleState({
    required this.circles,
    required this.pendingRequests,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CircleMember> circles;
  final List<CircleMember> pendingRequests;
  final bool isLoading;
  final String? errorMessage;

  CircleState copyWith({
    List<CircleMember>? circles,
    List<CircleMember>? pendingRequests,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CircleState(
      circles: circles ?? this.circles,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CircleStateManager extends StateNotifier<CircleState> {
  CircleStateManager(this._ref)
      : super(const CircleState(circles: [], pendingRequests: [])) {
    _ref.listen(circlesProvider, (previous, next) {
      state = state.copyWith(circles: next);
    });
    _ref.listen(pendingRequestsProvider, (previous, next) {
      state = state.copyWith(pendingRequests: next);
    });
  }

  final Ref _ref;

  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(circlesProvider.notifier).fetchCircle();
      await _ref.read(pendingRequestsProvider.notifier).fetchPendingRequests();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Map<String, dynamic>> inviteMember(String memberId) async {
    final cleanId = memberId.trim().toLowerCase();
    final username = cleanId.contains('@') ? cleanId.replaceFirst('@', '') : cleanId;
    final placeholder = CircleMember(
      id: memberId,
      username: username,
      firstName: username.isNotEmpty ? username[0].toUpperCase() + username.substring(1) : 'Member',
      relationshipState: RelationshipState.pending,
    );

    // Optimistically update the UI to Pending
    state = state.copyWith(
      pendingRequests: [
        ...state.pendingRequests.where((m) => m.id != memberId && m.username != username),
        placeholder,
      ],
    );

    try {
      final res = await _ref.read(circlesProvider.notifier).addMember(memberId);
      if (res['ok'] != true) {
        // Rollback
        state = state.copyWith(
          pendingRequests: state.pendingRequests.where((m) => m.id != memberId && m.username != username).toList(),
        );
      }
      return res;
    } catch (e) {
      state = state.copyWith(
        pendingRequests: state.pendingRequests.where((m) => m.id != memberId && m.username != username).toList(),
      );
      rethrow;
    }
  }

  Future<bool> removeMember(String memberId) async {
    final res = await _ref.read(circlesProvider.notifier).removeMember(memberId);
    return res;
  }

  Future<bool> acceptRequest(String senderId) async {
    final res = await _ref.read(pendingRequestsProvider.notifier).acceptRequest(senderId);
    return res;
  }

  Future<bool> declineRequest(String senderId) async {
    final res = await _ref.read(pendingRequestsProvider.notifier).declineRequest(senderId);
    return res;
  }
}

final circleStateManagerProvider =
    StateNotifierProvider<CircleStateManager, CircleState>((ref) {
  return CircleStateManager(ref);
});
