import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/notification_item.dart';

class NotificationRouter {
  static void routeToDestination(BuildContext context, NotificationItem item) {
    switch (item.type) {
      case NotificationType.message:
        final sender = item.data['sender'];
        if (sender != null && sender.isNotEmpty) {
          context.push('/chat/$sender');
        } else {
          context.go('/circle');
        }
      case NotificationType.memory:
      case NotificationType.reaction:
        final memoryId = item.data['memoryId'];
        if (memoryId != null && memoryId.isNotEmpty) {
          context.push('/memory/$memoryId');
        } else {
          context.go('/feed');
        }
      case NotificationType.circleRequest:
        context.go('/circle');
      case NotificationType.circleMilestone:
        context.go('/circle');
    }
  }
}
