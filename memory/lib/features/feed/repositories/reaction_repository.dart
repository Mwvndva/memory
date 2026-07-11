import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/features/circle/circle.dart';

class ReactionRepository {
  final Ref _ref;
  ReactionRepository(this._ref);

  Future<void> sendReaction(
    String memoryId,
    String emoji, {
    bool isRemoving = false,
  }) async {
    if (kUseMockBackend) {
      await Future.delayed(const Duration(milliseconds: 150));
      return;
    }
    final chatNotifier = _ref.read(chatProvider.notifier);
    await chatNotifier.sendReactionEvent(
      memoryId,
      emoji,
      isRemoving ? 'remove' : 'add',
    );
  }
}

final reactionRepositoryProvider = Provider<ReactionRepository>((ref) {
  return ReactionRepository(ref);
});
