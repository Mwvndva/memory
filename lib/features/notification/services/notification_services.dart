import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/core/theme.dart'; // contains sharedPreferencesProvider

// Event Bus Events
abstract class NotificationEvent {}

class NotificationReceivedEvent extends NotificationEvent {
  final NotificationItem notification;
  NotificationReceivedEvent(this.notification);
}

class NotificationReadEvent extends NotificationEvent {
  final String id;
  NotificationReadEvent(this.id);
}

class AllNotificationsReadEvent extends NotificationEvent {}

class NotificationPreferencesChangedEvent extends NotificationEvent {
  final NotificationType type;
  final bool enabled;
  NotificationPreferencesChangedEvent(this.type, this.enabled);
}

// NotificationEventBus
class NotificationEventBus {
  final _controller = StreamController<NotificationEvent>.broadcast();

  Stream<T> on<T extends NotificationEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void fire(NotificationEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

// NotificationCache
class NotificationCache {
  final SharedPreferences _prefs;
  static const String _cacheKey = 'cached_notifications_list';

  NotificationCache(this._prefs);

  Future<void> cacheNotifications(List<NotificationItem> items) async {
    final jsonList = items.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_cacheKey, jsonList);
  }

  List<NotificationItem> getCachedNotifications() {
    final jsonList = _prefs.getStringList(_cacheKey);
    if (jsonList == null) return [];
    return jsonList.map((e) {
      try {
        return NotificationItem.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<NotificationItem>().toList();
  }

  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
  }
}

// NotificationPreferencesService
class NotificationPreferencesService {
  final SharedPreferences _prefs;
  static const String _prefix = 'notification_preference_';

  NotificationPreferencesService(this._prefs);

  bool isNotificationTypeEnabled(NotificationType type) {
    return _prefs.getBool('$_prefix${type.name}') ?? true;
  }

  Future<void> setNotificationTypeEnabled(NotificationType type, bool enabled) async {
    await _prefs.setBool('$_prefix${type.name}', enabled);
  }

  bool isAllNotificationsEnabled() {
    return _prefs.getBool('${_prefix}all') ?? true;
  }

  Future<void> setAllNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('${_prefix}all', enabled);
  }
}

// BadgeService
class BadgeService {
  static const MethodChannel _channel = MethodChannel('com.memory.app/badge');
  int _currentBadgeCount = 0;

  int get currentBadgeCount => _currentBadgeCount;

  Future<void> setBadgeCount(int count) async {
    _currentBadgeCount = count;
    try {
      await _channel.invokeMethod('setBadgeCount', {'count': count});
    } catch (e) {
      // Fail silently if platform channel is not implemented
    }
  }

  Future<void> clearBadge() async {
    await setBadgeCount(0);
  }
}

// Providers
final notificationEventBusProvider = Provider<NotificationEventBus>((ref) {
  final bus = NotificationEventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

final notificationCacheProvider = Provider<NotificationCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationCache(prefs);
});

final notificationPreferencesServiceProvider = Provider<NotificationPreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationPreferencesService(prefs);
});

final badgeServiceProvider = Provider<BadgeService>((ref) {
  return BadgeService();
});
