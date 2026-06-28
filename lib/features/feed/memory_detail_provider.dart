import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/error_handler.dart';
import '../../models/memory_item.dart';
import '../../models/comment_item.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/auth_repository.dart';
import 'memory_detail_state.dart';

class MemoryDetailStateManager extends StateNotifier<MemoryDetailState> {
  MemoryDetailStateManager(this._ref, this._memoryId) : super(MemoryDetailState()) {
    loadMemory();
  }

  final Ref _ref;
  final String _memoryId;

  // Local backups for transactional rollbacks
  List<CommentItem>? _commentsBackup;
  MemoryItem? _memoryBackup;

  Future<void> loadMemory() async {
    state = state.copyWith(status: MemoryDetailLoadStatus.loading, errorMessage: null);
    try {
      // Find the memory from feed first to bootstrap quickly
      final feedState = _ref.read(feedProvider);
      MemoryItem? found = feedState.memories.firstWhere((m) => m.id == _memoryId,
          orElse: () => MemoryItem(
                id: _memoryId,
                person: 'Loading...',
                username: '...',
                initial: 'L',
                time: '...',
                caption: '',
                avatar: Color(0xFFFADA5E),
                colors: [Color(0xFFFADA5E)],
                ageHours: 0.0,
              ));

      state = state.copyWith(memory: found);

      if (!kUseMockBackend) {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.get('/memories/$_memoryId');
        // Let's assume standard single object response or parse it
        final raw = response.data;
        // In NestJS single memory endpoint parses same format
        final colors = (raw['gradient_colors'] as List? ?? []).map((c) => parseHexColor(c as String)).toList();
        final avatarColor = parseHexColor(raw['avatar'] as String? ?? '');
        final creator = raw['creator'] as Map<String, dynamic>?;
        
        found = MemoryItem(
          id: raw['id'] as String? ?? '',
          person: raw['person'] as String? ?? '',
          username: creator?['username'] as String? ?? '',
          initial: raw['initial'] as String? ?? '',
          time: raw['time'] as String? ?? '',
          caption: raw['caption'] as String? ?? '',
          avatar: avatarColor,
          colors: colors.isEmpty ? [avatarColor] : colors,
          ageHours: (raw['age_hours'] as num?)?.toDouble() ?? 0.0,
          videoPath: raw['video_url'] as String?,
          avatarUrl: creator?['avatar_url'] as String?,
          isLiked: raw['is_liked'] as bool? ?? false,
          likeCount: raw['like_count'] as int? ?? 0,
          isBookmarked: raw['is_bookmarked'] as bool? ?? false,
          reactions: (raw['reactions'] as List? ?? []).fold<Map<String, int>>({}, (map, r) {
            final emoji = r['emoji'] as String? ?? '';
            final count = r['count'] as int? ?? 0;
            if (emoji.isNotEmpty) map[emoji] = count;
            return map;
          }),
        );
      }

      state = state.copyWith(
        status: MemoryDetailLoadStatus.loaded,
        memory: found,
      );

      // Initial load of comments
      if (mounted) {
        await loadComments(replaceAll: true);
      }
    } catch (e, stack) {
      if (mounted) {
        final mapped = mapException(e, stack);
        state = state.copyWith(
          status: MemoryDetailLoadStatus.error,
          errorMessage: mapped.toString(),
        );
      }
    }
  }

