import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/realtime/realtime_event.dart';
import 'package:memory_app/realtime/realtime_providers.dart';

class NotificationStateManager extends StateNotifier<NotificationState> {
  NotificationStateManager(this._ref)
    : super(const NotificationState(notifications: [], unreadCount: 0)) {
    Future.microtask(() {
      _listenToRealtimeEvents();
    });
  }

  final Ref _ref;
  ProviderSubscription? _eventSubscription;

  void _listenToRealtimeEvents() {
    _eventSubscription = _ref.listen<AsyncValue<RealtimeEvent>>(
      realtimeEventStreamProvider,
      (_, next) {
        next.whenData((event) {
          _handleRealtimeEvent(event);
        });
      },
    );
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    NotificationItem? item;
    switch (event) {
      case NewMessageEvent():
        item = NotificationItem(
          id: event.eventId,
          title: 'New Message from ${event.sender} 💬',
          body: event.text,
          timestamp: event.timestamp,
          isRead: false,
          type: NotificationType.message,
          data: {'sender': event.sender},
        );
      case NewMemoryEvent():
        item = NotificationItem(
          id: event.eventId,
          title: 'New Memory 📸',
          body: '${event.creatorName} shared a new memory.',
          timestamp: DateTime.now(),
          isRead: false,
          type: NotificationType.memory,
          data: {'creatorUsername': event.creatorUsername},
        );
      case NewReactionEvent():
        item = NotificationItem(
          id: event.eventId,
          title: 'New Reaction ${event.emoji} ❤️',
          body:
              '${event.reactorName} reacted to your memory: "${event.memoryCaption}".',
          timestamp: DateTime.now(),
          isRead: false,
          type: NotificationType.reaction,
          data: {'memoryId': event.memoryId ?? ''},
        );
      case CircleRequestEvent():
        item = NotificationItem(
          id: event.eventId,
          title: 'Circle Request 👥',
          body:
              '${event.senderFirstName} (@${event.senderUsername}) wants to join your circle.',
          timestamp: DateTime.now(),
          isRead: false,
          type: NotificationType.circleRequest,
          data: {'senderUsername': event.senderUsername},
        );
      case CircleMilestoneEvent():
        item = NotificationItem(
          id: event.eventId,
          title: 'Circle Milestone! 🎉',
          body:
              '@${event.circleOwnerUsername}\'s circle reached a ${event.milestone}-user milestone!',
          timestamp: DateTime.now(),
          isRead: false,
          type: NotificationType.circleMilestone,
          data: {'milestone': event.milestone.toString()},
        );
      default:
        break;
    }

    if (item != null) {
      _reconcileAndIngest(item);
    }
  }

  void handlePushNotification(
    String title,
    String body,
    Map<String, dynamic> rawData,
  ) {
    final typeName = rawData['type'] as String? ?? 'message';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => NotificationType.message,
    );

    final item = NotificationItem(
      id:
          rawData['id']?.toString() ??
          'push-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      data: Map<String, String>.from(rawData['data'] ?? {}),
    );

    _reconcileAndIngest(item);
  }

  void _reconcileAndIngest(NotificationItem incoming) {
    final existing = state.notifications;
    if (existing.any((n) => n.id == incoming.id)) return; // Deduplicated

    final updatedList = [incoming, ...existing];
    // Sort descending by timestamp
    updatedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: state.unreadCount + 1,
    );
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications(limit: 20);
      final list = res['notifications'] as List<NotificationItem>;

      state = state.copyWith(
        notifications: list,
        unreadCount: list.where((n) => !n.isRead).length,
        cursor: res['nextCursor'] as String?,
        hasMore: res['nextCursor'] != null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.cursor == null) return;
    state = state.copyWith(isLoading: true);

    try {
      final repo = _ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications(
        cursor: state.cursor,
        limit: 20,
      );

      final nextList = res['notifications'] as List<NotificationItem>;
      final merged = [...state.notifications];

      for (final item in nextList) {
        if (!merged.any((n) => n.id == item.id)) {
          merged.add(item);
        }
      }
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = state.copyWith(
        notifications: merged,
        cursor: res['nextCursor'] as String?,
        hasMore: res['nextCursor'] != null,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAsRead(String id) async {
    final repo = _ref.read(notificationRepositoryProvider);
    unawaited(repo.markAsRead(id));

    final updated = state.notifications.map((n) {
      if (n.id == id && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
  }

  Future<void> markAllAsRead() async {
    final repo = _ref.read(notificationRepositoryProvider);
    unawaited(repo.markAllAsRead());

    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    state = state.copyWith(notifications: updated, unreadCount: 0);
  }

  @override
  void dispose() {
    _eventSubscription?.close();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationStateManager, NotificationState>((ref) {
      return NotificationStateManager(ref);
    });
