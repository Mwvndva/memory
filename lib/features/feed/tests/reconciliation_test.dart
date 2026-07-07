import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

const _alice = MemoryItem(
  id: 'uuid-alice-1',
  person: 'Alice',
  username: 'alice',
  initial: 'A',
  time: '1h ago',
  caption: 'Morning run',
  avatar: kMint,
  colors: [kMint, kSky],
  ageHours: 1,
);

const _bob = MemoryItem(
  id: 'uuid-bob-2',
  person: 'Bob',
  username: 'bob',
  initial: 'B',
  time: '2h ago',
  caption: 'Lunch break walk',
  avatar: kYellow,
  colors: [kYellow, kAmber],
  ageHours: 2,
);

const _carol = MemoryItem(
  id: 'uuid-carol-3',
  person: 'Carol',
  username: 'carol',
  initial: 'C',
  time: '3h ago',
  caption: 'Sunset view',
  avatar: kLavender,
  colors: [kLavender, kMint],
  ageHours: 3,
);

// ---------------------------------------------------------------------------
// MockMemoryRepository — returns controlled pages, never touches the network.
// ---------------------------------------------------------------------------

class MockMemoryRepository extends MemoryRepository {
  MockMemoryRepository(super.ref);

  @override
  List<MemoryItem> getCachedFeed() => const [];

  @override
  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    if (cursor == null) {
      return const FeedPageResult(
        memories: [_alice, _bob],
        nextCursor: 'page-2-cursor',
      );
    }
    if (cursor == 'page-2-cursor') {
      return const FeedPageResult(
        memories: [_carol],
        nextCursor: null,
      );
    }
    return const FeedPageResult(memories: [], nextCursor: null);
  }
}

// ---------------------------------------------------------------------------
// Helper: create a container backed by MockMemoryRepository and drain init.

