import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'event_deduplicator.dart';
import 'realtime_event.dart';

// ─── Connection state ─────────────────────────────────────────────────────────

/// Authoritative connection state for the single WebSocket session.
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  authFailed,
  offline,
}

// ─── Coordinator ──────────────────────────────────────────────────────────────

/// The single owner of the WebSocket connection.
///
/// Responsibilities:
/// - Open / close exactly one connection per authenticated session.
/// - Authenticate via the `/auth/ws-ticket` ticket exchange.
/// - Maintain a ping/keep-alive heartbeat every 25 seconds.
/// - Reconnect automatically with exponential back-off on failure.
/// - Parse raw WS frames into typed [RealtimeEvent] values.
/// - Deduplicate events using [EventDeduplicator].
/// - Broadcast events through a single [Stream<RealtimeEvent>].
///
/// Feature modules (ChatNotifier, FeedNotifier, etc.) subscribe to
/// [eventStream] and filter for the event types they care about.
/// No feature module may open its own socket connection.
class RealtimeCoordinator {
  RealtimeCoordinator(this._ref) {
    // Observe auth state; connect on login, disconnect on logout.
    _ref.listen<UserProfile>(authProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) != next.isAuthenticated) {
        if (next.isAuthenticated) {
          connect();
        } else {
          disconnect(manual: true);
        }
      }
    });

    // Connect immediately if already authenticated.
    if (!kUseMockBackend && _ref.read(authProvider).isAuthenticated) {
      connect();
    }
  }

  final Ref _ref;

  // ── Internal state ──────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _manualClose = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  int _connectionGeneration = 0;

  // ── Connection state ────────────────────────────────────────────────────────
  RealtimeConnectionState _connectionState =
      RealtimeConnectionState.disconnected;

  RealtimeConnectionState get connectionState => _connectionState;

  void _setConnectionState(RealtimeConnectionState next) {
    if (_connectionState == next) return;
    _connectionState = next;
    _connectionStateController.add(next);
  }

  final _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();

  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  // ── Event stream ─────────────────────────────────────────────────────────────
  final _eventController = StreamController<RealtimeEvent>.broadcast();

  /// Broadcast stream of all incoming real-time events.
  /// Feature modules subscribe and filter for the events they care about.
  Stream<RealtimeEvent> get eventStream => _eventController.stream;

  // ── Deduplication ────────────────────────────────────────────────────────────
  final _deduplicator = EventDeduplicator();

  // ── Diagnostics ──────────────────────────────────────────────────────────────
  int reconnectAttempts = 0;
  int heartbeatFailures = 0;
  DateTime? lastConnectedAt;
  final List<String> recentDisconnectReasons = [];

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Establish the WebSocket connection.
  Future<void> connect() async {
    if (kUseMockBackend || _disposed || _isConnecting) return;

    final user = _ref.read(authProvider);
    if (!user.isAuthenticated) return;

    _isConnecting = true;
    _setConnectionState(RealtimeConnectionState.connecting);

    try {
      final connectionId = ++_connectionGeneration;
      _closeChannel(manual: false);

      final token = _ref.read(sessionProvider).accessToken ?? '';
      if (token.isEmpty) {
        _scheduleReconnect('empty access token');
        return;
      }

      // Exchange a short-lived WebSocket ticket to avoid exposing the JWT
      // in URL logs of proxies, load balancers, or CDNs.
      final dio = _ref.read(apiClientProvider);
      final response = await dio.post('/auth/ws-ticket');
      final ticket = response.data['ticket'] as String?;

      // A newer connection attempt superseded this one while we awaited.
      if (connectionId != _connectionGeneration) return;

      if (ticket == null || ticket.isEmpty) {
        _scheduleReconnect('empty ws-ticket');
        return;
      }

      final baseUri = Uri.parse(kWebSocketUrl);
      final wsUri = baseUri.replace(
        queryParameters: {...baseUri.queryParameters, 'ticket': ticket},
      );

      _manualClose = false;
      _channel = IOWebSocketChannel.connect(wsUri);
      _reconnectAttempt = 0;
      lastConnectedAt = DateTime.now();

      _startHeartbeat();

      _channel!.stream.listen(
        (raw) => _onFrame(raw, connectionId),
        onError: (error) => _onSocketError('error: $error', connectionId),
        onDone: () => _onSocketClosed('done', connectionId),
        cancelOnError: true,
      );

      _setConnectionState(RealtimeConnectionState.connected);
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('[Realtime] Connection failed: $mapped');
      _scheduleReconnect('connect exception: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// Cleanly disconnect. Will not auto-reconnect.
  void disconnect({required bool manual}) {
    _closeChannel(manual: manual);
    _setConnectionState(RealtimeConnectionState.disconnected);
  }

  /// Emit a raw JSON frame over the socket.
  ///
  /// Feature modules must call this instead of accessing the channel directly.
  void emit(Map<String, dynamic> frame) {
    if (_channel == null) {
      debugPrint(
        '[Realtime] emit() called with no open channel; frame dropped.',
      );
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(frame));
    } catch (e) {
      debugPrint('[Realtime] emit() failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _connectionGeneration++;
    _deduplicator.dispose();
    _closeChannel(manual: true);
    _connectionStateController.close();
    _eventController.close();
  }

  // ─── Heartbeat ────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_disposed || _manualClose || _channel == null) return;
      try {
        _channel!.sink.add(
          jsonEncode({
            'event': 'ping',
            'data': {'ts': DateTime.now().toIso8601String()},
          }),
        );
      } catch (e) {
        heartbeatFailures++;
        debugPrint('[Realtime] Heartbeat ping failed: $e');
      }
    });
  }

  // ─── Reconnection ─────────────────────────────────────────────────────────

  static const _reconnectDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];

  void _scheduleReconnect(String reason) {
    if (_disposed || _manualClose) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _setConnectionState(RealtimeConnectionState.reconnecting);

    final index = _reconnectAttempt < _reconnectDelays.length
        ? _reconnectAttempt
        : _reconnectDelays.length - 1;
    final delay = _reconnectDelays[index];
    if (_reconnectAttempt < _reconnectDelays.length - 1) _reconnectAttempt++;

    reconnectAttempts++;
    _addDisconnectReason(reason);
    debugPrint(
      '[Realtime] Reconnecting in ${delay.inSeconds}s (attempt $reconnectAttempts). Reason: $reason',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_disposed || _manualClose) return;
      if (!_ref.read(authProvider).isAuthenticated) return;
      connect();
    });
  }

  void _addDisconnectReason(String reason) {
    recentDisconnectReasons.add(
      '${DateTime.now().toIso8601String()} — $reason',
    );
    if (recentDisconnectReasons.length > 20) {
      recentDisconnectReasons.removeAt(0);
    }
  }

  // ─── Socket lifecycle ─────────────────────────────────────────────────────

  void _closeChannel({required bool manual}) {
    _manualClose = manual;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('[Realtime] Error closing channel: $e');
    }
    _channel = null;
  }

  void _onSocketError(String reason, int connectionId) {
    if (connectionId != _connectionGeneration) return;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _channel = null;
    if (_disposed || _manualClose) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    _scheduleReconnect(reason);
  }

  void _onSocketClosed(String reason, int connectionId) {
    if (connectionId != _connectionGeneration) return;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _channel = null;
    if (_disposed || _manualClose) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    _scheduleReconnect(reason);
  }

  // ─── Frame parsing & routing ──────────────────────────────────────────────

  void _onFrame(dynamic raw, int connectionId) {
    if (connectionId != _connectionGeneration) return;
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final eventName = frame['event'] as String? ?? '';
      final data = frame['data'] as Map<String, dynamic>? ?? {};

      final event = _parse(eventName, data);
      if (event == null) return;

      // Deduplicate
      if (!_deduplicator.isNew(event.eventId)) {
        debugPrint('[Realtime] Duplicate event dropped: ${event.eventId}');
        return;
      }

      _eventController.add(event);
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      debugPrint('[Realtime] Failed to decode frame: $mapped');
    }
  }

  RealtimeEvent? _parse(String eventName, Map<String, dynamic> data) {
    final now = DateTime.now().millisecondsSinceEpoch.toString();

    switch (eventName) {
      case 'pong':
        return PongEvent(eventId: 'pong-$now', serverTs: data['ts'] as String?);

      case 'new_message':
        final id = data['id']?.toString() ?? now;
        return NewMessageEvent(
          eventId: 'msg-$id',
          id: id,
          sender: data['sender'] as String? ?? 'Unknown',
          text: data['text'] as String? ?? '',
          timestamp:
              DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
              DateTime.now(),
          receiver: data['receiver'] as String?,
        );

      case 'message_sent':
        final id = data['id']?.toString() ?? now;
        return MessageSentAckEvent(
          eventId: 'ack-$id',
          tempId: data['tempId'] as String? ?? id,
        );

      case 'typing':
      case 'typing_status':
        final sender = data['sender'] as String? ?? '';
        if (sender.isEmpty) return null;
        return TypingEvent(
          eventId: 'typing-$sender-$now',
          sender: sender,
          isTyping: data['isTyping'] as bool? ?? false,
        );

      case 'read_receipt':
        final sender = data['sender'] as String? ?? '';
        if (sender.isEmpty) return null;
        return ReadReceiptEvent(eventId: 'read-$sender-$now', sender: sender);

      case 'new_memory':
        final id = data['memoryId']?.toString() ?? now;
        return NewMemoryEvent(
          eventId: 'memory-$id',
          creatorName: data['creatorName'] as String? ?? 'A friend',
          creatorUsername: data['creatorUsername'] as String? ?? '',
          memoryId: data['memoryId'] as String?,
        );

      case 'new_reaction':
        final id = data['memoryId']?.toString() ?? now;
        return NewReactionEvent(
          eventId: 'reaction-$id-${data['reactorName'] ?? now}',
          reactorName: data['reactorName'] as String? ?? 'A friend',
          emoji: data['emoji'] as String? ?? '❤️',
          memoryCaption: data['memoryCaption'] as String? ?? 'your memory',
          memoryId: data['memoryId'] as String?,
        );

      case 'new_circle_request':
        final senderId = data['senderId']?.toString() ?? now;
        return CircleRequestEvent(
          eventId: 'circle-req-$senderId',
          senderId: senderId,
          senderUsername: data['senderUsername'] as String? ?? '',
          senderFirstName: data['senderFirstName'] as String? ?? '',
          senderAvatarUrl:
              data['senderAvatarUrl'] as String? ??
              data['senderAvatar'] as String?,
        );

      case 'new_circle_milestone':
        final ownerId = data['circleOwnerId']?.toString() ?? now;
        final milestone = data['milestone'] as int? ?? 0;
        return CircleMilestoneEvent(
          eventId: 'milestone-$ownerId-$milestone',
          circleOwnerId: ownerId,
          circleOwnerUsername: data['circleOwnerUsername'] as String? ?? '',
          milestone: milestone,
          members: (data['members'] as List? ?? [])
              .map((m) => m as Map<String, dynamic>)
              .toList(),
        );

      case 'presence':
        final username = data['username'] as String? ?? '';
        if (username.isEmpty) return null;
        final statusStr = data['status'] as String? ?? 'offline';
        final status = PresenceStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => PresenceStatus.offline,
        );
        return PresenceEvent(
          eventId: 'presence-$username-$now',
          username: username,
          status: status,
        );

      case 'connected':
        // Server confirms successful WS connection.
        // Update connection state — no state-changing event needed.
        _setConnectionState(RealtimeConnectionState.connected);
        return null;

      case 'auth_error':
        debugPrint(
          '[Realtime] auth_error received from server: ${data['message']}',
        );
        _setConnectionState(RealtimeConnectionState.authFailed);
        // Attempt a session refresh then reconnect
        _scheduleReconnect('auth_error from server');
        return null;

      case 'reaction_update':
        // A count update for the memory's whole audience — not a notification.
        final memoryId = data['memoryId']?.toString() ?? '';
        final emoji = data['emoji'] as String? ?? '';
        if (memoryId.isEmpty || emoji.isEmpty) return null;
        final count = (data['count'] as num?)?.toInt() ?? 0;
        return ReactionUpdateEvent(
          eventId: 'reaction-update-$memoryId-$emoji-$count',
          memoryId: memoryId,
          emoji: emoji,
          count: count,
        );

      default:
        return UnknownEvent(
          eventId: 'unknown-$eventName-$now',
          rawEventName: eventName,
        );
    }
  }
}
