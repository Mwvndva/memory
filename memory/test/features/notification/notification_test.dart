import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/app_providers.dart';

class _FakeSessionManager extends StateNotifier<SessionState>
    implements SessionManager {
  _FakeSessionManager()
    : super(
        SessionState(
          isAuthenticated: false,
          user: const UserProfile(
            firstName: 'Test',
            lastName: 'User',
            username: 'testuser',
            email: 'test@test.com',
            phone: '+10000000000',
            isAuthenticated: true,
          ),
          accessToken: '',
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockNotificationRepository extends NotificationRepository {
  MockNotificationRepository(super.ref);

  List<NotificationItem> items = [];

  @override
  Future<Map<String, dynamic>> fetchNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    return {
      'notifications': items,
      'nextCursor': null,
      'unreadCount': items.where((i) => !i.isRead).length,
    };
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final idx = items.indexWhere((i) => i.id == notificationId);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    items = items.map((i) => i.copyWith(isRead: true)).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);

    SharedPreferences.setMockInitialValues({});
  });

  group('Notifications Modernization Architecture Tests', () {
    test(
      'State Manager ingests, orders, and de-duplicates events correctly',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionProvider.overrideWith((_) => _FakeSessionManager()),
            authProvider.overrideWithValue(
              const UserProfile(
                firstName: 'Test',
                lastName: 'User',
                username: 'testuser',
                email: 'test@test.com',
                phone: '+10000000000',
                isAuthenticated: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(notificationProvider.notifier);

        // Trigger ingestion from realtime handlers
        notifier.handlePushNotification('New Message from Amara 💬', 'Hello!', {
          'id': 'msg-123',
          'type': 'message',
          'data': {'sender': 'Amara'},
        });

        notifier.handlePushNotification(
          'New Message from Amara 💬',
          'Hello duplicate!',
          {
            'id': 'msg-123',
            'type': 'message',
            'data': {'sender': 'Amara'},
          },
        );

        final state = container.read(notificationProvider);
        expect(state.notifications.length, 1);
        expect(state.unreadCount, 1);
      },
    );

    test(
      'Read status management synchronizes lists and badge counts correctly',
      () async {
        final prefs = await SharedPreferences.getInstance();
        late MockNotificationRepository mockRepo;
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionProvider.overrideWith((_) => _FakeSessionManager()),
            authProvider.overrideWithValue(
              const UserProfile(
                firstName: 'Test',
                lastName: 'User',
                username: 'testuser',
                email: 'test@test.com',
                phone: '+10000000000',
                isAuthenticated: false,
              ),
            ),
            notificationRepositoryProvider.overrideWith((ref) {
              mockRepo = MockNotificationRepository(ref);
              mockRepo.items = [
                NotificationItem(
                  id: 'notif-1',
                  title: 'Title 1',
                  body: 'Body 1',
                  timestamp: DateTime.now(),
                  isRead: false,
                  type: NotificationType.message,
                  data: {},
                ),
                NotificationItem(
                  id: 'notif-2',
                  title: 'Title 2',
                  body: 'Body 2',
                  timestamp: DateTime.now(),
                  isRead: false,
                  type: NotificationType.reaction,
                  data: {},
                ),
              ];
              return mockRepo;
            }),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(notificationProvider.notifier);
        await pumpEventQueue();
        await notifier.loadInitial();

        expect(container.read(notificationProvider).unreadCount, 2);

        await notifier.markAsRead('notif-1');
        expect(container.read(notificationProvider).unreadCount, 1);
        expect(
          container
              .read(notificationProvider)
              .notifications
              .firstWhere((n) => n.id == 'notif-1')
              .isRead,
          true,
        );

        await notifier.markAllAsRead();
        expect(container.read(notificationProvider).unreadCount, 0);
      },
    );
  });
}
