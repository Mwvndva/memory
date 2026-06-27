import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/models/memory_item.dart';
import 'package:memory_app/repositories/memory_repository.dart';
import 'package:memory_app/repositories/optimistic_transaction_manager.dart';
import 'package:memory_app/core/theme.dart';

const _testItem = MemoryItem(
  id: 'optimistic-test-1',
  person: 'Tester',
  username: 'tester',
  initial: 'T',
  time: '10 min ago',
  caption: 'Testing optimistic updates',
  avatar: kMint,
  colors: [kMint],
  ageHours: 0.1,
  isLiked: false,
  likeCount: 5,
  isBookmarked: false,
  reactions: {},
);

class MockMemoryRepositoryWithFailure extends MemoryRepository {
  bool shouldFail = false;
  int toggleLikeCallCount = 0;

  MockMemoryRepositoryWithFailure(super.ref);

  @override
  List<MemoryItem> getCachedFeed() => const [];

  @override
  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    return const FeedPageResult(
      memories: [_testItem],
      nextCursor: null,
    );
  }

  @override
  Future<void> toggleLike(String memoryId, bool isLiked) async {
    toggleLikeCallCount++;
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldFail) {
      throw Exception('Fake Network Failure');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transactional Optimistic updates and Rollback tests', () {
    test('UI updates immediately, commits on success, and rolls back on failure', () async {
      late MockMemoryRepositoryWithFailure mockRepo;
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWith((ref) {
            mockRepo = MockMemoryRepositoryWithFailure(ref);
            return mockRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(feedProvider.notifier);
      await pumpEventQueue(); // settle initialization

      // Verify initial state
      var currentFeed = container.read(feedProvider).memories;
      expect(currentFeed.length, 1);
      expect(currentFeed.first.isLiked, isFalse);
      expect(currentFeed.first.likeCount, 5);

      // Scenario 1: Success Path
      mockRepo.shouldFail = false;
      final f1 = notifier.toggleLike('optimistic-test-1');
      
      // UI state must have changed immediately (synchronously after dispatch)
      expect(container.read(feedProvider).memories.first.isLiked, isTrue);
      expect(container.read(feedProvider).memories.first.likeCount, 6);
      expect(notifier.txManager.pendingCount, 1);

      await f1; // await network operation
      expect(notifier.txManager.pendingCount, 0);
      expect(container.read(feedProvider).memories.first.isLiked, isTrue);
      expect(container.read(feedProvider).memories.first.likeCount, 6);

      // Scenario 2: Duplicate Prevention (Ignore request during pending)
      mockRepo.shouldFail = false;
      
      // Trigger first like (toggles back to false)
      final f2 = notifier.toggleLike('optimistic-test-1');
      expect(container.read(feedProvider).memories.first.isLiked, isFalse);
      expect(container.read(feedProvider).memories.first.likeCount, 5);
      
      // Trigger duplicate toggle immediately
      final f3 = notifier.toggleLike('optimistic-test-1');
      
      await Future.wait([f2, f3]);
      expect(mockRepo.toggleLikeCallCount, 2, reason: 'Duplicate call must be ignored while a transaction is pending');

      // Scenario 3: Failure Path & Revert/Rollback
      mockRepo.shouldFail = true;
      
      // Try to like again (turns true)
      final f4 = notifier.toggleLike('optimistic-test-1');
      expect(container.read(feedProvider).memories.first.isLiked, isTrue);
      expect(container.read(feedProvider).memories.first.likeCount, 6);

      try {
        await f4;
      } catch (_) {
        // Expected network failure
      }

      // UI state must have reverted/rolled back to previous state
      expect(container.read(feedProvider).memories.first.isLiked, isFalse);
      expect(container.read(feedProvider).memories.first.likeCount, 5);
    });
  });
}
