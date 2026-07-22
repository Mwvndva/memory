import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/core/widget_manager.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/router.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/core/optimistic_transaction_manager.dart';
import 'package:memory_app/realtime/realtime_event.dart';
import 'package:memory_app/realtime/realtime_providers.dart';
import 'package:memory_app/media/cache_coordinator.dart';
import 'package:memory_app/services/compression_service.dart';
import 'package:memory_app/services/thumbnail_service.dart';
import 'package:memory_app/design_system/design_system.dart';

Color parseHexColor(String hexStr) {
  var clean = hexStr.replaceAll('#', '').trim();
  if (clean.length == 6) {
    clean = 'FF$clean';
  } else if (clean.length == 8) {
    clean = 'FF${clean.substring(clean.length - 6)}';
  } else {
    return MemoryColors.accentWarm;
  }
  return Color(int.tryParse(clean, radix: 16) ?? 0xFFFADA5E);
}

class MemoryRepository {
  MemoryRepository(this._ref);

  final Ref _ref;

  static const _defaultMemories = [
    MemoryItem(
      id: 'mock-amara-1',
      person: 'Amara',
      username: 'amara',
      initial: 'A',
      time: '8 min ago',
      caption: 'The ridiculous cake moment',
      avatar: MemoryColors.accent,
      colors: MemoryColors.memoryFallbackGradient,
      ageHours: .13,
    ),
    MemoryItem(
      id: 'mock-mum-2',
      person: 'Mum',
      username: 'mum',
      initial: 'M',
      time: 'Yesterday',
      caption: 'Found your old school song',
      avatar: MemoryColors.mint,
      colors: [MemoryColors.mint, MemoryColors.sky, MemoryColors.accentWarm],
      ageHours: 26,
    ),
    MemoryItem(
      id: 'mock-leo-3',
      person: 'Leo',
      username: 'leo',
      initial: 'L',
      time: 'Friday',
      caption: 'Rainy walk after class',
      avatar: MemoryColors.sky,
      colors: [
        MemoryColors.sky,
        MemoryColors.lavender,
        MemoryColors.accentWarm,
      ],
      ageHours: 72,
    ),
    MemoryItem(
      id: 'mock-nia-4',
      person: 'Nia',
      username: 'nia',
      initial: 'N',
      time: '2 days ago',
      caption: 'Sunset on the way home',
      avatar: MemoryColors.lavender,
      colors: [MemoryColors.lavender, MemoryColors.accent, MemoryColors.amber],
      ageHours: 48,
    ),
  ];

  List<MemoryItem> _parseJsonFeed(List<dynamic> rawList) {
    return rawList.map((item) {
      final List<Color> colors = (item['gradient_colors'] as List? ?? []).map((
        colorStr,
      ) {
        return parseHexColor(colorStr as String);
      }).toList();

      final avatarStr = item['avatar'] as String? ?? '';
      final avatarColor = parseHexColor(avatarStr);

      final creatorObj = item['creator'] as Map<String, dynamic>?;
      final avatarUrl = creatorObj?['avatar_url'] as String?;

      final Map<String, int> reactionsMap = {};
      final reactionsList = item['reactions'] as List? ?? [];
      for (final r in reactionsList) {
        if (r is Map) {
          final emoji = r['emoji'] as String? ?? '';
          final count = r['count'] as int? ?? 0;
          if (emoji.isNotEmpty) {
            reactionsMap[emoji] = count;
          }
        }
      }

      return MemoryItem(
        id: item['id'] as String? ?? '',
        person: item['person'] as String? ?? '',
        username: creatorObj?['username'] as String? ?? '',
        initial: item['initial'] as String? ?? '',
        time: item['time'] as String? ?? '',
        caption: item['caption'] as String? ?? '',
        avatar: avatarColor,
        colors: colors.isEmpty ? [avatarColor] : colors,
        ageHours: (item['age_hours'] as num?)?.toDouble() ?? 0.0,
        videoPath: item['video_url'] as String?,
        avatarUrl: avatarUrl,
        reactions: reactionsMap,
      );
    }).toList();
  }

