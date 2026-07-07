import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/comment_item.dart';
import 'auth_repository.dart';

class CommentPageResult {
  final List<CommentItem> comments;
  final String? nextCursor;

  const CommentPageResult({required this.comments, this.nextCursor});
}

class CommentRepository {
  final Ref _ref;
  CommentRepository(this._ref);

  Future<CommentPageResult> fetchComments(String memoryId, {String? cursor, int limit = 10}) async {
    if (kUseMockBackend) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (cursor == null) {
        return CommentPageResult(
          comments: [
            CommentItem(
              id: 'mock-comment-1',
              memoryId: memoryId,
              person: 'Amara',
              username: 'amara',
              text: 'This is an amazing memory!',
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
            CommentItem(
              id: 'mock-comment-2',
              memoryId: memoryId,
              person: 'Mum',
              username: 'mum',
              text: 'So proud of you!',
              timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
          nextCursor: 'mock-comment-page-2',
        );
      } else if (cursor == 'mock-comment-page-2') {
        return CommentPageResult(
          comments: [
            CommentItem(
              id: 'mock-comment-3',
              memoryId: memoryId,
              person: 'Leo',
              username: 'leo',
              text: 'Awesome capture!',
              timestamp: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
          nextCursor: null,
        );
      }
      return const CommentPageResult(comments: []);
    }

    final dio = _ref.read(apiClientProvider);
    final Map<String, dynamic> params = {'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await dio.get('/memories/$memoryId/comments', queryParameters: params);
    final rawList = response.data['comments'] as List? ?? [];
    final commentsList = rawList.map<CommentItem>((item) {
      final creator = item['creator'] as Map<String, dynamic>?;
      return CommentItem(
        id: item['id'] as String? ?? '',
        memoryId: memoryId,
        person: item['person'] as String? ?? creator?['username'] as String? ?? 'Anonymous',
        username: creator?['username'] as String? ?? 'anonymous',
        text: item['text'] as String? ?? '',
        timestamp: DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now(),
        avatarUrl: creator?['avatar_url'] as String?,
      );
    }).toList();

    final meta = response.data['meta'] as Map<String, dynamic>?;
    final nextCursor = meta?['nextCursor'] as String?;

    return CommentPageResult(comments: commentsList, nextCursor: nextCursor);
  }

  Future<CommentItem> postComment(String memoryId, String text) async {
    if (kUseMockBackend) {
      await Future.delayed(const Duration(milliseconds: 150));
      final currentUser = _ref.read(sessionProvider).user;
      return CommentItem(
        id: 'mock-comment-posted-${DateTime.now().millisecondsSinceEpoch}',
        memoryId: memoryId,
        person: currentUser.firstName.isNotEmpty ? currentUser.firstName : 'Me',
        username: currentUser.username,
        text: text,
        timestamp: DateTime.now(),
        avatarUrl: currentUser.avatarUrl,
      );
    }

    final dio = _ref.read(apiClientProvider);
    final response = await dio.post('/memories/$memoryId/comments', data: {
      'text': text,
    });
    final item = response.data;
    final creator = item['creator'] as Map<String, dynamic>?;
    return CommentItem(
      id: item['id'] as String? ?? '',
      memoryId: memoryId,
      person: item['person'] as String? ?? creator?['username'] as String? ?? 'Anonymous',
      username: creator?['username'] as String? ?? 'anonymous',
      text: item['text'] as String? ?? '',
      timestamp: DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now(),
      avatarUrl: creator?['avatar_url'] as String?,
    );
  }
}

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(ref);
});
