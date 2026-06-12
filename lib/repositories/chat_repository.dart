import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_config.dart';
import '../core/secure_storage.dart';
import '../models/message.dart';

// ─── Chat state ──────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    required this.messagesByContact,
    required this.unreadNotifications,
  });

  final Map<String, List<Message>> messagesByContact;
  final int unreadNotifications;

  ChatState copyWith({
    Map<String, List<Message>>? messagesByContact,
    int? unreadNotifications,
  }) {
    return ChatState(
      messagesByContact: messagesByContact ?? this.messagesByContact,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
    );
  }
}

// ─── Chat notifier ───────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(_initialState) {
    if (!kUseMockBackend) {
      _initWebSocket();
    }
  }

  final Ref _ref;
  WebSocketChannel? _channel;

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
    unreadNotifications: 3,
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
    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.read(key: 'auth_token') ?? '';

      _channel = WebSocketChannel.connect(
        Uri.parse('$kWebSocketUrl?token=$token'),
      );

      _channel?.stream.listen(
        (raw) {
          try {
            final frame = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = frame['event'] as String?;
            final data  = frame['data']  as Map<String, dynamic>? ?? {};

            if (event == 'new_message') {
              _handleIncoming(data, isMine: false);
            } else if (event == 'message_sent') {
              // ACK — already shown optimistically; skip duplicate
            }
          } catch (_) {}
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
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
      } catch (_) {}
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  void _appendMessage(String contactName, Message msg) {
    final currentMessages = state.messagesByContact[contactName] ?? [];
    final updatedMap = Map<String, List<Message>>.from(state.messagesByContact);
    updatedMap[contactName] = [...currentMessages, msg];

    state = state.copyWith(
      messagesByContact: updatedMap,
      unreadNotifications: msg.isMine
          ? state.unreadNotifications
          : state.unreadNotifications + 1,
    );
  }

  void decrementNotifications() {
    if (state.unreadNotifications > 0) {
      state = state.copyWith(unreadNotifications: state.unreadNotifications - 1);
    }
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

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