  Future<FeedPageResult> fetchFeed({String? cursor, int limit = 20}) async {
    if (kUseMockBackend) {
      // Mock backend pagination: return 4 items if cursor is null, otherwise return empty
      if (cursor == null) {
        return const FeedPageResult(
          memories: _defaultMemories,
          nextCursor: 'mock-next-cursor-page-2',
        );
      } else if (cursor == 'mock-next-cursor-page-2') {
        // Return some older memory items for mock pagination testing
        final page2Memories = [
          MemoryItem(
            id: 'mock-kofi-5',
            person: 'Kofi',
            username: 'kofi',
            initial: 'K',
            time: '3 days ago',
            caption: 'Saturday morning coffee run',
            avatar: MemoryColors.lavender,
            colors: [
              MemoryColors.lavender,
              MemoryColors.accent,
              MemoryColors.sky,
            ],
            ageHours: 72,
          ),
          MemoryItem(
            id: 'mock-zoe-6',
            person: 'Zoe',
            username: 'zoe',
            initial: 'Z',
            time: '4 days ago',
            caption: 'Stretching after run',
            avatar: MemoryColors.accent,
            colors: [
              MemoryColors.accent,
              MemoryColors.mint,
              MemoryColors.amber,
            ],
            ageHours: 96,
          ),
        ];
        return FeedPageResult(
          memories: page2Memories,
          nextCursor: null, // End of feed
        );
      }
      return const FeedPageResult(memories: [], nextCursor: null);
    }

    try {
      final dio = _ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };
      final response = await dio.get(
        '/memories/feed',
        queryParameters: queryParams,
      );

      final rawList = (response.data['memories'] as List? ?? []);
      final list = _parseJsonFeed(rawList);

      final meta = response.data['meta'] as Map<String, dynamic>?;
      final nextCursor = meta?['nextCursor'] as String?;

      if (cursor == null) {
        // Only sync/cache initial page to avoid invalidating cache with partial pages
        final feedItems = list.where((m) => m.ageHours < 24).toList();
        WidgetManager.syncLatestMemory(feedItems);

        try {
          final coordinator = _ref.read(cacheCoordinatorProvider);
          await coordinator.write('feed', rawList);
        } catch (e) {
          debugPrint('Failed to save feed cache via CacheCoordinator: $e');
        }
      }

      return FeedPageResult(memories: list, nextCursor: nextCursor);
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      throw mapped;
    }
  }

  List<MemoryItem> getCachedFeed() {
    try {
      final coordinator = _ref.read(cacheCoordinatorProvider);
      final rawList = coordinator.read('feed');
      if (rawList != null && rawList is List) {
        return _parseJsonFeed(rawList);
      }
    } catch (_) {
      // Ignore cache loading errors
    }
    return const [];
  }

  Future<void> addMemory({
    required String caption,
    required List<Color> colors,
    required String? videoPath,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    if (kUseMockBackend) {
      final user = _ref.read(authProvider);
      final name = user.firstName.isNotEmpty ? user.firstName : 'You';
      final initial = name.isNotEmpty ? name[0] : 'Y';
      final newItem = MemoryItem(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        person: name,
        username: user.username,
        initial: initial,
        time: 'Just now',
        caption: caption,
        avatar: MemoryColors.accent,
        colors: colors,
        ageHours: 0.01,
        videoPath: videoPath,
        avatarUrl: user.avatarUrl,
      );

      // Add optimistically to state manager
      _ref.read(feedProvider.notifier).addLocalMemory(newItem);

      final currentStreak = _ref.read(authProvider).streakDays;
      _ref
          .read(sessionProvider.notifier)
          .updateProfile(
            _ref.read(authProvider).copyWith(streakDays: currentStreak + 1),
          );
    } else {
      final dio = _ref.read(apiClientProvider);
      final List<String> colorsHex = colors.map((c) {
        return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      }).toList();

      final formData = FormData.fromMap({
        'caption': caption,
        'colors': colorsHex,
        if (videoPath != null && videoPath.isNotEmpty)
          'video': await MultipartFile.fromFile(
            videoPath,
            filename: 'captured_memory.mp4',
          ),
      });

      await dio.post(
        '/memories/upload',
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    }
  }
}

class FeedPageResult {
  final List<MemoryItem> memories;
  final String? nextCursor;

  const FeedPageResult({required this.memories, this.nextCursor});
}

enum FeedLoadStatus {
  idle,
  loadingInitial,
  loaded,
  refreshing,
  loadingMore,
  error,
}

enum FeedErrorCategory {
  none,
  network, // Retryable: connection timeout, offline socket exceptions
  authentication, // Handled automatically by token refresh flow
  server, // Permanent / HTTP 500 errors
  emptyCircle,
  emptyFeed,
  unknown,
}

class FeedState {
  final List<MemoryItem> memories;
  final FeedLoadStatus status;
  final bool hasMore;
  final String? currentCursor;
  final String? nextCursor;
  final DateTime? lastRefreshTime;
  final String? errorMessage;
  final List<MemoryItem>? lastSuccessfulPage;
  final FeedErrorCategory errorCategory;
  final bool isOffline;

  FeedState({
    required this.memories,
    this.status = FeedLoadStatus.idle,
    this.hasMore = true,
    this.currentCursor,
    this.nextCursor,
    this.lastRefreshTime,
    this.errorMessage,
    this.lastSuccessfulPage,
    this.errorCategory = FeedErrorCategory.none,
    this.isOffline = false,
  });

  factory FeedState.idle() => FeedState(memories: const []);

  FeedState copyWith({
    List<MemoryItem>? memories,
    FeedLoadStatus? status,
    bool? hasMore,
    Object? currentCursor = _kUnset,
    Object? nextCursor = _kUnset,
    Object? errorMessage = _kUnset,
    Object? lastSuccessfulPage = _kUnset,
    DateTime? lastRefreshTime,
    FeedErrorCategory? errorCategory,
    bool? isOffline,
  }) {
    return FeedState(
      memories: memories ?? this.memories,
      status: status ?? this.status,
      hasMore: hasMore ?? this.hasMore,
      currentCursor: currentCursor == _kUnset
          ? this.currentCursor
          : currentCursor as String?,
      nextCursor: nextCursor == _kUnset
          ? this.nextCursor
          : nextCursor as String?,
      errorMessage: errorMessage == _kUnset
          ? this.errorMessage
          : errorMessage as String?,
      lastSuccessfulPage: lastSuccessfulPage == _kUnset
          ? this.lastSuccessfulPage
          : lastSuccessfulPage as List<MemoryItem>?,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      errorCategory: errorCategory ?? this.errorCategory,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// Sentinel value used by [FeedState.copyWith] to distinguish "not provided"
/// from "explicitly set to null" for nullable fields.
const Object _kUnset = Object();

class FeedStateManager extends StateNotifier<FeedState> {
  FeedStateManager(this._ref) : super(FeedState.idle()) {
    _initFeed();
    Future.microtask(() {
      _listenToAuthChanges();
    });
  }

  final Ref _ref;

  void _listenToAuthChanges() {
    _ref.listen<SessionState>(sessionProvider, (previous, next) {
      final wasAuth = previous?.isAuthenticated ?? false;
      final isAuth = next.isAuthenticated;
      if (wasAuth != isAuth ||
          (wasAuth &&
              isAuth &&
              previous?.user.username != next.user.username)) {
        // Reset state & empty index
        _index.clear();
        state = FeedState.idle();
        if (isAuth) {
          fetchFeed(force: true);
        }
      }
    });

    // Listen to real-time events for new memory notifications.
    _ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventStreamProvider, (
      _,
      next,
    ) {
      next.whenData((event) {
        if (event is NewMemoryEvent) {
          _handleNewMemoryNotification(event);
        } else if (event is NewReactionEvent) {
          _handleNewReactionNotification(event);
        } else if (event is ReactionUpdateEvent) {
          applyReactionUpdate(event.memoryId, event.emoji, event.count);
        }
      });
    });
  }

  void _handleNewMemoryNotification(NewMemoryEvent event) {
    // Show the notification toast (the business logic requirement)
    final templates = [
      '{name} just shared a new memory! Tap to see what they\'re up to.',
      'New post alert! {name} just captured a new memory.',
      '{name} has updated their circle! Check out their latest memory.',
      '{name}\'s day looks interesting! See their new memory now.',
      'Peek into {name}\'s world — a new memory was just posted!',
    ];
    final randomIdx = DateTime.now().millisecondsSinceEpoch % templates.length;
    final body = templates[randomIdx].replaceAll('{name}', event.creatorName);

    showGlobalNotification(
      title: 'New Memory 📸',
      body: body,
      onTap: () {
        rootNavigatorKey.currentState?.context.go('/feed');
      },
    );
  }

  void _handleNewReactionNotification(NewReactionEvent event) {
    // Show the notification toast (the business logic requirement)
    final templates = [
      '{name} loved your memory! Reaction: emoji',
      '{name} reacted emoji to your latest memory: "caption"',
      'emoji from {name}! She just reacted to your post.',
      '{name} found your memory "caption" reaction-worthy: emoji',
      'Reaction alert! {name} left a emoji on your memory.',
    ];
    final randomIdx = DateTime.now().millisecondsSinceEpoch % templates.length;
    final body = templates[randomIdx]
        .replaceAll('{name}', event.reactorName)
        .replaceAll('emoji', event.emoji)
        .replaceAll('caption', event.memoryCaption);

    showGlobalNotification(
      title: 'New Reaction ${event.emoji}',
      body: body,
      onTap: () {
        rootNavigatorKey.currentState?.context.go('/circle');
      },
    );
  }

  // ─── Reconciliation engine ──────────────────────────────────────────────────

  /// Maps each Memory's backend [id] to its position in [state.memories].
  /// Provides O(1) canonical identity lookups during reconciliation.
  final Map<String, int> _index = {};

  /// Atomically rebuilds [_index] from the given [list].
  /// Items with an empty [id] (local mock items) are not indexed.
  void _rebuildIndex(List<MemoryItem> list) {
    _index.clear();
    for (var i = 0; i < list.length; i++) {
      final id = list[i].id;
      if (id.isNotEmpty) _index[id] = i;
    }
  }

  /// The single gateway for every feed mutation.
  ///
  /// Reconciles [incoming] memories against the current canonical feed:
  ///
  /// - If [replaceAll] is `true`, adopt [incoming] as the authoritative ordering
  ///   (used by initial load, fetchFeed, refreshFeed, and cache restoration).
  ///   Known items are merged (mutable fields updated, position preserved within
  ///   the new ordering). Unknown items are inserted in arrival order.
  ///
  /// - If [prepend] is `true`, unknown items are inserted at the front of the
  ///   existing list (used by optimistic uploads via [addLocalMemory]).
  ///
  /// - Default (append) inserts unknown items at the end of the existing list
  ///   (used by pagination via [loadMore]).
  ///
  /// Existing items that appear in [incoming] are always merged in-place using
  /// their canonical [id] — never duplicated.
  ///
  /// Fields merged from incoming: caption, time, ageHours, avatarUrl,
  ///   videoPath, colors.
  /// Fields preserved from existing: id, person, username, initial, avatar.
  ///
  /// After reconciliation [_index] is rebuilt atomically.
  List<MemoryItem> reconcile(
    List<MemoryItem> incoming, {
    bool replaceAll = false,
    bool prepend = false,
  }) {
    if (replaceAll) {
      // Build result in the backend's authoritative ordering.
      // For each incoming item: update the existing canonical object if known,
      // or use the incoming object as-is for new items.
      final result = incoming.map((item) {
        final existingIdx = _index[item.id];
        if (existingIdx != null && item.id.isNotEmpty) {
          // Merge mutable fields into the canonical existing object.
          final existing = state.memories[existingIdx];
          return existing.copyWith(
            caption: item.caption,
            time: item.time,
            ageHours: item.ageHours,
            avatarUrl: item.avatarUrl,
            videoPath: item.videoPath,
            colors: item.colors,
          );
        }
        return item;
      }).toList();
      _rebuildIndex(result);
      return result;
    }

    // Incremental path: append or prepend only truly new items.
    final mutable = List<MemoryItem>.from(state.memories);
    final newItems = <MemoryItem>[];

    for (final item in incoming) {
      final existingIdx = _index[item.id];
      if (existingIdx != null && item.id.isNotEmpty) {
        // Merge mutable fields into the existing canonical item in-place.
        mutable[existingIdx] = mutable[existingIdx].copyWith(
          caption: item.caption,
          time: item.time,
          ageHours: item.ageHours,
          avatarUrl: item.avatarUrl,
          videoPath: item.videoPath,
          colors: item.colors,
        );
      } else {
        newItems.add(item);
      }
    }

    final result = prepend
        ? [...newItems, ...mutable]
        : [...mutable, ...newItems];
    _rebuildIndex(result);
    return result;
  }

  /// Removes the Memory with the given [id] from the feed exactly once.
  /// No-ops silently if [id] is not found in [_index].
  void removeById(String id) {
    final idx = _index[id];
    if (idx == null) return;
    final updated = List<MemoryItem>.from(state.memories)..removeAt(idx);
    _rebuildIndex(updated);
    state = state.copyWith(memories: updated);
  }

  void _initFeed() {
    final repository = _ref.read(memoryRepositoryProvider);
    final cached = repository.getCachedFeed();
    if (cached.isNotEmpty) {
      final reconciled = reconcile(cached, replaceAll: true);
      state = state.copyWith(
        status: FeedLoadStatus.loaded,
        memories: reconciled,
        currentCursor: null,
        nextCursor: null,
        hasMore: true,
      );
    } else if (kUseMockBackend) {
      final reconciled = reconcile(
        List<MemoryItem>.from(MemoryRepository._defaultMemories),
        replaceAll: true,
      );
      state = state.copyWith(
        status: FeedLoadStatus.loaded,
        memories: reconciled,
        currentCursor: null,
        nextCursor: 'mock-next-cursor-page-2',
        hasMore: true,
      );
    }

    if (!kUseMockBackend) {
      final dio = _ref.read(apiClientProvider);
      final isLocalMock =
          dio.options.baseUrl.contains('localhost') ||
          dio.options.baseUrl.contains('127.0.0.1');
      if (!isLocalMock) {
        fetchFeed();
      }
    }
  }

  // To serialize pagination calls and ensure out-of-order/obsolete calls are ignored,
  // we keep track of the count of active pagination requests.
  int _requestCounter = 0;
  DateTime? _lastRefreshRequestTime;

  /// Centralized Cache Invalidation & Refresh Policy gatekeeper.
  /// - User-initiated pull-to-refresh (force: true) always proceeds.
  /// - System/automated requests (force: false) are throttled to once every 5 seconds.
  bool requestRefresh({required bool force}) {
    if (force) return true;
    final now = DateTime.now();
    if (_lastRefreshRequestTime != null &&
        now.difference(_lastRefreshRequestTime!).inSeconds < 5) {
      return false; // Throttled / ignored
    }
    _lastRefreshRequestTime = now;
    return true;
  }

  FeedErrorCategory _classifyError(dynamic e) {
    final mapped = mapException(e);
    if (mapped is NetworkException || mapped is TimeoutException) {
      return FeedErrorCategory.network;
    }
    if (mapped is AuthenticationException) {
      return FeedErrorCategory.authentication;
    }
    if (mapped is ServerException) {
      return FeedErrorCategory.server;
    }
    return FeedErrorCategory.unknown;
  }

  Future<void> fetchFeed({bool force = false}) async {
    if (!requestRefresh(force: force)) return;

    if (state.status == FeedLoadStatus.loadingInitial ||
        state.status == FeedLoadStatus.refreshing ||
        state.status == FeedLoadStatus.loadingMore) {
      return;
    }

    _requestCounter++;
    final currentRequestId = _requestCounter;

    state = state.copyWith(
      status: FeedLoadStatus.loadingInitial,
      errorMessage: null,
      errorCategory: FeedErrorCategory.none,
      currentCursor: null,
      nextCursor: null,
      hasMore: true,
      lastSuccessfulPage: null,
    );

    try {
      final repository = _ref.read(memoryRepositoryProvider);
      final result = await repository.fetchFeed(cursor: null);

      if (currentRequestId != _requestCounter) {
        // Discard obsolete response
        return;
      }

      final reconciled = reconcile(result.memories, replaceAll: true);

      state = state.copyWith(
        status: FeedLoadStatus.loaded,
        memories: reconciled,
        lastRefreshTime: DateTime.now(),
        hasMore: result.nextCursor != null,
        currentCursor: null,
        nextCursor: result.nextCursor,
        lastSuccessfulPage: result.memories,
        errorCategory: reconciled.isEmpty
            ? FeedErrorCategory.emptyFeed
            : FeedErrorCategory.none,
        isOffline: false,
      );
    } catch (e) {
      if (currentRequestId != _requestCounter) return;
      final category = _classifyError(e);
      state = state.copyWith(
        status: FeedLoadStatus.error,
        errorMessage: e.toString(),
        errorCategory: category,
        isOffline: category == FeedErrorCategory.network,
      );
    }
  }

  Future<void> refreshFeed({bool force = true}) async {
    // Direct User Pull-To-Refresh forces refresh (bypasses throttle)
    if (!requestRefresh(force: force)) return;

    if (state.status == FeedLoadStatus.loadingInitial ||
        state.status == FeedLoadStatus.refreshing ||
        state.status == FeedLoadStatus.loadingMore) {
      return;
    }

    _requestCounter++;
    final currentRequestId = _requestCounter;

    state = state.copyWith(
      status: FeedLoadStatus.refreshing,
      errorMessage: null,
      lastSuccessfulPage: null,
    );

    try {
      final repository = _ref.read(memoryRepositoryProvider);
      final result = await repository.fetchFeed(cursor: null);

      if (currentRequestId != _requestCounter) {
        return;
      }

      final reconciled = reconcile(result.memories, replaceAll: true);
      state = state.copyWith(
        status: FeedLoadStatus.loaded,
        memories: reconciled,
        lastRefreshTime: DateTime.now(),
        hasMore: result.nextCursor != null,
        currentCursor: null,
        nextCursor: result.nextCursor,
        lastSuccessfulPage: result.memories,
        errorCategory: reconciled.isEmpty
            ? FeedErrorCategory.emptyFeed
            : FeedErrorCategory.none,
        isOffline: false,
      );
    } catch (e) {
      if (currentRequestId != _requestCounter) return;
      final category = _classifyError(e);
      // For refresh failures, retain existing memories! Never clear the feed.
      state = state.copyWith(
        status: FeedLoadStatus.loaded, // preserve memories in loaded state
        errorMessage: e.toString(),
        errorCategory: category,
        isOffline: category == FeedErrorCategory.network,
      );
    }
  }

  Future<void> loadMore() async {
    // Eligibility Checks:
    // Do not load more if initial load, refresh, or page request is already running,
    // or if there are no more pages.
    if (state.status == FeedLoadStatus.loadingInitial ||
        state.status == FeedLoadStatus.refreshing ||
        state.status == FeedLoadStatus.loadingMore ||
        !state.hasMore) {
      return;
    }

    _requestCounter++;
    final currentRequestId = _requestCounter;
    final targetCursor = state.nextCursor;

    state = state.copyWith(
      status: FeedLoadStatus.loadingMore,
      errorMessage: null,
    );

    try {
      final repository = _ref.read(memoryRepositoryProvider);
      final result = await repository.fetchFeed(cursor: targetCursor);

      if (currentRequestId != _requestCounter) {
        // Discard obsolete response to enforce deterministic ordering
        return;
      }

      // Route through reconciliation engine: deduplicates by canonical id,
      // merges mutable fields for existing items, appends truly new items.
      state = state.copyWith(
        status: FeedLoadStatus.loaded,
        memories: reconcile(result.memories),
        currentCursor: targetCursor,
        nextCursor: result.nextCursor,
        hasMore: result.nextCursor != null && result.memories.isNotEmpty,
        lastSuccessfulPage: result.memories,
        errorCategory: FeedErrorCategory.none,
        isOffline: false,
      );
    } catch (e) {
      if (currentRequestId != _requestCounter) return;
      final category = _classifyError(e);
      // Isolated pagination failure: memories list is retained
      state = state.copyWith(
        status: FeedLoadStatus.loaded, // keep memories in loaded state
        errorMessage: e.toString(),
        errorCategory: category,
        isOffline: category == FeedErrorCategory.network,
      );
    }
  }

  Future<void> retryCurrentFailure() async {
    // Expose context-aware retry execution path based on the current state.
    if (state.memories.isEmpty) {
      await fetchFeed(force: true);
    } else {
      if (state.nextCursor != null) {
        await loadMore();
      } else {
        await refreshFeed(force: true);
      }
    }
  }

  void addLocalMemory(MemoryItem item) {
    // Route through reconciliation engine with prepend=true:
    // - If this id already exists in the feed (e.g. race with realtime), merge in-place.
    // - Otherwise insert at the front (newest-first ordering for optimistic uploads).
    state = state.copyWith(memories: reconcile([item], prepend: true));
  }

  /// Removes the Memory identified by [id] from the feed exactly once.
  /// Delegates to [removeById] which uses the O(1) [_index] for lookup.
  /// The legacy [deleteMemory] name is preserved for call-site compatibility.
  void deleteMemory(String id) => removeById(id);

  final OptimisticTransactionManager txManager = OptimisticTransactionManager();

  /// Applies the authoritative reaction count the server broadcast for
  /// [memoryId]. This is what reconciles an optimistic tap with reality, and
  /// what makes other people's reactions visible.
  void applyReactionUpdate(String memoryId, String emoji, int count) {
    final idx = _index[memoryId];
    if (idx == null) return;

    final original = state.memories[idx];
    if ((original.reactions[emoji] ?? 0) == count) return;

    final updatedReactions = Map<String, int>.from(original.reactions);
    if (count <= 0) {
      updatedReactions.remove(emoji);
    } else {
      updatedReactions[emoji] = count;
    }

    final updatedList = List<MemoryItem>.from(state.memories);
    updatedList[idx] = original.copyWith(reactions: updatedReactions);
    state = state.copyWith(memories: updatedList);
  }

  Future<void> sendReaction(String memoryId, String emoji) async {
    final idx = _index[memoryId];
    if (idx == null) return;

    // Duplicate Prevention check (emoji-level)
    if (txManager.hasPending(memoryId, 'reaction-$emoji')) return;

    final original = state.memories[idx];
    final currentCount = original.reactions[emoji] ?? 0;

    // We increment or decrement based on current state (simple toggle for reactions)
    // Tapping reacts adds 1, tapping again removes 1
    final isRemoving = currentCount > 0;
    final targetCount = isRemoving ? currentCount - 1 : currentCount + 1;

    final updatedReactions = Map<String, int>.from(original.reactions);
    if (targetCount <= 0) {
      updatedReactions.remove(emoji);
    } else {
      updatedReactions[emoji] = targetCount;
    }

    final optimisticItem = original.copyWith(reactions: updatedReactions);

    final txId = 'tx-reaction-$emoji-${DateTime.now().millisecondsSinceEpoch}';
    final tx = OptimisticTransaction(
      id: txId,
      memoryId: memoryId,
      actionType: 'reaction-$emoji',
      originalValue: original,
      optimisticValue: optimisticItem,
      timestamp: DateTime.now(),
    );

    txManager.register(tx);

    // Apply UI state change immediately
    final updatedList = List<MemoryItem>.from(state.memories);
    updatedList[idx] = optimisticItem;
    state = state.copyWith(memories: updatedList);
    try {
      await _ref
          .read(reactionRepositoryProvider)
          .sendReaction(memoryId, emoji, isRemoving: isRemoving);

      txManager.resolve(memoryId, txId, TransactionStatus.committed);
    } catch (e) {
      txManager.resolve(memoryId, txId, TransactionStatus.rolledBack);

      // Revert UI to original state snapshot
      final currentIdx = _index[memoryId];
      if (currentIdx != null) {
        final revertedList = List<MemoryItem>.from(state.memories);
        revertedList[currentIdx] = original;
        state = state.copyWith(memories: revertedList);
      }
      rethrow;
    }
  }
}

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref);
});

