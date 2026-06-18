import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import 'auth_repository.dart';
import '../features/feed/streak_milestones.dart';
import '../core/theme.dart';
import '../core/router.dart';

// ─── Circle Member model ─────────────────────────────────────────────────────

class CircleMember {
  const CircleMember({
    required this.id,
    required this.username,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      id:        json['id']         as String? ?? '',
      username:  json['username']   as String? ?? '',
      firstName: json['first_name'] as String?
                  ?? json['firstName'] as String? ?? '',
      lastName:  json['last_name'] as String?
                  ?? json['lastName'] as String?,
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

  Future<Map<String, dynamic>> addMember(String memberId) async {
    if (kUseMockBackend) {
      final cleanId = memberId.trim().toLowerCase();
      // Generate a mock member details based on the ID/username searched
      final newMember = CircleMember(
        id: memberId,
        username: cleanId.contains('@') ? cleanId.replaceFirst('@', '') : cleanId,
        firstName: memberId.length > 1 ? memberId[0].toUpperCase() + memberId.substring(1) : 'Member',
      );
      // Avoid duplicate adding
      if (!state.any((m) => m.username.toLowerCase() == newMember.username.toLowerCase())) {
        state = [...state, newMember];
      }

      // Check mockup circle milestone triggers
      final count = state.length;
      if (count == 7 || count == 30) {
        _triggerMockCircleMilestone(count);
      }

      return {'ok': true, 'message': 'Added (mock)'};
    }
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post('/circles/members', data: {'memberId': memberId});
      await fetchCircle(); // Refresh list
      final data = response.data;
      return {
        'ok': true,
        'message': data is Map && data['message'] != null ? data['message'] : 'Request sent',
        'status': response.statusCode,
      };
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      String msg = 'Failed to send request.';
      if (status == 409) {
        try {
          final d = e.response?.data;
          if (d is Map && d['message'] != null) msg = d['message'].toString();
        } catch (_) {}
      } else if (e.response != null && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d['message'] != null) msg = d['message'].toString();
      } else {
        msg = e.message ?? msg;
      }
      return {'ok': false, 'message': msg, 'status': status};
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // ─── Remove a member by their user ID ───────────────────────────────────

  Future<bool> removeMember(String memberId) async {
    if (kUseMockBackend) {
      state = state.where((m) => m.id != memberId && m.username != memberId).toList();
      return true;
    }
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.delete('/circles/members/$memberId');
      state = state.where((m) => m.id != memberId).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Simulation Trigger for Circle Milestones in Mock Mode ────────────────

  void _triggerMockCircleMilestone(int milestone) {
    final user = _ref.read(authProvider);
    final currentUsername = user.username.isNotEmpty ? user.username : 'user';
    final key = 'user_${currentUsername}_seen_circle_me_$milestone';

    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs.getBool(key) ?? false) return;
    prefs.setBool(key, true);

    final rand = Random();
    final mockMembersWithMemories = <CircleMemberWithMemories>[
      // Owner (me)
      CircleMemberWithMemories(
        id: user.username,
        username: user.username.isNotEmpty ? user.username : 'user',
        firstName: user.firstName.isNotEmpty ? user.firstName : 'User',
        avatarUrl: user.avatarUrl,
        memoryCount: rand.nextInt(15) + 5,
      ),
      // Friends
      ...state.map((m) => CircleMemberWithMemories(
        id: m.id,
        username: m.username,
        firstName: m.firstName,
        lastName: m.lastName,
        avatarUrl: m.avatarUrl,
        memoryCount: rand.nextInt(15) + 1,
      )),
    ];

    showGlobalNotification(
      title: 'Circle Milestone! 👥🎉',
      body: 'Your circle reached a $milestone-user milestone! Tap to view the special card.',
      onTap: () {
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => CircleMilestoneCongratulationsDialog(
              circleOwnerUsername: currentUsername,
              milestone: milestone,
              members: mockMembersWithMemories,
            ),
          );
        }
      },
    );

    // Also pop it up automatically
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CircleMilestoneCongratulationsDialog(
            circleOwnerUsername: currentUsername,
            milestone: milestone,
            members: mockMembersWithMemories,
          ),
        );
      }
    });
  }
}

final circlesProvider =
    StateNotifierProvider<CirclesNotifier, List<CircleMember>>((ref) {
  return CirclesNotifier(ref);
});

// ─── Pending Requests notifier ────────────────────────────────────────────────

class PendingRequestsNotifier extends StateNotifier<List<CircleMember>> {
  PendingRequestsNotifier(this._ref) : super(const []) {
    if (kUseMockBackend) {
      state = const [
        CircleMember(
          id: 'mock_req_kofi',
          username: 'kofishares',
          firstName: 'Kofi',
        ),
      ];
    } else {
      fetchPendingRequests();
    }
  }

  final Ref _ref;

  Future<void> fetchPendingRequests() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/circles/requests/pending');
      final rawList = response.data as List? ?? [];
      state = rawList.map((item) {
        final userJson = item['user'] as Map<String, dynamic>? ?? {};
        return CircleMember.fromJson(userJson);
      }).toList();
    } catch (_) {}
  }

  Future<bool> acceptRequest(String senderId) async {
    if (kUseMockBackend) {
      final index = state.indexWhere((m) => m.id == senderId);
      if (index != -1) {
        final acceptedUser = state[index];
        state = state.where((m) => m.id != senderId).toList();
        final circlesNotifier = _ref.read(circlesProvider.notifier);
        circlesNotifier.state = [...circlesNotifier.state, acceptedUser];
      }
      return true;
    }
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/circles/requests/accept', data: {'senderId': senderId});
      await fetchPendingRequests();
      await _ref.read(circlesProvider.notifier).fetchCircle();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> declineRequest(String senderId) async {
    if (kUseMockBackend) {
      state = state.where((m) => m.id != senderId).toList();
      return true;
    }
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/circles/requests/decline', data: {'senderId': senderId});
      await fetchPendingRequests();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final pendingRequestsProvider =
    StateNotifierProvider<PendingRequestsNotifier, List<CircleMember>>((ref) {
  return PendingRequestsNotifier(ref);
});
