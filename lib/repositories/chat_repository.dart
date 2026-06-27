import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/error_handler.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/message.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_providers.dart';
import 'auth_repository.dart';
import 'circles_repository.dart';

// ─── Chat state ──────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    required this.messagesByContact,
    required this.unreadCounts,
    this.typingIndicators = const {},
    this.cursors = const {},
    this.hasMoreMessages = const {},
    this.isConversationsLoading = false,
    this.errorMessage,
  });

  final Map<String, List<Message>> messagesByContact;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingIndicators;
  final Map<String, String?> cursors;
  final Map<String, bool> hasMoreMessages;
  final bool isConversationsLoading;
  final String? errorMessage;

  int get unreadNotifications {
    return unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  ChatState copyWith({
    Map<String, List<Message>>? messagesByContact,
    Map<String, int>? unreadCounts,
    Map<String, bool>? typingIndicators,
    Map<String, String?>? cursors,
    Map<String, bool>? hasMoreMessages,
    bool? isConversationsLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messagesByContact: messagesByContact ?? this.messagesByContact,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      typingIndicators: typingIndicators ?? this.typingIndicators,
      cursors: cursors ?? this.cursors,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isConversationsLoading:
          isConversationsLoading ?? this.isConversationsLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─── Chat notifier ───────────────────────────────────────────────────────────
//
// ChatNotifier is the single source of truth for messaging state.
//
// WebSocket lifecycle (connect / disconnect / reconnect / heartbeat) is now
// owned exclusively by RealtimeCoordinator. ChatNotifier subscribes to
// realtimeEventStreamProvider and handles only the events it owns:
//   NewMessageEvent, TypingEvent, ReadReceiptEvent
//
// All outbound WS frames are emitted through the coordinator, never directly
// via a channel reference.

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref)
      : super(kUseMockBackend
            ? _initialState
            : const ChatState(messagesByContact: {}, unreadCounts: {})) {
    // Ensure the coordinator is running (it self-initialises on first read).
    _ref.read(realtimeCoordinatorProvider);

    // Subscribe to the broadcast event stream; filter for messaging events.
    _eventSubscription = _ref.listen<AsyncValue<RealtimeEvent>>(
      realtimeEventStreamProvider,
      (_, next) => next.whenData(_handleRealtimeEvent),
    );
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<RealtimeEvent>>? _eventSubscription;
  bool _disposed = false;
  String? _activeContact;
  final Map<String, Timer> _typingExpirationTimers = {};

  // ── Mock initial state ────────────────────────────────────────────────────

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

  // ── Real-time event handling ──────────────────────────────────────────────

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (_disposed) return;
    switch (event) {
      case NewMessageEvent():
        _handleIncoming(event);
      case TypingEvent():
        _handleTypingEvent(event);
      case ReadReceiptEvent():
        _handleReadReceipt(event);
      default:
        // Other event types are handled by their respective feature notifiers.
        break;
    }
  }

  void _handleIncoming(NewMessageEvent event) {
    final contactKey = event.receiver ?? event.sender;

    final existingList = state.messagesByContact[contactKey] ?? [];
    if (existingList.any((m) => m.id == event.id)) return; // deduplicated

    bool replaced = false;
    final updatedList = existingList.map((m) {
      if (m.isMine && m.isPending && m.text == event.text && !replaced) {
        replaced = true;
        return m.copyWith(id: event.id, isPending: false, timestamp: event.timestamp);
      }
      return m;
    }).toList();

    if (!replaced) {
      updatedList.add(Message(
        id: event.id,
        sender: event.sender,
        text: event.text,
        timestamp: event.timestamp,
        isMine: false,
      ));
    }

    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactKey] = updatedList;

    final updatedUnread = Map<String, int>.from(state.unreadCounts);
    if (_activeContact != contactKey) {
      updatedUnread[contactKey] = (updatedUnread[contactKey] ?? 0) + 1;
    }

    state = state.copyWith(
      messagesByContact: updatedMap,
      unreadCounts: updatedUnread,
    );

    _showNewMessageNotification(event.sender, event.text);
  }

  void _handleTypingEvent(TypingEvent event) {
    if (_disposed) return;
    final updated = Map<String, bool>.from(state.typingIndicators);
    updated[event.sender] = event.isTyping;
    state = state.copyWith(typingIndicators: updated);

    _typingExpirationTimers[event.sender]?.cancel();
    if (event.isTyping) {
      _typingExpirationTimers[event.sender] = Timer(const Duration(seconds: 5), () {
        if (_disposed) return;
        final current = Map<String, bool>.from(state.typingIndicators);
        current[event.sender] = false;
        state = state.copyWith(typingIndicators: current);
      });
    }
  }

  void _handleReadReceipt(ReadReceiptEvent event) {
    if (_disposed) return;
    final list = state.messagesByContact[event.sender] ?? [];
    final updated = list.map((m) => m.copyWith(isRead: true)).toList();
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[event.sender] = updated;
    state = state.copyWith(messagesByContact: updatedMap);
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

  // ─── Load conversation history from REST API ─────────────────────────────

  Future<void> loadConversation(
    String contactUsername, {
    bool shouldMarkRead = false,
    bool loadMore = false,
  }) async {
    if (kUseMockBackend) return;

    if (loadMore && state.hasMoreMessages[contactUsername] == false) {
      return;
    }

    try {
      final circles = _ref.read(circlesProvider);
      final member =
          circles.where((m) => m.username == contactUsername).firstOrNull;
      if (member == null) return;

      final dio = _ref.read(apiClientProvider);
      final markReadParam = shouldMarkRead ? 'true' : 'false';
      final cursor = loadMore ? state.cursors[contactUsername] : null;
      final cursorParam = cursor != null ? '&cursor=$cursor' : '';

      final response = await dio
          .get('/messages/history/${member.id}?markRead=$markReadParam$cursorParam');
      final body = response.data as Map<String, dynamic>? ?? {};
      final rawList =
          body['data'] as List? ?? body['comments'] as List? ?? [];

      final fetched = rawList.map((item) {
        final d = item as Map<String, dynamic>;
        final senderUsername =
            (d['sender'] as Map<String, dynamic>?)?['username'] as String? ?? '';
        final isMine = senderUsername != contactUsername;
        return Message(
          id: d['id']?.toString() ?? '',
          sender: isMine ? 'You' : contactUsername,
          text: d['text'] as String? ?? '',
          timestamp:
              DateTime.tryParse(d['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isMine: isMine,
          isRead: d['isRead'] as bool? ?? d['is_read'] as bool? ?? false,
        );
      }).toList();

      final String? nextCursor = body['nextCursor'] as String? ??
          (body['meta'] as Map?)?['nextCursor'] as String?;
      final bool hasMore = nextCursor != null;

      final updatedMap =
          Map<String, List<Message>>.from(state.messagesByContact);
      final existing = state.messagesByContact[contactUsername] ?? [];
      final merged = <Message>[];

      if (loadMore) {
        final existingIds = existing.map((m) => m.id).toSet();
        for (final m in fetched) {
          if (!existingIds.contains(m.id)) merged.add(m);
        }
        merged.addAll(existing);
      } else {
        final existingIds = fetched.map((m) => m.id).toSet();
        merged.addAll(fetched);
        for (final m in existing) {
          if (!existingIds.contains(m.id)) merged.add(m);
        }
      }

      merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      updatedMap[contactUsername] = merged;

      final unreadCount =
          fetched.where((msg) => !msg.isMine && !msg.isRead).length;
      final updatedUnread = Map<String, int>.from(state.unreadCounts);
      updatedUnread[contactUsername] =
          _activeContact == contactUsername ? 0 : unreadCount;

      final updatedCursors = Map<String, String?>.from(state.cursors);
      updatedCursors[contactUsername] = nextCursor;

      final updatedHasMore = Map<String, bool>.from(state.hasMoreMessages);
      updatedHasMore[contactUsername] = hasMore;

      state = state.copyWith(
        messagesByContact: updatedMap,
        unreadCounts: updatedUnread,
        cursors: updatedCursors,
        hasMoreMessages: updatedHasMore,
      );
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to load/merge conversation: $mapped');
    }
  }

  // ─── Outbound WS frames via coordinator ──────────────────────────────────

  /// Send a reaction event over the WebSocket.
  Future<void> sendReactionEvent(
      String memoryId, String emoji, String action) async {
    if (kUseMockBackend) return;
    try {
      _ref.read(realtimeCoordinatorProvider).emit({
        'event': 'send_reaction',
        'data': {'memory_id': memoryId, 'emoji': emoji, 'action': action},
      });
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('Failed to transmit reaction: $mapped');
      rethrow;
    }
  }

  /// Send typing indicator over the WebSocket.
  Future<void> sendTypingIndicator(String contactName, bool isTyping) async {
    if (kUseMockBackend) return;
    try {
      _ref.read(realtimeCoordinatorProvider).emit({
        'event': 'typing',
        'data': {'receiver': contactName, 'isTyping': isTyping},
      });
    } catch (e) {
      debugPrint('Failed to transmit typing indicator: $e');
    }
  }

  /// Send a read receipt over the WebSocket.
  Future<void> sendReadReceipt(String contactName) async {
    if (kUseMockBackend) return;
    try {
      _ref.read(realtimeCoordinatorProvider).emit({
        'event': 'read_receipt',
        'data': {'receiver': contactName},
      });
    } catch (e) {
      debugPrint('Failed to transmit read receipt: $e');
    }
  }

  // ─── Send a message ───────────────────────────────────────────────────────

  void sendMessage(String contactName, String text) {
    if (text.trim().isEmpty) return;

    final tempId = 'msg-local-${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = Message(
      id: tempId,
      sender: 'You',
      text: text.trim(),
      timestamp: DateTime.now(),
      isMine: true,
      isPending: true,
    );

    _appendMessage(contactName, newMessage);

    if (kUseMockBackend) {
      Timer(const Duration(milliseconds: 300), () {
        _confirmDelivery(contactName, tempId);
        _simulateReply(contactName);
      });
    } else {
      _transmitMessage(contactName, tempId, text.trim());
    }
  }

  void _transmitMessage(String contactName, String tempId, String text) {
    final coordinator = _ref.read(realtimeCoordinatorProvider);
    try {
      coordinator.emit({
        'event': 'send_message',
        'data': {'receiver': contactName, 'text': text},
      });
      _confirmDelivery(contactName, tempId);
    } catch (e) {
      _markFailed(contactName, tempId);
    }
  }

  void _confirmDelivery(String contactName, String tempId) {
    final list = state.messagesByContact[contactName] ?? [];
    final updated = list.map((msg) {
      if (msg.id == tempId) return msg.copyWith(isPending: false, isFailed: false);
      return msg;
    }).toList();
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = updated;
    state = state.copyWith(messagesByContact: updatedMap);
  }

  void _markFailed(String contactName, String tempId) {
    final list = state.messagesByContact[contactName] ?? [];
    final updated = list.map((msg) {
      if (msg.id == tempId) return msg.copyWith(isPending: false, isFailed: true);
      return msg;
    }).toList();
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = updated;
    state = state.copyWith(messagesByContact: updatedMap);
  }

  void retryMessage(String contactName, String tempId) {
    final list = state.messagesByContact[contactName] ?? [];
    final index = list.indexWhere((m) => m.id == tempId);
    if (index < 0) return;
    final msg = list[index];
    final updated = list.toList();
    updated[index] = msg.copyWith(isPending: true, isFailed: false);
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = updated;
    state = state.copyWith(messagesByContact: updatedMap);
    _transmitMessage(contactName, tempId, msg.text);
  }

  void deleteMessageOptimistic(String contactName, String tempId) {
    final list = state.messagesByContact[contactName] ?? [];
    final updated = list.where((m) => m.id != tempId).toList();
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = updated;
    state = state.copyWith(messagesByContact: updatedMap);
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: contactName,
        text: _getMockReply(contactName),
        timestamp: DateTime.now(),
        isMine: false,
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

  @override
  void dispose() {
    _disposed = true;
    _eventSubscription?.close();
    for (final t in _typingExpirationTimers.values) {
      t.cancel();
    }
    _typingExpirationTimers.clear();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
