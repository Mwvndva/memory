import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/message.dart';
import 'circles_repository.dart';
import '../models/user_profile.dart';
import '../core/router.dart';
import 'package:go_router/go_router.dart';
import 'auth_repository.dart';
import 'package:flutter/material.dart';
import '../features/feed/streak_milestones.dart';
import '../core/theme.dart';
import '../core/error_handler.dart';

// ─── Chat state ──────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    required this.messagesByContact,
    required this.unreadCounts,
  });

  final Map<String, List<Message>> messagesByContact;
  final Map<String, int> unreadCounts;

  int get unreadNotifications {
    return unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  ChatState copyWith({
    Map<String, List<Message>>? messagesByContact,
    Map<String, int>? unreadCounts,
  }) {
    return ChatState(
      messagesByContact: messagesByContact ?? this.messagesByContact,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }
}

// ─── Chat notifier ───────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref)
      : super(kUseMockBackend
            ? _initialState
            : const ChatState(messagesByContact: {}, unreadCounts: {})) {
    // Only initialize websocket when authenticated. Also listen to auth changes to clear/reconnect.
    final user = _ref.read(authProvider);
    if (!kUseMockBackend && user.isAuthenticated) {
      _initWebSocket();
    }

    _ref.listen<UserProfile>(authProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) != next.isAuthenticated) {
        if (next.isAuthenticated) {
          // Reconnect WS
          _initWebSocket();
        } else {
          // Clear messages on logout
          state = const ChatState(messagesByContact: {}, unreadCounts: {});
          _connectionGeneration++;
          _closeSocket(manual: true);
        }
      }
    });
  }

  final Ref _ref;
  WebSocketChannel? _channel;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _manualClose = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  int _connectionGeneration = 0;

  // ─── Default mock data (shown when kUseMockBackend = true) ────────────────

  static final ChatState _initialState = ChatState(
    messagesByContact: {
      'Amara': [
        Message(
          id: 'a1',
          sender: 'Amara',
          text: 'Reacted 😂 to your memory',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          isMine: false,
        ),
        Message(
          id: 'a2',
          sender: 'Amara',
          text: 'That video made my day.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
          isMine: false,
        ),
        Message(
          id: 'a3',
          sender: 'You',
          text: "I still can't believe it happened.",
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isMine: true,
        ),
      ],
      'Mum': [
        Message(
          id: 'm1',
          sender: 'Mum',
          text: 'Found your old school song',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isMine: false,
        ),
      ],
      'Leo': [
        Message(
          id: 'l1',
          sender: 'Leo',
          text: 'Rainy walk after class',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          isMine: false,
        ),
      ],
      'Nia': [
        Message(
          id: 'n1',
          sender: 'Nia',
          text: 'Sunset on the way home',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isMine: false,
        ),
      ],
    },
    unreadCounts: const {
      'Amara': 2,
      'Mum': 1,
    },
  );

  // ─── Live WebSocket connection ────────────────────────────────────────────
  //
  // NestJS raw ws gateway emits frames as:
  //   { "event": "new_message",   "data": { "id", "sender", "text", "timestamp", "is_mine" } }
  //   { "event": "message_sent",  "data": { ... } }
  //   { "event": "reaction_update","data": { "memory_id", "emoji", "count" } }
  //   { "event": "connected",     "data": { "userId", "username" } }
  //   { "event": "auth_error",    "data": { "message" } }

  Future<void> _initWebSocket() async {
    if (kUseMockBackend || _disposed || _isConnecting) return;

    final user = _ref.read(authProvider);
    if (!user.isAuthenticated) return;

    _isConnecting = true;
    try {
      final connectionId = ++_connectionGeneration;
      _closeSocket(manual: false);

      final token = _ref.read(sessionProvider).accessToken ?? '';
      if (token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      // Request a short-lived single-use WebSocket connection ticket from the backend.
      // The HTTP call automatically attaches the Bearer token via apiClientProvider.
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post('/auth/ws-ticket');
      final ticket = response.data['ticket'] as String?;

      if (connectionId != _connectionGeneration) {
        // A newer connection attempt started while we were awaiting the ticket.
        // Discard this ticket and return.
        return;
      }

      if (ticket == null || ticket.isEmpty) {
        _scheduleReconnect();
        return;
      }

      // Append the opaque ticket as a query parameter.
      // This prevents the JWT from being exposed in URL query logs or
      // header logs (e.g. Sec-WebSocket-Protocol) of proxies, load balancers, or CDNs.
      final baseUri = Uri.parse(kWebSocketUrl);
      final wsUri = baseUri.replace(
        queryParameters: {
          ...baseUri.queryParameters,
          'ticket': ticket,
        },
      );

      _manualClose = false;
      _channel = IOWebSocketChannel.connect(wsUri);

      _reconnectAttempt = 0;
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_disposed || _manualClose || _channel == null) return;
        try {
          _channel?.sink.add(jsonEncode({
            'event': 'ping',
            'data': {'ts': DateTime.now().toIso8601String()},
          }));
        } catch (e) {
          debugPrint('Failed to send ping: $e');
        }
      });

      _channel?.stream.listen(
        (raw) {
          try {
            final frame = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = frame['event'] as String?;
            final data = frame['data'] as Map<String, dynamic>? ?? {};

            if (event == 'new_circle_request') {
              try {
                final senderId = data['senderId']?.toString() ?? '';
                final senderUsername = data['senderUsername'] as String? ?? '';
                final senderFirstName = data['senderFirstName'] as String? ?? '';
                final senderAvatar = data['senderAvatarUrl'] as String? ?? data['senderAvatar'] as String?;

                if (senderId.isNotEmpty || senderUsername.isNotEmpty) {
                  try {
                    _ref.read(pendingRequestsProvider.notifier).addPending(
                      CircleMember(
                        id: senderId.isNotEmpty ? senderId : (senderUsername.isNotEmpty ? senderUsername : ''),
                        username: senderUsername.isNotEmpty ? senderUsername : (senderId.isNotEmpty ? senderId : ''),
                        firstName: senderFirstName.isNotEmpty ? senderFirstName : (senderUsername.isNotEmpty ? senderUsername : 'Friend'),
                        avatarUrl: senderAvatar,
                      ),
                    );
                  } catch (e) {
                    debugPrint('Error adding pending request: $e');
                  }
                }

                Future.delayed(const Duration(seconds: 4), () {
                  try {
                    _ref.read(pendingRequestsProvider.notifier).fetchPendingRequests();
                  } catch (e) {
                    debugPrint('Error fetching pending requests in delay: $e');
                  }
                });
              } catch (e) {
                debugPrint('Failed to process pending request frame: $e');
              }
              return;
            }

            if (event == 'pong') {
              return;
            }

            if (event == 'new_message') {
              _handleIncoming(data, isMine: false);
            } else if (event == 'new_reaction') {
              _handleReactionNotification(data);
            } else if (event == 'new_memory') {
              _handleMemoryNotification(data);
            } else if (event == 'new_circle_milestone') {
              _handleCircleMilestone(data);
            } else if (event == 'message_sent') {
              // ACK — already shown optimistically; skip duplicate
            }
          } catch (e, stack) {
            final mapped = mapException(e, stack);
            debugPrint('Failed to decode incoming stream frame: $mapped');
          }
        },
        onError: (error) {
          _handleSocketClosed('error: $error', connectionId);
        },
        onDone: () {
          _handleSocketClosed('closed', connectionId);
        },
        cancelOnError: true,
      );
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to establish WebSocket connection: $mapped');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleSocketClosed(String reason, int connectionId) {
    if (connectionId != _connectionGeneration) return;

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _channel = null;

    if (_disposed || _manualClose) return;
    if (!_ref.read(authProvider).isAuthenticated) return;

    _scheduleReconnect(reason: reason);
  }

  void _scheduleReconnect({String reason = 'socket closed'}) {
    if (_disposed || _manualClose) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    if (_reconnectTimer?.isActive ?? false) return;

    final delays = <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 15),
    ];
    final index = _reconnectAttempt < delays.length ? _reconnectAttempt : delays.length - 1;
    final delay = delays[index];
    if (_reconnectAttempt < delays.length - 1) {
      _reconnectAttempt++;
    }

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_disposed || _manualClose) return;
      if (!_ref.read(authProvider).isAuthenticated) return;
      _initWebSocket();
    });
  }

  void _closeSocket({required bool manual}) {
    _manualClose = manual;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Failed to close WS channel: $e');
    }
    _channel = null;
  }

  void _handleIncoming(Map<String, dynamic> data, {required bool isMine}) {
    final sender = data['sender'] as String? ?? 'Unknown';
    final msg = Message(
      id:        data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender:    sender,
      text:      data['text'] as String? ?? '',
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isMine:    isMine,
    );
    _appendMessage(sender, msg);

    if (!isMine) {
      _showNewMessageNotification(sender, msg.text);
    }
  }

  void _showNewMessageNotification(String sender, String text) {
    final templates = [
      '{name} sent you a message: "text"',
      '{name} is tapping: "text"',
      'New message from {name}! \'text\'',
      '{name} says: "text"',
      'Hey! {name} just pinged you: "text"',
    ];
    final randomIdx = DateTime.now().millisecondsSinceEpoch % templates.length;
    final body = templates[randomIdx]
        .replaceAll('{name}', sender)
        .replaceAll('text', text);

    showGlobalNotification(
      title: 'New Message from $sender 💬',
      body: body,
      onTap: () {
        rootNavigatorKey.currentState?.context.push('/chat/$sender');
      },
    );
  }

  void _handleReactionNotification(Map<String, dynamic> data) {
    final reactorName = data['reactorName'] as String? ?? 'A friend';
    final emoji = data['emoji'] as String? ?? '❤️';
    final caption = data['memoryCaption'] as String? ?? 'your memory';

    final templates = [
      '{name} loved your memory! Reaction: emoji',
      '{name} reacted emoji to your latest memory: "caption"',
      'emoji from {name}! She just reacted to your post.',
      '{name} found your memory "caption" reaction-worthy: emoji',
      'Reaction alert! {name} left a emoji on your memory.',
    ];

    final randomIdx = DateTime.now().millisecondsSinceEpoch % templates.length;
    final body = templates[randomIdx]
        .replaceAll('{name}', reactorName)
        .replaceAll('emoji', emoji)
        .replaceAll('caption', caption);

    showGlobalNotification(
      title: 'New Reaction $emoji',
      body: body,
      onTap: () {
        rootNavigatorKey.currentState?.context.go('/circle');
      },
    );
  }

  void _handleMemoryNotification(Map<String, dynamic> data) {
    final creatorName = data['creatorName'] as String? ?? 'A friend';

    final templates = [
      '{name} just shared a new memory! Tap to see what they\'re up to.',
      'New post alert! {name} just captured a new memory.',
      '{name} has updated their circle! Check out their latest memory.',
      '{name}\'s day looks interesting! See their new memory now.',
      'Peek into {name}\'s world — a new memory was just posted!',
    ];

    final randomIdx = DateTime.now().millisecondsSinceEpoch % templates.length;
    final body = templates[randomIdx].replaceAll('{name}', creatorName);

    showGlobalNotification(
      title: 'New Memory 📸',
      body: body,
      onTap: () {
        rootNavigatorKey.currentState?.context.go('/feed');
      },
    );
  }

  // ─── Load conversation history from REST API ─────────────────────────────

  Future<void> loadConversation(String contactUsername, {bool shouldMarkRead = false}) async {
    if (kUseMockBackend) return;
    try {
      // Resolve username → userId via the circles list (already fetched)
      final circles = _ref.read(circlesProvider);
      final member = circles.where((m) => m.username == contactUsername).firstOrNull;
      if (member == null) return; // not in circle, skip

      final dio = _ref.read(apiClientProvider);
      // Pass markRead=false during background preview loads; markRead=true when user opens chat
      final markReadParam = shouldMarkRead ? 'true' : 'false';
      final response = await dio.get('/messages/history/${member.id}?markRead=$markReadParam');
      final body = response.data as Map<String, dynamic>? ?? {};
      final rawList = body['data'] as List? ?? [];

      final fetched = rawList.map((item) {
        final d = item as Map<String, dynamic>;
        // determine if the message is mine by checking sender username
        final senderUsername = (d['sender'] as Map<String, dynamic>?)?['username'] as String? ?? '';
        final isMine = senderUsername != contactUsername;
        return Message(
          id:        d['id']?.toString() ?? '',
          sender:    isMine ? 'You' : contactUsername,
          text:      d['text'] as String? ?? '',
          timestamp: DateTime.tryParse(d['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isMine:    isMine,
          isRead:    d['isRead'] as bool? ?? d['is_read'] as bool? ?? false,
        );
      }).toList();

      if (fetched.isEmpty) return;

      final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
      // Merge: history first, then any messages already in state (sent this session)
      final existing = state.messagesByContact[contactUsername] ?? [];
      final merged = <Message>[];
      final existingIds = existing.map((m) => m.id).toSet();
      for (final m in fetched) {
        if (!existingIds.contains(m.id)) merged.add(m);
      }
      merged.addAll(existing);
      updatedMap[contactUsername] = merged;

      final unreadCount = fetched.where((msg) => !msg.isMine && !msg.isRead).length;
      final updatedUnread = Map<String, int>.from(state.unreadCounts);
      updatedUnread[contactUsername] = _activeContact == contactUsername ? 0 : unreadCount;

      state = state.copyWith(
        messagesByContact: updatedMap,
        unreadCounts: updatedUnread,
      );
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to load/merge conversation: $mapped');
    }
  }

  // ─── Send a message ───────────────────────────────────────────────────────

  void sendMessage(String contactName, String text) {
    if (text.trim().isEmpty) return;

    final newMessage = Message(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      sender:    'You',
      text:      text.trim(),
      timestamp: DateTime.now(),
      isMine:    true,
    );

    // Optimistic UI update
    _appendMessage(contactName, newMessage);

    if (kUseMockBackend) {
      _simulateReply(contactName);
    } else {
      try {
        // NestJS gateway expects: { "event": "send_message", "data": { "receiver": "<username>", "text": "<text>" } }
        _channel?.sink.add(jsonEncode({
          'event': 'send_message',
          'data': {
            'receiver': contactName,
            'text': text.trim(),
          },
        }));
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        debugPrint('Failed to transmit message over WS: $mapped');
      }
    }
  }

  Future<void> sendReactionEvent(String memoryId, String emoji, String action) async {
    if (kUseMockBackend) return;
    try {
      _channel?.sink.add(jsonEncode({
        'event': 'send_reaction',
        'data': {
          'memory_id': memoryId,
          'emoji': emoji,
          'action': action,
        },
      }));
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to transmit reaction over WS: $mapped');
      rethrow;
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  String? _activeContact;

  void enterConversation(String contactName) {
    _activeContact = contactName;
    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    updatedUnread[contactName] = 0;
    state = state.copyWith(unreadCounts: updatedUnread);
  }

  void exitConversation() {
    _activeContact = null;
  }

  void _appendMessage(String contactName, Message msg) {
    final currentMessages = state.messagesByContact[contactName] ?? [];
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = [...currentMessages, msg];

    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    if (!msg.isMine && _activeContact != contactName) {
      updatedUnread[contactName] = (updatedUnread[contactName] ?? 0) + 1;
    } else {
      updatedUnread[contactName] = 0;
    }

    state = state.copyWith(
      messagesByContact: updatedMap,
      unreadCounts: updatedUnread,
    );
  }

  void _simulateReply(String contactName) {
    Timer(const Duration(seconds: 1), () {
      final replyMessage = Message(
        id:        DateTime.now().millisecondsSinceEpoch.toString(),
        sender:    contactName,
        text:      _getMockReply(contactName),
        timestamp: DateTime.now(),
        isMine:    false,
      );
      _appendMessage(contactName, replyMessage);
    });
  }

  String _getMockReply(String name) {
    final replies = [
      'That makes sense!',
      'Haha love that 😂',
      "Awesome, let's meet up soon.",
      'Can you share that memory again?',
      'Miss you guys!',
    ];
    return replies[DateTime.now().second % replies.length];
  }

  void _handleCircleMilestone(Map<String, dynamic> data) {
    try {
      final circleOwnerId = data['circleOwnerId'] as String? ?? '';
      final circleOwnerUsername = data['circleOwnerUsername'] as String? ?? 'user';
      final milestone = data['milestone'] as int? ?? 7;
      final rawMembers = data['members'] as List? ?? [];

      final prefs = _ref.read(sharedPreferencesProvider);
      final user = _ref.read(authProvider);
      final currentUsername = user.username.isNotEmpty ? user.username : 'user';
      final key = 'user_${currentUsername}_seen_circle_${circleOwnerId}_$milestone';

      if (prefs.getBool(key) ?? false) return;

      // Mark as seen locally so it only triggers once
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

      // Trigger celebratory global notification
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

      // If current user is the owner, also pop it up automatically!
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

  @override
  void dispose() {
    _disposed = true;
    _connectionGeneration++;
    _closeSocket(manual: true);
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
