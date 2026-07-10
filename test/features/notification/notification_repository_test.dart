import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/theme.dart'; // sharedPreferencesProvider
import 'package:memory_app/features/notification/notification.dart';

/// Serves the payloads emitted by the backend's NotificationsController:
///
///   GET  /notifications      → { data: [...], nextCursor, unreadCount }
///   POST /notifications/:id/read
///   POST /notifications/read-all
class _NotificationsApiInterceptor extends Interceptor {
  _NotificationsApiInterceptor({this.failList = false});

  /// Simulates the endpoint being unreachable (this is what a 404 looked like
  /// before the backend existed — the repository silently fell back to cache).
  final bool failList;
  final List<RequestOptions> requests = [];

  static Map<String, dynamic> item({
    required String id,
    required String type,
    bool isRead = false,
    String timestamp = '2026-07-01T12:00:00.000Z',
  }) => {
    'id': id,
    'title': 'New Reaction',
    'body': '@amara reacted 🔥 to your memory',
    'timestamp': timestamp,
    'isRead': isRead,
    'type': type,
    'data': {'event': 'new_reaction', 'memoryId': 'm-1'},
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);

    if (options.method == 'GET' && options.path.startsWith('/notifications')) {
      if (failList) {
        handler.reject(
          DioException(requestOptions: options, error: 'network down'),
        );
        return;
      }
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': [
              item(id: 'n1', type: 'reaction'),
              item(id: 'n2', type: 'circleRequest', isRead: true),
            ],
            'nextCursor': '2026-07-01T11:00:00.000Z',
            'unreadCount': 3,
          },
        ),
      );
      return;
    }

    if (options.method == 'POST') {
      handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: {'ok': true}),
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        error: 'Unexpected ${options.method} ${options.path}',
      ),
    );
  }
}

Future<ProviderContainer> _container(
  _NotificationsApiInterceptor interceptor,
) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..interceptors.add(interceptor);
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(dio),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
}

void main() {
  // BadgeService talks to a MethodChannel; the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fetchNotifications parses the backend page shape', () async {
    final interceptor = _NotificationsApiInterceptor();
    final container = await _container(interceptor);

    final result = await container
        .read(notificationRepositoryProvider)
        .fetchNotifications();

    final items = result['notifications'] as List<NotificationItem>;
    expect(items, hasLength(2));
    expect(result['nextCursor'], '2026-07-01T11:00:00.000Z');
    expect(result['unreadCount'], 3);

    expect(items[0].id, 'n1');
    expect(items[0].type, NotificationType.reaction);
    expect(items[0].isRead, isFalse);
    expect(items[0].timestamp, DateTime.parse('2026-07-01T12:00:00.000Z'));
    expect(items[0].data['memoryId'], 'm-1');

    // Every type name the backend emits must map onto the client enum.
    expect(items[1].type, NotificationType.circleRequest);
    expect(items[1].isRead, isTrue);
  });

  test('fetchNotifications appends the cursor as a query string', () async {
    final interceptor = _NotificationsApiInterceptor();
    final container = await _container(interceptor);

    await container
        .read(notificationRepositoryProvider)
        .fetchNotifications(cursor: '2026-07-01T10:00:00.000Z');

    expect(interceptor.requests.single.path, contains('cursor='));
  });

  test(
    'first page is cached, and served when the network later fails',
    () async {
      // Populate the cache from a successful call.
      final ok = await _container(_NotificationsApiInterceptor());
      await ok.read(notificationRepositoryProvider).fetchNotifications();

      // A subsequent failure must fall back to that cache rather than throw.
      final down = await _container(
        _NotificationsApiInterceptor(failList: true),
      );
      final result = await down
          .read(notificationRepositoryProvider)
          .fetchNotifications();

      final items = result['notifications'] as List<NotificationItem>;
      expect(items, hasLength(2));
      expect(result['nextCursor'], isNull);
      // One of the two cached rows was unread.
      expect(result['unreadCount'], 1);
    },
  );

  test('markAsRead posts to the notification and updates the cache', () async {
    final interceptor = _NotificationsApiInterceptor();
    final container = await _container(interceptor);
    final repo = container.read(notificationRepositoryProvider);

    await repo.fetchNotifications();
    await repo.markAsRead('n1');

    expect(
      interceptor.requests.map((r) => r.path),
      contains('/notifications/n1/read'),
    );

    final cached = container
        .read(notificationCacheProvider)
        .getCachedNotifications();
    expect(cached.firstWhere((n) => n.id == 'n1').isRead, isTrue);
  });

  test('markAllAsRead posts to read-all and clears unread in cache', () async {
    final interceptor = _NotificationsApiInterceptor();
    final container = await _container(interceptor);
    final repo = container.read(notificationRepositoryProvider);

    await repo.fetchNotifications();
    await repo.markAllAsRead();

    expect(
      interceptor.requests.map((r) => r.path),
      contains('/notifications/read-all'),
    );

    final cached = container
        .read(notificationCacheProvider)
        .getCachedNotifications();
    expect(cached.every((n) => n.isRead), isTrue);
  });
}
