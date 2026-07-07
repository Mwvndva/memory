import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/core/structured_logger.dart';

class NotificationRepository {
  NotificationRepository(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> fetchNotifications({String? cursor, int limit = 20}) async {
    try {
      final dio = _ref.read(apiClientProvider);
      final cursorParam = cursor != null ? '?cursor=$cursor' : '';
      final response = await dio.get('/notifications$cursorParam');

      final dataMap = response.data as Map<String, dynamic>? ?? {};
      final list = dataMap['data'] as List? ?? [];
      final notifications = list
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final unreadCount = dataMap['unreadCount'] as int? ?? 0;

      // Leverage cache service for first page of notifications
      if (cursor == null) {
        await _ref.read(notificationCacheProvider).cacheNotifications(notifications);
      }

      // Update system badge count
      await _ref.read(badgeServiceProvider).setBadgeCount(unreadCount);

      return {
        'notifications': notifications,
        'nextCursor': dataMap['nextCursor'] as String?,
        'unreadCount': unreadCount,
      };
    } catch (e, st) {
      StructuredLogger.logError('Failed to fetch notifications', category: 'NotificationRepository', error: e, stackTrace: st);
      
      // Fallback to local cache if network request fails
      final cached = _ref.read(notificationCacheProvider).getCachedNotifications();
      final unreadCount = cached.where((n) => !n.isRead).length;

      return {
        'notifications': cached,
        'nextCursor': null,
        'unreadCount': unreadCount,
      };
    }
  }

  Future<void> markAsRead(String notificationId) async {
    // Publish notification read event to the event bus
    _ref.read(notificationEventBusProvider).fire(NotificationReadEvent(notificationId));

    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/notifications/$notificationId/read');

      // Update cache
      final cache = _ref.read(notificationCacheProvider);
      final cached = cache.getCachedNotifications();
      final updated = cached.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      await cache.cacheNotifications(updated);

      // Update badge count
      final unreadCount = updated.where((n) => !n.isRead).length;
      await _ref.read(badgeServiceProvider).setBadgeCount(unreadCount);
    } catch (e, st) {
      StructuredLogger.logError('Failed to mark notification $notificationId as read', category: 'NotificationRepository', error: e, stackTrace: st);
    }
  }

  Future<void> markAllAsRead() async {
    // Publish all read event to the event bus
    _ref.read(notificationEventBusProvider).fire(AllNotificationsReadEvent());

    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/notifications/read-all');

      // Update cache
      final cache = _ref.read(notificationCacheProvider);
      final cached = cache.getCachedNotifications();
      final updated = cached.map((n) => n.copyWith(isRead: true)).toList();
      await cache.cacheNotifications(updated);

      // Clear system badge
      await _ref.read(badgeServiceProvider).clearBadge();
    } catch (e, st) {
      StructuredLogger.logError('Failed to mark all notifications as read', category: 'NotificationRepository', error: e, stackTrace: st);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref);
});

