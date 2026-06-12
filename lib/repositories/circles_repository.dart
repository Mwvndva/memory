import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';

// ─── Circle Member model ─────────────────────────────────────────────────────

class CircleMember {
  const CircleMember({
    required this.id,
    required this.username,
    required this.firstName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String firstName;
  final String? avatarUrl;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      id:        json['id']         as String? ?? '',
      username:  json['username']   as String? ?? '',
      firstName: json['first_name'] as String?
                  ?? json['firstName'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?
                  ?? json['avatarUrl'] as String?,
    );
  }

  String get initial => firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
}

// ─── Circles notifier ────────────────────────────────────────────────────────

class CirclesNotifier extends StateNotifier<List<CircleMember>> {
  CirclesNotifier(this._ref) : super(const []) {
    if (!kUseMockBackend) {
      fetchCircle();
    }
  }

  final Ref _ref;

  // ─── Fetch current user's circle members ────────────────────────────────

  Future<void> fetchCircle() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/circles/members');
      final rawList = response.data as List? ?? [];
      state = rawList
          .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  // ─── Add a member by their user ID ──────────────────────────────────────

  Future<bool> addMember(String memberId) async {
    if (kUseMockBackend) return false;
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/circles/members', data: {'memberId': memberId});
      await fetchCircle(); // Refresh list
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Remove a member by their user ID ───────────────────────────────────

  Future<bool> removeMember(String memberId) async {
    if (kUseMockBackend) return false;
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.delete('/circles/members/$memberId');
      state = state.where((m) => m.id != memberId).toList();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final circlesProvider =
    StateNotifierProvider<CirclesNotifier, List<CircleMember>>((ref) {
  return CirclesNotifier(ref);
});
