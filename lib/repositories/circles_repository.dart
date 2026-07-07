import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';
import '../models/user_profile.dart';
import '../features/feed/streak_milestones.dart';
import '../core/theme.dart';
import '../core/router.dart';
import '../core/error_handler.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_providers.dart';
import '../models/relationship_state.dart';
import '../services/circle_invitation_service.dart';

// ─── Circle Member model ─────────────────────────────────────────────────────

class CircleMember {
  const CircleMember({
    required this.id,
    required this.username,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    this.role = CircleRole.member,
    this.relationshipState = RelationshipState.member,
  });

  final String id;
  final String username;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final CircleRole role;
  final RelationshipState relationshipState;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String?;
    CircleRole parsedRole = CircleRole.member;
    if (roleStr == 'owner') {
      parsedRole = CircleRole.owner;
    } else if (roleStr == 'admin') {
      parsedRole = CircleRole.admin;
    } else if (roleStr == 'moderator') {
      parsedRole = CircleRole.moderator;
    }

    final stateStr = json['relationshipState'] as String? ?? json['status'] as String?;
    RelationshipState parsedState = RelationshipState.member;
    if (stateStr == 'pending') {
      parsedState = RelationshipState.pending;
    } else if (stateStr == 'notConnected') {
      parsedState = RelationshipState.notConnected;
    } else if (stateStr == 'removed') {
      parsedState = RelationshipState.removed;
    } else if (stateStr == 'unknown') {
      parsedState = RelationshipState.unknown;
    }

    return CircleMember(
      id:        json['id']         as String? ?? '',
      username:  json['username']   as String? ?? '',
      firstName: json['first_name'] as String?
                  ?? json['firstName'] as String? ?? '',
      lastName:  json['last_name'] as String?
                  ?? json['lastName'] as String?,
      avatarUrl: json['avatar_url'] as String?
                  ?? json['avatarUrl'] as String?,
      role: parsedRole,
      relationshipState: parsedState,
    );
  }

  CircleMember copyWith({
    String? id,
    String? username,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    CircleRole? role,
    RelationshipState? relationshipState,
  }) {
    return CircleMember(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      relationshipState: relationshipState ?? this.relationshipState,
    );
  }

  String get initial => firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
}

// ─── Circles notifier ────────────────────────────────────────────────────────

