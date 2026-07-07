import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_providers.dart';
import '../core/api_config.dart';
import 'chat_repository.dart';

abstract class MessageRepository {
  Future<void> sendMessage(String contactName, String text);
  Future<void> retryMessage(String contactName, String tempId);
  void deleteMessageOptimistic(String contactName, String tempId);
  Future<void> sendReadReceipt(String contactName);
  Future<void> sendReactionEvent(String memoryId, String emoji, String action);
}

abstract class ConversationRepository {
  Future<void> loadConversation(
    String contactUsername, {
    bool shouldMarkRead = false,
    bool loadMore = false,
  });
}

abstract class PresenceRepository {
  Future<void> updatePresence(PresenceStatus status);
  Stream<PresenceEvent> get presenceEvents;
}

abstract class TypingRepository {
  Future<void> sendTypingIndicator(String contactName, bool isTyping);
}

class MessageRepositoryImpl implements MessageRepository {
  final Ref _ref;
  MessageRepositoryImpl(this._ref);

  @override
  Future<void> sendMessage(String contactName, String text) async {
    if (kUseMockBackend) return;
    _ref.read(realtimeCoordinatorProvider).emit({
      'event': 'send_message',
      'data': {'receiver': contactName, 'text': text},
    });
  }

  @override
  Future<void> retryMessage(String contactName, String tempId) async {
    _ref.read(chatProvider.notifier).retryMessage(contactName, tempId);
  }

  @override
  void deleteMessageOptimistic(String contactName, String tempId) {
    _ref.read(chatProvider.notifier).deleteMessageOptimistic(contactName, tempId);
  }

  @override
  Future<void> sendReadReceipt(String contactName) async {
    if (kUseMockBackend) return;
    _ref.read(realtimeCoordinatorProvider).emit({
      'event': 'read_receipt',
      'data': {'receiver': contactName},
    });
  }

  @override
  Future<void> sendReactionEvent(String memoryId, String emoji, String action) async {
    if (kUseMockBackend) return;
    _ref.read(realtimeCoordinatorProvider).emit({
      'event': 'send_reaction',
      'data': {'memory_id': memoryId, 'emoji': emoji, 'action': action},
    });
  }
}

class ConversationRepositoryImpl implements ConversationRepository {
  final Ref _ref;
  ConversationRepositoryImpl(this._ref);

  @override
  Future<void> loadConversation(
    String contactUsername, {
    bool shouldMarkRead = false,
    bool loadMore = false,
  }) async {
    await _ref.read(chatProvider.notifier).loadConversation(
      contactUsername,
      shouldMarkRead: shouldMarkRead,
      loadMore: loadMore,
    );
  }
}

class PresenceRepositoryImpl implements PresenceRepository {
  final Ref _ref;
  PresenceRepositoryImpl(this._ref);

  @override
  Future<void> updatePresence(PresenceStatus status) async {
    if (kUseMockBackend) return;
    try {
      _ref.read(realtimeCoordinatorProvider).emit({
        'event': 'presence',
        'data': {'status': status.name},
      });
    } catch (e) {
      debugPrint('Failed to transmit presence: $e');
    }
  }

  @override
  Stream<PresenceEvent> get presenceEvents {
    return _ref.read(realtimeCoordinatorProvider).eventStream.where((event) => event is PresenceEvent).cast<PresenceEvent>();
  }
}

class TypingRepositoryImpl implements TypingRepository {
  final Ref _ref;
  TypingRepositoryImpl(this._ref);

  @override
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
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(ref);
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepositoryImpl(ref);
});

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepositoryImpl(ref);
});

final typingRepositoryProvider = Provider<TypingRepository>((ref) {
  return TypingRepositoryImpl(ref);
});