class _FakeSessionManager extends StateNotifier<SessionState>
    implements SessionManager {
  _FakeSessionManager()
      : super(SessionState(
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
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<({ProviderContainer container, FeedStateManager notifier})> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWith((ref) => MockMemoryRepository(ref)),
      sessionProvider.overrideWith((_) => _FakeSessionManager()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWithValue(const UserProfile(
        firstName: 'Test',
        lastName: 'User',
        username: 'testuser',
        email: 'test@test.com',
        phone: '+10000000000',
        isAuthenticated: true,
      )),
    ],
  );
  // Read notifier first — this triggers FeedStateManager construction + _initFeed.
  final notifier = container.read(feedProvider.notifier);
  // Drain the event queue so _initFeed -> fetchFeed completes.
  await pumpEventQueue();
  return (container: container, notifier: notifier);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);

    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  group('Feed Reconciliation Engine Tests', () {

    // ── Scenario 1 ───────────────────────────────────────────────────────────
    test('1. reconcile(replaceAll) adopts backend ordering with no duplicates', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Initial load returns [alice, bob].
      final s1 = container.read(feedProvider);
      expect(s1.memories.length, 2,
          reason: 'Feed should have 2 items after init');
      expect(s1.memories[0].id, 'uuid-alice-1');
      expect(s1.memories[1].id, 'uuid-bob-2');

      // A refresh that returns the same two items must NOT duplicate them.
      await notifier.refreshFeed();

      final s2 = container.read(feedProvider);
      expect(s2.memories.length, 2,
          reason: 'Refresh must not duplicate existing items');
      expect(s2.memories.map((m) => m.id).toSet().length, 2,
          reason: 'All IDs must be unique after refresh');
    });

    // ── Scenario 2 ───────────────────────────────────────────────────────────
    test('2. Deduplication uses canonical id, not the unstable time string', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed: [alice, bob]
      expect(container.read(feedProvider).memories.length, 2);

      // Simulate alice having her relative time label refreshed.
      final aliceUpdated = _alice.copyWith(time: 'Just now', ageHours: 0.01);

      // Call reconcile directly to simulate a targeted update arriving.
      final reconciled = notifier.reconcile([aliceUpdated]);

      // Should merge alice in-place (id match), not append a new entry.
      expect(reconciled.length, 2,
          reason: 'Item with changed time must be merged, not duplicated');

      final aliceInFeed = reconciled.firstWhere((m) => m.id == 'uuid-alice-1');
      expect(aliceInFeed.time, 'Just now',
          reason: 'Merged item must reflect the updated time string');
      expect(aliceInFeed.caption, 'Morning run',
          reason: 'Preserved field must not change');
    });

    // ── Scenario 3 ───────────────────────────────────────────────────────────
    test('3. reconcile(prepend) inserts new item at front; updates existing by id', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed: [alice, bob]
      expect(container.read(feedProvider).memories.length, 2);

      // New optimistic upload (carol) — should appear at the front.
      notifier.addLocalMemory(_carol);

      final s = container.read(feedProvider);
      expect(s.memories.length, 3,
          reason: 'New item must be added');
      expect(s.memories.first.id, 'uuid-carol-3',
          reason: 'Optimistic upload must appear at the front');

      // Calling addLocalMemory with the same id must merge, not duplicate.
      notifier.addLocalMemory(_carol.copyWith(caption: 'Updated caption'));

      final s2 = container.read(feedProvider);
      expect(s2.memories.length, 3,
          reason: 'Re-inserting same id must not create a duplicate');
      // After merging, the existing carol at position 0 gets the new caption.
      final carolInFeed = s2.memories.firstWhere((m) => m.id == 'uuid-carol-3');
      expect(carolInFeed.caption, 'Updated caption',
          reason: 'Caption must be updated via merge');
    });

    // ── Scenario 4 ───────────────────────────────────────────────────────────
    test('4. removeById removes exactly one item; index stays consistent', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed: [alice, bob]
      expect(container.read(feedProvider).memories.length, 2);

      notifier.removeById('uuid-alice-1');

      final s = container.read(feedProvider);
      expect(s.memories.length, 1);
      expect(s.memories.first.id, 'uuid-bob-2');

      // Removing the same id again is a no-op.
      notifier.removeById('uuid-alice-1');
      expect(container.read(feedProvider).memories.length, 1);

      // Removing a non-existent id is a no-op.
      notifier.removeById('uuid-nobody-99');
      expect(container.read(feedProvider).memories.length, 1);
    });

    // ── Scenario 5 ───────────────────────────────────────────────────────────
    test('5. Overlapping pagination pages produce no duplicates', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed: [alice, bob]
      expect(container.read(feedProvider).memories.length, 2);

      // Simulate a pagination result that overlaps with existing items.
      // [bob, carol] — bob exists, carol is new.
      final reconciled = notifier.reconcile([_bob, _carol]);

      expect(reconciled.length, 3,
          reason: 'bob must be merged in-place; carol must be appended');
      expect(reconciled.where((m) => m.id == 'uuid-bob-2').length, 1,
          reason: 'bob must appear exactly once');
      expect(reconciled.last.id, 'uuid-carol-3',
          reason: 'carol (new item) must be appended at the end');
    });

    // ── Scenario 6 ───────────────────────────────────────────────────────────
    test('6. Item with changed time string is updated in-place, not duplicated', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed: [alice, bob]
      expect(container.read(feedProvider).memories.length, 2);

      // Simulate a refresh where alice and bob have updated relative times.
      final refreshedAlice = _alice.copyWith(time: '2h ago', ageHours: 2.0);
      final refreshedBob   = _bob.copyWith(time: '3h ago', ageHours: 3.0);

      final reconciled = notifier.reconcile(
        [refreshedAlice, refreshedBob],
        replaceAll: true,
      );

      expect(reconciled.length, 2,
          reason: 'No duplicates after refresh with updated time strings');

      final aliceResult = reconciled.firstWhere((m) => m.id == 'uuid-alice-1');
      expect(aliceResult.time, '2h ago');
      expect(aliceResult.ageHours, 2.0);
    });

    // ── Scenario 7 ───────────────────────────────────────────────────────────
    test('7. fetchFeed after init produces no duplicates', () async {
      final (:container, :notifier) = await makeContainer();
      addTearDown(container.dispose);

      // Feed initialized: [alice, bob].
      expect(container.read(feedProvider).memories.length, 2);

      // Simulate a second fetchFeed (e.g., after app resume or post-upload refresh).
      // This calls reconcile(replaceAll:true) internally.
      await notifier.fetchFeed();

      final s = container.read(feedProvider);
      expect(s.memories.length, 2,
          reason: 'fetchFeed must not duplicate items already in the feed');
      expect(s.memories.map((m) => m.id).toSet().length, 2,
          reason: 'All IDs must remain unique');
    });

  });
}
