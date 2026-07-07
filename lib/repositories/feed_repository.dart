import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'memory_repository.dart';

class FeedRepository {
  final Ref _ref;
  FeedRepository(this._ref);

  Future<void> fetchFeed({bool force = false}) async {
    await _ref.read(feedProvider.notifier).fetchFeed(force: force);
  }

  Future<void> refreshFeed({bool force = true}) async {
    await _ref.read(feedProvider.notifier).refreshFeed(force: force);
  }

  Future<void> loadMore() async {
    await _ref.read(feedProvider.notifier).loadMore();
  }

  Future<void> retryCurrentFailure() async {
    await _ref.read(feedProvider.notifier).retryCurrentFailure();
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref);
});