  Future<void> loadComments({bool replaceAll = false}) async {
    if (!mounted || state.isCommentsLoading) return;
    state = state.copyWith(isCommentsLoading: true);

    try {
      final cursor = replaceAll ? null : state.commentCursor;
      List<CommentItem> fetchedComments = [];
      String? nextCursor;

      if (kUseMockBackend) {
        // Mock comments load
        await Future.delayed(const Duration(milliseconds: 150));
        if (replaceAll) {
          fetchedComments = [
            CommentItem(
              id: 'mock-c1',
              memoryId: _memoryId,
              person: 'Amara',
              username: 'amara',
              text: 'Oh my days! This is amazing!',
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
            CommentItem(
              id: 'mock-c2',
              memoryId: _memoryId,
              person: 'Leo',
              username: 'leo',
              text: 'Love the gradient colors here',
              timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
            ),
          ];
          nextCursor = 'mock-comment-page-2';
        } else if (cursor == 'mock-comment-page-2') {
          fetchedComments = [
            CommentItem(
              id: 'mock-c3',
              memoryId: _memoryId,
              person: 'Nia',
              username: 'nia',
              text: 'Absolutely stunning visual vibe',
              timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ];
          nextCursor = null; // No more
        }
      } else {
        final dio = _ref.read(apiClientProvider);
        final params = {
          'limit': 15,
          if (cursor != null) 'cursor': cursor,
        };
        final response = await dio.get('/memories/$_memoryId/comments', queryParameters: params);
        final rawList = response.data['comments'] as List? ?? [];
        fetchedComments = rawList.map((item) {
          final creator = item['creator'] as Map<String, dynamic>?;
          return CommentItem(
            id: item['id'] as String? ?? '',
            memoryId: _memoryId,
            person: item['person'] as String? ?? creator?['first_name'] as String? ?? 'Friend',
            username: creator?['username'] as String? ?? '',
            text: item['text'] as String? ?? '',
            timestamp: DateTime.tryParse(item['timestamp']?.toString() ?? '') ?? DateTime.now(),
            avatarUrl: creator?['avatar_url'] as String?,
          );
        }).toList();

        final meta = response.data['meta'] as Map<String, dynamic>?;
        nextCursor = meta?['nextCursor'] as String?;
      }

      final newList = replaceAll ? fetchedComments : [...state.comments, ...fetchedComments];
      // Deduplicate comments by ID
      final Map<String, CommentItem> deduped = {};
      for (final c in newList) {
        deduped[c.id] = c;
      }

      if (mounted) {
        state = state.copyWith(
          comments: deduped.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp)), // Newest first
          commentCursor: nextCursor,
          hasMoreComments: nextCursor != null,
          isCommentsLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isCommentsLoading: false);
      }
    }
  }

  // ─── Optimistic Comment Posting with Transactional Rollback ─────────────────

  Future<void> postComment(String text) async {
    if (text.trim().isEmpty) return;

    final user = _ref.read(authProvider);
    final optimisticId = 'local-comment-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticComment = CommentItem(
      id: optimisticId,
      memoryId: _memoryId,
      person: user.firstName.isNotEmpty ? user.firstName : 'You',
      username: user.username,
      text: text.trim(),
      timestamp: DateTime.now(),
      avatarUrl: user.avatarUrl,
    );

    // Save backup of current comments
    _commentsBackup = List<CommentItem>.from(state.comments);

    // Optimistically insert at front
    state = state.copyWith(
      comments: [optimisticComment, ...state.comments],
      isPostingComment: true,
      errorMessage: null,
    );