class CirclesNotifier extends StateNotifier<List<CircleMember>> {
  CirclesNotifier(this._ref) : super(const []) {
    // Only fetch when authenticated. Also listen for auth changes to refresh.
    final user = _ref.read(authProvider);
    if (!kUseMockBackend && user.isAuthenticated) {
      fetchCircle();
    }

    _ref.listen<UserProfile>(authProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) != next.isAuthenticated) {
        if (next.isAuthenticated) {
          fetchCircle();
        } else {
          // Clear local circle on logout
          state = const [];
        }
      }
    });

    // Listen to real-time event stream for circle milestone updates
    _ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventStreamProvider, (_, next) {
      next.whenData((event) {
        if (event is CircleMilestoneEvent) {
          _handleCircleMilestone(event);
        }
      });
    });
  }

  void _handleCircleMilestone(CircleMilestoneEvent event) {
    try {
      final circleOwnerId = event.circleOwnerId;
      final circleOwnerUsername = event.circleOwnerUsername;
      final milestone = event.milestone;
      final rawMembers = event.members;

      final prefs = _ref.read(sharedPreferencesProvider);
      final user = _ref.read(authProvider);
      final currentUsername = user.username.isNotEmpty ? user.username : 'user';
      final key = 'user_${currentUsername}_seen_circle_${circleOwnerId}_$milestone';

      if (prefs.getBool(key) ?? false) return;
      prefs.setBool(key, true);

      final membersList = rawMembers.map((m) {
        return CircleMemberWithMemories(
          id: m['id'] as String? ?? '',
          username: m['username'] as String? ?? '',
          firstName: m['firstName'] as String? ?? '',
          lastName: m['lastName'] as String?,
          avatarUrl: m['avatarUrl'] as String?,
          memoryCount: m['memoryCount'] as int? ?? 0,
        );
      }).toList();

      showGlobalNotification(
        title: 'Circle Milestone! 👥🎉',
        body: '@$circleOwnerUsername\'s circle reached a $milestone-user milestone! Tap to view the special card.',
        onTap: () {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => CircleMilestoneCongratulationsDialog(
                circleOwnerUsername: circleOwnerUsername,
                milestone: milestone,
                members: membersList,
              ),
            );
          }
        },
      );

      if (circleOwnerUsername == user.username) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => CircleMilestoneCongratulationsDialog(
                circleOwnerUsername: circleOwnerUsername,
                milestone: milestone,
                members: membersList,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to present milestone congratulations dialog: $e');
    }
  }

  final Ref _ref;

  // ─── Fetch current user's circle members ────────────────────────────────

  Future<void> fetchCircle() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/circles/members');
      final rawList = response.data as List? ?? [];
      final members = rawList
          .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
          .toList();
      state = members;
      
      // Load conversation history for all circle members in the background to populate message previews and unread badges
      for (final m in members) {
        _ref.read(chatProvider.notifier).loadConversation(m.username, shouldMarkRead: false);
      }
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to fetch circle: $mapped');
    }
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
    
    final inviteService = _ref.read(circleInvitationServiceProvider);
    final res = await inviteService.inviteMember(memberId);
    if (res['ok'] == true && res['message'] == 'Member added') {
      await fetchCircle();
    }
    return res;
  }

  // ─── Remove a member by their user ID ───────────────────────────────────

  Future<bool> removeMember(String memberId) async {
    if (kUseMockBackend) {
      state = state.where((m) => m.id != memberId && m.username != memberId).toList();
      return true;
    }
    final inviteService = _ref.read(circleInvitationServiceProvider);
    final ok = await inviteService.removeMember(memberId);
    if (ok) {
      state = state.where((m) => m.id != memberId).toList();
    }
    return ok;
  }

  void updateMemberRole(String memberId, CircleRole newRole) {
    state = state.map((m) {
      if (m.id == memberId) {
        return m.copyWith(role: newRole);
      }
      return m;
    }).toList();
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
    // Load pending requests only when authenticated. Also start a lightweight
    // reconciliation poll so we don't depend entirely on WebSocket delivery.
    final user = _ref.read(authProvider);
    if (kUseMockBackend) {
      state = const [
        CircleMember(
          id: 'mock_req_kofi',
          username: 'kofishares',
          firstName: 'Kofi',
        ),
      ];
    } else if (user.isAuthenticated) {
      fetchPendingRequests();
      _startReconciliationPoll();
    }

    _ref.listen<UserProfile>(authProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) != next.isAuthenticated) {
        if (next.isAuthenticated) {
          fetchPendingRequests();
          _startReconciliationPoll();
        } else {
          state = const [];
          _cancelReconciliationPoll();
        }
      }
    });

    // Listen to real-time events for new circle requests
    _ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventStreamProvider, (_, next) {
      next.whenData((event) {
        if (event is CircleRequestEvent) {
          addPending(CircleMember(
            id: event.senderId,
            username: event.senderUsername,
            firstName: event.senderFirstName,
            avatarUrl: event.senderAvatarUrl,
          ));
          Future.delayed(const Duration(seconds: 4), () {
            fetchPendingRequests();
          });
        }
      });
    });
  }

  final Ref _ref;
  Timer? _reconTimer;

  Future<void> fetchPendingRequests() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/circles/requests/pending');
      final rawList = response.data as List? ?? [];
      state = rawList.map((item) {
        final userJson = item['user'] as Map<String, dynamic>? ?? {};
        return CircleMember.fromJson(userJson);
      }).toList();
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to fetch pending requests: $mapped');
    }
  }

  /// Optimistically add a pending request locally. This is used when a WS
  /// event arrives so the UI updates immediately. A reconciliation poll will
  /// ensure server truth shortly after.
  void addPending(CircleMember member) {
    if (state.any((m) => m.id == member.id || m.username == member.username)) return;
    state = [...state, member];
  }

  void _startReconciliationPoll() {
    _cancelReconciliationPoll();
    _reconTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      try {
        fetchPendingRequests();
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        debugPrint('Error in pending requests reconciliation poll: $mapped');
      }
    });
  }

  void _cancelReconciliationPoll() {
    _reconTimer?.cancel();
    _reconTimer = null;
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
    final inviteService = _ref.read(circleInvitationServiceProvider);
    final ok = await inviteService.acceptRequest(senderId);
    if (ok) {
      await fetchPendingRequests();
      await _ref.read(circlesProvider.notifier).fetchCircle();
    }
    return ok;
  }

  Future<bool> declineRequest(String senderId) async {
    if (kUseMockBackend) {
      state = state.where((m) => m.id != senderId).toList();
      return true;
    }
    final inviteService = _ref.read(circleInvitationServiceProvider);
    final ok = await inviteService.declineRequest(senderId);
    if (ok) {
      await fetchPendingRequests();
    }
    return ok;
  }

  @override
  void dispose() {
    _cancelReconciliationPoll();
    super.dispose();
  }
}

final pendingRequestsProvider =
    StateNotifierProvider<PendingRequestsNotifier, List<CircleMember>>((ref) {
  return PendingRequestsNotifier(ref);
});
