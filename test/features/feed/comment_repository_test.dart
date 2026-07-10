import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/features/feed/feed.dart';

/// Serves the payloads emitted by the backend's CommentsController verbatim:
///
///   GET  /memories/:id/comments → { comments: [...], meta: { nextCursor } }
///   POST /memories/:id/comments → a single comment object
///
/// The client and server were written against each other by inspection; these
/// tests pin the shape so a rename on either side fails here rather than at
/// runtime with a silently-empty comment list.
class _CommentsApiInterceptor extends Interceptor {
  _CommentsApiInterceptor({this.nextCursor});

  final String? nextCursor;
  final List<RequestOptions> requests = [];

  /// Passing [person] as null omits the key entirely, which is the only way
  /// the client's `person ?? creator.username` fallback can fire.
  static Map<String, dynamic> comment({
    required String id,
    required String text,
    String? person = 'Amara',
    String username = 'amara',
    String? avatarUrl = 'https://cdn/a.png',
    String createdAt = '2026-07-01T12:00:00.000Z',
  }) => {
    'id': id,
    'person': ?person,
    'text': text,
    'created_at': createdAt,
    'creator': {'id': 'u-1', 'username': username, 'avatar_url': avatarUrl},
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);

    if (options.method == 'GET' && options.path.endsWith('/comments')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'comments': [
              comment(id: 'c1', text: 'This is an amazing memory!'),
              comment(
                id: 'c2',
                text: 'So proud of you!',
                person: null,
                username: 'mum',
                avatarUrl: null,
              ),
            ],
            'meta': {'nextCursor': nextCursor, 'limit': 10},
          },
        ),
      );
      return;
    }

    if (options.method == 'POST' && options.path.endsWith('/comments')) {
      final body = options.data as Map<String, dynamic>;
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: comment(id: 'c-new', text: body['text'] as String),
        ),
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

ProviderContainer _container(_CommentsApiInterceptor interceptor) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..interceptors.add(interceptor);
  return ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(dio)],
  );
}

void main() {
  test('fetchComments parses the backend page shape', () async {
    final interceptor = _CommentsApiInterceptor(
      nextCursor: '2026-07-01T11:00:00.000Z',
    );
    final container = _container(interceptor);

    final page = await container
        .read(commentRepositoryProvider)
        .fetchComments('m-1');

    expect(page.comments, hasLength(2));
    expect(page.nextCursor, '2026-07-01T11:00:00.000Z');

    final first = page.comments.first;
    expect(first.id, 'c1');
    expect(first.memoryId, 'm-1');
    expect(first.person, 'Amara');
    expect(first.username, 'amara');
    expect(first.text, 'This is an amazing memory!');
    expect(first.avatarUrl, 'https://cdn/a.png');
    expect(first.timestamp, DateTime.parse('2026-07-01T12:00:00.000Z'));
  });

  test(
    'fetchComments falls back to the username when person is absent',
    () async {
      final container = _container(_CommentsApiInterceptor());

      final page = await container
          .read(commentRepositoryProvider)
          .fetchComments('m-1');

      final second = page.comments[1];
      expect(second.person, 'mum');
      expect(second.username, 'mum');
      expect(second.avatarUrl, isNull);
    },
  );

  test('fetchComments reports a null cursor on the last page', () async {
    final container = _container(_CommentsApiInterceptor());

    final page = await container
        .read(commentRepositoryProvider)
        .fetchComments('m-1');

    expect(page.nextCursor, isNull);
  });

  test('fetchComments forwards limit and cursor as query parameters', () async {
    final interceptor = _CommentsApiInterceptor();
    final container = _container(interceptor);

    await container
        .read(commentRepositoryProvider)
        .fetchComments('m-1', cursor: '2026-07-01T10:00:00.000Z', limit: 25);

    final req = interceptor.requests.single;
    expect(req.path, '/memories/m-1/comments');
    expect(req.queryParameters['limit'], 25);
    expect(req.queryParameters['cursor'], '2026-07-01T10:00:00.000Z');
  });

  test('postComment sends the text and parses the created comment', () async {
    final interceptor = _CommentsApiInterceptor();
    final container = _container(interceptor);

    final created = await container
        .read(commentRepositoryProvider)
        .postComment('m-1', 'Great shot');

    final req = interceptor.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/memories/m-1/comments');
    expect((req.data as Map)['text'], 'Great shot');

    expect(created.id, 'c-new');
    expect(created.memoryId, 'm-1');
    expect(created.text, 'Great shot');
    expect(created.username, 'amara');
  });
}