    try {
      if (kUseMockBackend) {
        await Future.delayed(const Duration(milliseconds: 150));
      } else {
        final dio = _ref.read(apiClientProvider);
        final response = await dio.post('/memories/$_memoryId/comments', data: {
          'text': text.trim(),
        });
        final raw = response.data;
        final creator = raw['creator'] as Map<String, dynamic>?;
        final realComment = CommentItem(
          id: raw['id'] as String? ?? '',
          memoryId: _memoryId,
          person: raw['person'] as String? ?? creator?['first_name'] as String? ?? 'You',
          username: creator?['username'] as String? ?? '',
          text: raw['text'] as String? ?? '',
          timestamp: DateTime.tryParse(raw['timestamp']?.toString() ?? '') ?? DateTime.now(),
          avatarUrl: creator?['avatar_url'] as String?,
        );

        // Replace optimistic representation with the confirmed backend item
        final updated = List<CommentItem>.from(state.comments);
        final idx = updated.indexWhere((c) => c.id == optimisticId);
        if (idx != -1) {
          updated[idx] = realComment;
        }
        state = state.copyWith(comments: updated);
      }

      state = state.copyWith(isPostingComment: false);
      _commentsBackup = null; // Clear backup on success
    } catch (e, stack) {
      state = state.copyWith(
        isPostingComment: false,
        comments: _commentsBackup ?? state.comments, // Rollback immediately
        errorMessage: mapException(e, stack).toString(),
      );
      _commentsBackup = null;
    }
  }

  // ─── Reaction Syncing ───────────────────────────────────────────────────────

  Future<void> toggleLike() async {
    final m = state.memory;
    if (m == null) return;

    _memoryBackup = m;

    final optimisticLiked = !m.isLiked;
    final optimisticCount = m.likeCount + (optimisticLiked ? 1 : -1);
    final optimisticItem = m.copyWith(isLiked: optimisticLiked, likeCount: optimisticCount);

    state = state.copyWith(memory: optimisticItem);

    // Sync to feedProvider first so it stays in sync immediately
    _ref.read(feedProvider.notifier).toggleLike(m.id).catchError((_) {
      // Revert if feed manager failed and rolled back
      state = state.copyWith(memory: _memoryBackup);
    });
  }



  Future<void> sendReaction(String emoji) async {
    final m = state.memory;
    if (m == null) return;

    _memoryBackup = m;

    final currentCount = m.reactions[emoji] ?? 0;
    final isRemoving = currentCount > 0;
    final targetCount = isRemoving ? currentCount - 1 : currentCount + 1;

    final updated = Map<String, int>.from(m.reactions);
    if (targetCount <= 0) {
      updated.remove(emoji);
    } else {
      updated[emoji] = targetCount;
    }

    final optimisticItem = m.copyWith(reactions: updated);
    state = state.copyWith(memory: optimisticItem);

    _ref.read(feedProvider.notifier).sendReaction(m.id, emoji).catchError((_) {
      state = state.copyWith(memory: _memoryBackup);
    });
  }

  // ─── Phase 2: Transactional Editing ────────────────────────────────────────

  void setDraftCaption(String text) {
    state = state.copyWith(draftCaption: text);
  }

  Future<void> saveCaptionEdit() async {
    final m = state.memory;
    final draft = state.draftCaption;
    if (m == null || draft == null) return;

    state = state.copyWith(isSavingEdit: true, errorMessage: null);
    _memoryBackup = m;

    final optimisticItem = m.copyWith(caption: draft);
    state = state.copyWith(memory: optimisticItem);

    try {
      if (kUseMockBackend) {
        await Future.delayed(const Duration(milliseconds: 150));
      } else {
        final dio = _ref.read(apiClientProvider);
        await dio.patch('/memories/${m.id}', data: {'caption': draft});
      }

      // Propagate update in-place to main FeedStateManager cache indices
      final feedNotifier = _ref.read(feedProvider.notifier);
      final list = List<MemoryItem>.from(feedNotifier.state.memories);
      final idx = list.indexWhere((item) => item.id == m.id);
      if (idx != -1) {
        list[idx] = optimisticItem;
        feedNotifier.state = feedNotifier.state.copyWith(memories: list);
      }

      state = state.copyWith(isSavingEdit: false, isEditing: false, draftCaption: null);
      _memoryBackup = null;
    } catch (e, stack) {
      state = state.copyWith(
        isSavingEdit: false,
        memory: _memoryBackup, // Rollback immediately
        errorMessage: mapException(e, stack).toString(),
      );
      _memoryBackup = null;
    }
  }

  // ─── Phase 3: Transactional Deletion ───────────────────────────────────────

  Future<bool> deleteMemory() async {
    final m = state.memory;
    if (m == null) return false;

    state = state.copyWith(isDeleting: true, errorMessage: null);

    try {
      if (kUseMockBackend) {
        await Future.delayed(const Duration(milliseconds: 150));
      } else {
        final dio = _ref.read(apiClientProvider);
        await dio.delete('/memories/${m.id}');
      }

      // Remove from feedStateManager
      _ref.read(feedProvider.notifier).deleteMemory(m.id);

      state = state.copyWith(isDeleting: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: mapException(e, stack).toString(),
      );
      return false;
    }
  }
}

// Auto-dispose state manager provider parameterized by Memory ID
final memoryDetailProvider = StateNotifierProvider.family.autoDispose<MemoryDetailStateManager, MemoryDetailState, String>((ref, memoryId) {
  return MemoryDetailStateManager(ref, memoryId);
});