final feedProvider = StateNotifierProvider<FeedStateManager, FeedState>((ref) {
  return FeedStateManager(ref);
});

final feedMemoriesProvider = Provider<List<MemoryItem>>((ref) {
  final list = ref.watch(feedProvider).memories;
  final filtered = list.where((m) => m.ageHours < 24).toList();
  filtered.sort((a, b) => a.ageHours.compareTo(b.ageHours));
  return filtered;
});

final archivedMemoriesProvider = Provider<List<MemoryItem>>((ref) {
  final list = ref.watch(feedProvider).memories;
  return list.where((m) => m.ageHours >= 24).toList();
});

enum UploadStatus {
  idle,
  preparing,
  validating,
  compressing,
  generatingThumbnail,
  queued,
  uploading,
  waitingForResponse,
  succeeded,
  failed,
  cancelled,
}

class UploadState {
  final UploadStatus status;
  final double progress;
  final String? errorMessage;
  final bool isRetryable;

  UploadState({
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.isRetryable = false,
  });

  factory UploadState.idle() => UploadState(status: UploadStatus.idle);

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    bool? isRetryable,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }
}

class UploadCoordinator extends StateNotifier<UploadState> {
  UploadCoordinator(this._ref) : super(UploadState.idle());

  final Ref _ref;
  CancelToken? _cancelToken;

