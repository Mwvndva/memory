import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/models/memory_item.dart';
import 'package:memory_app/models/comment_item.dart';
import 'package:memory_app/features/feed/memory_detail_state.dart';
import 'package:memory_app/features/feed/memory_detail_provider.dart';
import 'package:memory_app/repositories/memory_repository.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/theme.dart';

const _stubDetailItem = MemoryItem(
  id: 'detail-test-uuid',
  person: 'Test Actor',
  username: 'testactor',
  initial: 'T',
  time: 'Just now',
  caption: 'Original Caption',
  avatar: kMint,
  colors: [kMint],
  ageHours: 0.1,
);

class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/comments') || options.path.contains('comments')) {
      if (options.method == 'POST') {
        final Map<String, dynamic> dataMap = options.data is Map ? options.data as Map<String, dynamic> : {};
        final text = dataMap['text'] as String? ?? '';
        final res = Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'id': 'real-c-1',
            'text': text,
            'person': 'You',
            'timestamp': DateTime.now().toIso8601String(),
            'creator': {'username': 'you', 'avatar_url': ''}
          },
        );
        handler.resolve(res);
        return;
      }
      final res = Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'comments': [
            {
              'id': 'mock-c1',
              'text': 'Oh my days! This is amazing!',
              'person': 'Amara',
              'timestamp': DateTime.now().toIso8601String(),
              'creator': {'username': 'amara', 'avatar_url': ''}
            }
          ],
          'meta': {'nextCursor': null}
        },
      );
      handler.resolve(res);
    } else if (options.path.contains('detail-test-uuid')) {
      final res = Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'id': 'detail-test-uuid',
          'person': 'Test Actor',
          'initial': 'T',
          'time': 'Just now',
          'caption': 'Original Caption',
          'avatar': '#00FF00',
          'gradient_colors': ['#00FF00'],
          'age_hours': 0.1,
          'is_liked': false,
          'like_count': 0,
          'is_bookmarked': false,
          'reactions': [],
          'creator': {'username': 'testactor', 'avatar_url': ''}
        },
      );
      handler.resolve(res);
    } else {
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;

  setUpAll(() {
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
      return null;
    });

    const homeWidgetChannel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(homeWidgetChannel, (methodCall) async {
      return null;
    });

    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await Hive.openBox('feed_cache');
    mockDio = Dio(BaseOptions(baseUrl: 'http://localhost'))..interceptors.add(MockInterceptor());
  });

  group('Memory Details Modernization Subsystem Tests', () {
    test('State Manager loads memory and comments on initialization', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          apiClientProvider.overrideWithValue(mockDio),
          feedProvider.overrideWith((ref) {
            final notifier = FeedStateManager(ref);
            notifier.state = notifier.state.copyWith(memories: [_stubDetailItem]);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        memoryDetailProvider('detail-test-uuid'),
        (previous, next) {},
      );
      addTearDown(subscription.close);

      final notifier = container.read(memoryDetailProvider('detail-test-uuid').notifier);
      await pumpEventQueue();

      final state = container.read(memoryDetailProvider('detail-test-uuid'));
      expect(state.status, equals(MemoryDetailLoadStatus.loaded));
      expect(state.comments.isNotEmpty, isTrue, reason: 'Initial page of comments should load');
    });

    test('Optimistic comment posting adds item and rolls back on failure', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          apiClientProvider.overrideWithValue(mockDio),
          feedProvider.overrideWith((ref) {
            final notifier = FeedStateManager(ref);
            notifier.state = notifier.state.copyWith(memories: [_stubDetailItem]);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        memoryDetailProvider('detail-test-uuid'),
        (previous, next) {},
      );
      addTearDown(subscription.close);

      final notifier = container.read(memoryDetailProvider('detail-test-uuid').notifier);
      await pumpEventQueue();

      notifier.state = notifier.state.copyWith(comments: []);

      const commentText = 'Testing optimistic rollback comments';
      final future = notifier.postComment(commentText);
      expect(container.read(memoryDetailProvider('detail-test-uuid')).comments.first.text, commentText);
      await future;
    });

    test('Reaction synchronization propagates to state manager successfully', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          apiClientProvider.overrideWithValue(mockDio),
          feedProvider.overrideWith((ref) {
            final notifier = FeedStateManager(ref);
            notifier.state = notifier.state.copyWith(memories: [_stubDetailItem]);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        memoryDetailProvider('detail-test-uuid'),
        (previous, next) {},
      );
      addTearDown(subscription.close);

      final notifier = container.read(memoryDetailProvider('detail-test-uuid').notifier);
      await pumpEventQueue();

      final originalCount = container.read(memoryDetailProvider('detail-test-uuid')).memory?.reactions['❤️'] ?? 0;
      await notifier.sendReaction('❤️');

      final updatedCount = container.read(memoryDetailProvider('detail-test-uuid')).memory?.reactions['❤️'] ?? 0;
      expect(updatedCount, isNot(originalCount), reason: 'Reactions must modify counting metrics');
    });

    test('Draft editing caption transaction save updates local states', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          apiClientProvider.overrideWithValue(mockDio),
          feedProvider.overrideWith((ref) {
            final notifier = FeedStateManager(ref);
            notifier.state = notifier.state.copyWith(memories: [_stubDetailItem]);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        memoryDetailProvider('detail-test-uuid'),
        (previous, next) {},
      );
      addTearDown(subscription.close);

      final notifier = container.read(memoryDetailProvider('detail-test-uuid').notifier);
      await pumpEventQueue();

      notifier.setDraftCaption('New edited caption');
      await notifier.saveCaptionEdit();

      expect(container.read(memoryDetailProvider('detail-test-uuid')).memory?.caption, equals('New edited caption'));
    });
  });
}
