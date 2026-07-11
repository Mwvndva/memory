import 'package:memory_app/features/notification/notification.dart';

class NotificationState {
  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    this.isLoading = false,
    this.hasMore = false,
    this.cursor,
    this.errorMessage,
  });

  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool isLoading;
  final bool hasMore;
  final String? cursor;
  final String? errorMessage;

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
    bool? isLoading,
    bool? hasMore,
    String? cursor,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
