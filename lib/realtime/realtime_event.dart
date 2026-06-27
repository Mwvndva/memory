/// Typed real-time event model.
///
/// Every incoming WebSocket frame is parsed into one of these sealed subtypes
/// before being dispatched to feature state managers. Feature modules never
/// parse raw JSON frames directly.
library;

// ─── Base ────────────────────────────────────────────────────────────────────

sealed class RealtimeEvent {
  const RealtimeEvent({required this.eventId});

  /// Unique identifier used for deduplication.
  /// Derived from the event type + payload id field, or a timestamp hash
  /// when no id is present.
  final String eventId;
}

// ─── Messaging ───────────────────────────────────────────────────────────────

class NewMessageEvent extends RealtimeEvent {
  const NewMessageEvent({
    required super.eventId,
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.receiver,
  });

  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final String? receiver;
}

class MessageSentAckEvent extends RealtimeEvent {
  const MessageSentAckEvent({required super.eventId, required this.tempId});

  final String tempId;
}

// ─── Typing ──────────────────────────────────────────────────────────────────

class TypingEvent extends RealtimeEvent {
  const TypingEvent({
    required super.eventId,
    required this.sender,
    required this.isTyping,
  });

  final String sender;
  final bool isTyping;
}

// ─── Read receipts ───────────────────────────────────────────────────────────

class ReadReceiptEvent extends RealtimeEvent {
  const ReadReceiptEvent({
    required super.eventId,
    required this.sender,
  });

  final String sender;
}

// ─── Feed / Memories ─────────────────────────────────────────────────────────

class NewMemoryEvent extends RealtimeEvent {
  const NewMemoryEvent({
    required super.eventId,
    required this.creatorName,
    required this.creatorUsername,
    this.memoryId,
  });

  final String creatorName;
  final String creatorUsername;
  final String? memoryId;
}

// ─── Reactions ───────────────────────────────────────────────────────────────

class NewReactionEvent extends RealtimeEvent {
  const NewReactionEvent({
    required super.eventId,
    required this.reactorName,
    required this.emoji,
    required this.memoryCaption,
    this.memoryId,
  });

  final String reactorName;
  final String emoji;
  final String memoryCaption;
  final String? memoryId;
}

// ─── Circle requests ─────────────────────────────────────────────────────────

class CircleRequestEvent extends RealtimeEvent {
  const CircleRequestEvent({
    required super.eventId,
    required this.senderId,
    required this.senderUsername,
    required this.senderFirstName,
    this.senderAvatarUrl,
  });

  final String senderId;
  final String senderUsername;
  final String senderFirstName;
  final String? senderAvatarUrl;
}

// ─── Circle milestones ────────────────────────────────────────────────────────

class CircleMilestoneEvent extends RealtimeEvent {
  const CircleMilestoneEvent({
    required super.eventId,
    required this.circleOwnerId,
    required this.circleOwnerUsername,
    required this.milestone,
    required this.members,
  });

  final String circleOwnerId;
  final String circleOwnerUsername;
  final int milestone;
  final List<Map<String, dynamic>> members;
}

// ─── Presence ────────────────────────────────────────────────────────────────

class PresenceEvent extends RealtimeEvent {
  const PresenceEvent({
    required super.eventId,
    required this.username,
    required this.status,
  });

  final String username;
  final PresenceStatus status;
}

enum PresenceStatus { online, offline, idle }

// ─── Heartbeat ───────────────────────────────────────────────────────────────

class PongEvent extends RealtimeEvent {
  const PongEvent({required super.eventId, this.serverTs});

  final String? serverTs;
}

// ─── Unknown / unhandled ─────────────────────────────────────────────────────

class UnknownEvent extends RealtimeEvent {
  const UnknownEvent({required super.eventId, required this.rawEventName});

  final String rawEventName;
}
