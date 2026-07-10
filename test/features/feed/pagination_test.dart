import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/design_system/design_system.dart';

/// A fully-mocked [MemoryRepository] that never hits the network.
/// - fetchFeed(cursor: null) returns page 1 + a nextCursor token.
/// - fetchFeed(cursor: 'page-2-cursor') returns page 2 + null nextCursor.
/// - getCachedFeed returns [] so Hive is never accessed in tests.
class MockMemoryRepository extends MemoryRepository {
  MockMemoryRepository(super.ref);

  @override
  List<MemoryItem> getCachedFeed() => const [];

  @override
  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    if (cursor == null) {
      // Page 1 - initial load driven by _initFeed
      return const FeedPageResult(
        memories: [
          MemoryItem(
            id: 'test-alice-1',
            person: 'Alice',
            username: 'alice',
            initial: 'A',
            time: '1 hour ago',
            caption: 'Morning run',
            avatar: MemoryColors.mint,
            colors: [MemoryColors.mint, MemoryColors.sky],
            ageHours: 1,
          ),
        ],
        nextCursor: 'page-2-cursor',
      );
    }
    if (cursor == 'page-2-cursor') {
      // Page 2 - last page, triggered by loadMore
      return const FeedPageResult(
        memories: [
          MemoryItem(
            id: 'test-zoe-2',
            person: 'Zoe',
            username: 'zoe',
            initial: 'Z',
            time: 'Yesterday',
            caption: 'Stretching after run',
            avatar: MemoryColors.accent,
            colors: [MemoryColors.accent, MemoryColors.mint],
            ageHours: 26,
          ),
        ],
        nextCursor: null,
      );
    }
    return const FeedPageResult(memories: [], nextCursor: null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deterministic Pagination Engine Tests', () {
    test('FeedState copyWith retains cursor fields', () {
      final state = FeedState(
        memories: const [],
        status: FeedLoadStatus.idle,
        hasMore: true,
        currentCursor: 'c1',
        nextCursor: 'c2',
      );
      expect(state.currentCursor, equals('c1'));
      expect(state.nextCursor, equals('c2'));
      expect(state.hasMore, isTrue);
    });

    test('FeedStateManager prevents concurrent pagination requests', () async {
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWith(
            (ref) => MockMemoryRepository(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(feedProvider.notifier);

      // Drain all pending async tasks so that _initFeed completes fully
      // before we begin the pagination test.
      await pumpEventQueue();

      // After init, feed should be loaded with page 1 data and a pending cursor.
      final initState = container.read(feedProvider);
      expect(
        initState.status,
        equals(FeedLoadStatus.loaded),
        reason: 'Expected feed to be loaded after init',
      );
      expect(
        initState.nextCursor,
        equals('page-2-cursor'),
        reason: 'Expected nextCursor after page 1',
      );
      expect(
        initState.memories.length,
        equals(1),
        reason: 'Expected 1 memory after page 1',
      );

      // Trigger loadMore three times concurrently.
      // Only the first call should proceed; the other two hit the concurrency guard.
      final f1 = notifier.loadMore();
      final f2 = notifier.loadMore();
      final f3 = notifier.loadMore();

      await Future.wait([f1, f2, f3]);

      // After loadMore resolves we should have page 2 appended and no more pages.
      final finalState = container.read(feedProvider);
      expect(finalState.status, equals(FeedLoadStatus.loaded));
      expect(finalState.currentCursor, equals('page-2-cursor'));
      expect(finalState.nextCursor, isNull);
      expect(finalState.hasMore, isFalse);
      expect(finalState.memories.length, equals(2)); // page 1 + page 2
    });
  });
}
