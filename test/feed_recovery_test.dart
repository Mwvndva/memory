import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/models/memory_item.dart';
import 'package:memory_app/repositories/memory_repository.dart';
import 'package:memory_app/core/theme.dart';

const _stubItem = MemoryItem(
  id: 'recovery-test-uuid',
  person: 'Test Bot',
  username: 'testbot',
  initial: 'T',
  time: 'Just now',
  caption: 'Testing recovery states',
  avatar: kMint,
  colors: [kMint],
  ageHours: 0.1,
);

class MockMemoryRepositoryWithErrors extends MemoryRepository {
  bool failNext = false;
  bool isTimeout = false;

  MockMemoryRepositoryWithErrors(super.ref);

  @override
  List<MemoryItem> getCachedFeed() => const [];

  @override
  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    if (failNext) {
      if (isTimeout) {
        throw DioException(
          requestOptions: RequestOptions(path: '/feed'),
          type: DioExceptionType.connectionTimeout,
          error: 'Connection timed out',
        );
      } else {
        throw DioException(
          requestOptions: RequestOptions(path: '/feed'),
          type: DioExceptionType.connectionError,
          error: 'SocketException: Connection refused',
        );
      }
    }
    return const FeedPageResult(
      memories: [_stubItem],
      nextCursor: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  group('Feed Recovery Framework Tests', () {
    test('Initial load network failures map correctly to network recovery category', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      late MockMemoryRepositoryWithErrors mockRepo;
      
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          memoryRepositoryProvider.overrideWith((ref) {
            mockRepo = MockMemoryRepositoryWithErrors(ref);
            mockRepo.failNext = true; // Set early to fail during init fetch
            return mockRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      // Listen to feedProvider to catch any async uncaught exceptions during read
      container.listen(feedProvider, (previous, next) {}, onError: (err, stack) {});

      try {
        container.read(feedProvider.notifier);
      } catch (_) {}
      await pumpEventQueue();

      final state = container.read(feedProvider);
      expect(state.status, equals(FeedLoadStatus.error));
      expect(state.errorCategory, equals(FeedErrorCategory.network));
      expect(state.isOffline, isTrue);
    });

    test('Refresh failure preserves the existing loaded memory list', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      late MockMemoryRepositoryWithErrors mockRepo;
      
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          memoryRepositoryProvider.overrideWith((ref) {
            mockRepo = MockMemoryRepositoryWithErrors(ref);
            return mockRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(feedProvider.notifier);

      // Load initially successfully
      mockRepo.failNext = false;
      await notifier.fetchFeed(force: true);
      await pumpEventQueue();

      expect(container.read(feedProvider).memories.length, 1);

      // Trigger refresh offline
      mockRepo.failNext = true;
      mockRepo.isTimeout = false;

      try {
        await notifier.refreshFeed(force: true);
      } catch (_) {}
      await pumpEventQueue();

      // State status error but memories are retained
      final state = container.read(feedProvider);
      expect(state.memories.length, 1, reason: 'Feed list must not be cleared on refresh failures');
      expect(state.errorCategory, equals(FeedErrorCategory.network));
    });
  });
}
