import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../models/notification_item.dart';
import '../../core/structured_logger.dart';

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

      return {
        'notifications': notifications,
        'nextCursor': dataMap['nextCursor'] as String?,
        'unreadCount': dataMap['unreadCount'] as int? ?? 0,
      };
    } catch (e, st) {
      StructuredLogger.logError('Failed to fetch notifications', category: 'NotificationRepository', error: e, stackTrace: st);
      // Return empty defaults for mock/fallback robustness
      return {
        'notifications': <NotificationItem>[],
        'nextCursor': null,
        'unreadCount': 0,
      };
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/notifications/$notificationId/read');
    } catch (e, st) {
      StructuredLogger.logError('Failed to mark notification $notificationId as read', category: 'NotificationRepository', error: e, stackTrace: st);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/notifications/read-all');
    } catch (e, st) {
      StructuredLogger.logError('Failed to mark all notifications as read', category: 'NotificationRepository', error: e, stackTrace: st);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref);
});
