import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/theme.dart';

const _stubItem = MemoryItem(
  id: 'refresh-test-uuid',
  person: 'Test Bot',
  username: 'testbot',
  initial: 'T',
  time: 'Just now',
  caption: 'Testing cache refresh',
  avatar: kMint,
  colors: [kMint],
  ageHours: 0.1,
);

class MockMemoryRepositoryForRefresh extends MemoryRepository {
  int fetchCallCount = 0;

  MockMemoryRepositoryForRefresh(super.ref);

  @override
  List<MemoryItem> getCachedFeed() => const [];

  @override
  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    fetchCallCount++;
    return const FeedPageResult(
      memories: [_stubItem],
      nextCursor: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock platforms method channels to bypass secure storage / shared preferences failures
  setUpAll(() {
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
      if (methodCall.method == 'read') return null;
      if (methodCall.method == 'write') return true;
      if (methodCall.method == 'delete') return true;
      return null;
    });

    SharedPreferences.setMockInitialValues({});
  });

  group('Centralized Feed Refresh and Cache Invalidation Policy Tests', () {
    test('User-initiated refresh always proceeds, system/automated requests are throttled (5s)', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      late MockMemoryRepositoryForRefresh mockRepo;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          memoryRepositoryProvider.overrideWith((ref) {
            mockRepo = MockMemoryRepositoryForRefresh(ref);
            return mockRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(feedProvider.notifier);
      await pumpEventQueue();

      // Clear count after initial loading sequence (initial load fetchFeed completes async)
      mockRepo.fetchCallCount = 0;

      // 1. Trigger automated reload (force = false) with force override so first one doesn't get throttled
      await notifier.fetchFeed(force: true);
      expect(mockRepo.fetchCallCount, 1);

      // 2. Trigger another automated reload immediately - should get throttled/ignored
      await notifier.fetchFeed(force: false);
      expect(mockRepo.fetchCallCount, 1, reason: 'System request within 5s must be throttled');

      // 3. User-initiated Pull-To-Refresh (force = true) - must bypass throttling and reload
      await notifier.refreshFeed(force: true);
      expect(mockRepo.fetchCallCount, 2, reason: 'User force refresh must bypass throttling');
    });

    test('Account switches clear state manager indices and memory states', () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          memoryRepositoryProvider.overrideWith((ref) => MockMemoryRepositoryForRefresh(ref)),
        ],
      );
      addTearDown(container.dispose);

      // Construct notifier first to register its auth listener
      final notifier = container.read(feedProvider.notifier);
      await pumpEventQueue();

      // Explicitly login to populate some memories first via mock authentication
      container.read(sessionProvider.notifier).authenticate();
      await pumpEventQueue();

      // Trigger load to actually load memories since authenticated is true
      await notifier.fetchFeed(force: true);
      await pumpEventQueue();

      // Feed should have our stub item from mock repo
      expect(container.read(feedProvider).memories.length, 1);

      // Trigger logout via session notifier profile change (isAuthenticated = false)
      await container.read(sessionProvider.notifier).logout();
      await pumpEventQueue();

      // State should be completely reset
      expect(container.read(feedProvider).memories, isEmpty, reason: 'Feed state must clear upon logout');
    });
  });
}
