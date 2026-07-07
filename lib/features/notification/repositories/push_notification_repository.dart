import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/router.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/features/auth/auth.dart';

class PushNotificationRepository {
  PushNotificationRepository(this._ref) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  void _init() {
    // Listen to authentication changes to register/unregister tokens
    _ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        registerDeviceToken();
        _subscribeToMessages();
      } else if (!next.isAuthenticated && (previous?.isAuthenticated ?? false)) {
        _unsubscribe();
      }
    });

    // If already authenticated on startup, register token immediately
    final authState = _ref.read(authProvider);
    if (authState.isAuthenticated) {
      registerDeviceToken();
      _subscribeToMessages();
    }
  }

  Future<void> registerDeviceToken() async {
    if (kIsWeb) return; // Push notifications are mobile-only for this app config

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Fetch the FCM registration token
        final token = await messaging.getToken();
        if (token != null) {
          await _uploadToken(token);
        }

        // 3. Listen to token refreshes
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) async {
          await _uploadToken(newToken);
        });
      }
    } catch (e) {
      debugPrint('Error registering Firebase device token: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final dio = _ref.read(apiClientProvider);
      await dio.post('/users/me/fcm', data: {
        'fcmToken': token,
      });
      debugPrint('Firebase FCM device token registered successfully.');
    } catch (e) {
      debugPrint('Failed to upload FCM device token to backend: $e');
    }
  }

  void _subscribeToMessages() {
    if (kIsWeb) return;

    try {
      _foregroundMessageSubscription?.cancel();
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          final title = notification.title ?? 'Memory Alert';
          final body = notification.body ?? '';

          // Route to the Notification State Manager
          _ref.read(notificationProvider.notifier).handlePushNotification(
            title,
            body,
            message.data,
          );

          showGlobalNotification(
            title: title,
            body: body,
            onTap: () {
              final context = rootNavigatorKey.currentContext;
              if (context != null) {
                final event = message.data['event'] as String?;
                if (event == 'new_message') {
                  final sender = message.data['sender'] as String?;
                  if (sender != null) {
                    context.push('/chat/$sender');
                    return;
                  }
                }
                context.go('/feed');
              }
            },
          );
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to Firebase foreground messages: $e');
    }
  }

  void _unsubscribe() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = null;
  }

  void dispose() {
    _unsubscribe();
  }
}

final pushNotificationRepositoryProvider = Provider<PushNotificationRepository>((ref) {
  final repo = PushNotificationRepository(ref);
  ref.onDispose(() => repo.dispose());
  return repo;
});