  void cancelUpload() {
    if (state.status == UploadStatus.uploading ||
        state.status == UploadStatus.preparing ||
        state.status == UploadStatus.validating) {
      _cancelToken?.cancel('User cancelled the upload');
      state = state.copyWith(status: UploadStatus.cancelled);
    }
  }

  void reset() {
    state = UploadState.idle();
  }

  Future<void> startUpload(
    String caption,
    List<Color> colors, {
    String? videoPath,
  }) async {
    if (state.status == UploadStatus.preparing ||
        state.status == UploadStatus.validating ||
        state.status == UploadStatus.compressing ||
        state.status == UploadStatus.generatingThumbnail ||
        state.status == UploadStatus.queued ||
        state.status == UploadStatus.uploading ||
        state.status == UploadStatus.waitingForResponse) {
      return;
    }

    _cancelToken = CancelToken();

    state = state.copyWith(
      status: UploadStatus.preparing,
      progress: 0.0,
      errorMessage: null,
      isRetryable: false,
    );
    await Future.delayed(const Duration(milliseconds: 100));

    state = state.copyWith(status: UploadStatus.validating);
    try {
      if (videoPath != null && videoPath.isNotEmpty) {
        final file = File(videoPath);
        if (!await file.exists()) {
          throw ValidationException(
            'Recorded video file does not exist on disk.',
            null,
            StackTrace.current,
          );
        }
        final size = await file.length();
        const maxSizeBytes = 50 * 1024 * 1024;
        if (size > maxSizeBytes) {
          throw ValidationException(
            'Video file size exceeds the 50MB limit.',
            null,
            StackTrace.current,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: e.toString(),
        isRetryable: false,
      );
      return;
    }

    // Dynamic processing chain
    String finalPath = videoPath ?? '';
    try {
      if (finalPath.isNotEmpty) {
        // Compressing
        state = state.copyWith(status: UploadStatus.compressing, progress: 0.1);
        final compressionService = _ref.read(compressionServiceProvider);
        final compressResult = await compressionService.compressVideo(
          path: finalPath,
          onProgress: (p) => state = state.copyWith(progress: 0.1 + (p * 0.2)),
        );
        finalPath = compressResult.compressedPath;

        // Thumbnailing
        state = state.copyWith(
          status: UploadStatus.generatingThumbnail,
          progress: 0.3,
        );
        final thumbnailService = _ref.read(thumbnailServiceProvider);
        await thumbnailService.getThumbnail(finalPath);
        state = state.copyWith(progress: 0.4);
      }
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: mapped.message,
        isRetryable: false,
      );
      return;
    }

    state = state.copyWith(status: UploadStatus.uploading, progress: 0.4);

    try {
      final repository = _ref.read(memoryRepositoryProvider);
      await repository.addMemory(
        caption: caption,
        colors: colors,
        videoPath: finalPath.isNotEmpty ? finalPath : null,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = 0.4 + ((sent / total) * 0.5);
            if (progress >= 0.9) {
              state = state.copyWith(
                status: UploadStatus.waitingForResponse,
                progress: 0.9,
              );
            } else {
              if (progress - state.progress > 0.02) {
                state = state.copyWith(
                  status: UploadStatus.uploading,
                  progress: progress,
                );
              }
            }
          }
        },
      );

      // The upload POST has returned; mark success immediately so the UI
      // confirms without waiting on the follow-up refreshes below. Previously
      // these two awaited network round-trips ran BEFORE 'succeeded', adding
      // seconds of perceived send time.
      state = state.copyWith(status: UploadStatus.succeeded, progress: 1.0);

      if (!kUseMockBackend) {
        // Refresh profile (streak) and feed in the background so the new memory
        // is present when the user opens the feed, without blocking the tick.
        unawaited(_ref.read(sessionProvider.notifier).fetchProfile());
        unawaited(_ref.read(feedProvider.notifier).fetchFeed(force: true));
      }
    } on DioException catch (e, stack) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      final mapped = mapException(e, stack);
      bool retryable = false;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        retryable = true;
      } else {
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          if (statusCode == 408 ||
              statusCode == 429 ||
              statusCode == 502 ||
              statusCode == 503 ||
              statusCode == 504) {
            retryable = true;
          }
        }
      }
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: mapped.message,
        isRetryable: retryable,
      );
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      bool retryable = false;
      if (e is SocketException) {
        retryable = true;
      }
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: mapped.message,
        isRetryable: retryable,
      );
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadCoordinator, UploadState>((
  ref,
) {
  return UploadCoordinator(ref);
});
