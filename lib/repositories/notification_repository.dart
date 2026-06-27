import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../models/notification_item.dart';

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
    } catch (_) {
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
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/notifications/read-all');
    } catch (_) {}
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref);
});
