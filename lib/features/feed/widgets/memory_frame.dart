import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/auth/auth.dart';

class MemoryFrame extends ConsumerWidget {
  final MemoryItem memory;
  final bool dark;
  final bool showCaption;
  final Widget mediaWidget;
  final Widget Function(MemoryItem) reactionCarouselBuilder;
  final Widget Function(MemoryItem, bool) messageInputBuilder;
  final bool composerOpen;

  const MemoryFrame({
    required Key key,
    required this.memory,
    required this.dark,
    required this.showCaption,
    required this.mediaWidget,
    required this.reactionCarouselBuilder,
    required this.messageInputBuilder,
    required this.composerOpen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const radius = 74.0;
    final m = ref.watch(
      feedProvider.select((state) {
        final index = state.memories.indexWhere((item) => item.id == memory.id);
        return index != -1 ? state.memories[index] : memory;
      }),
    );

    return GestureDetector(
      onDoubleTap: () => context.push('/memory/${m.id}'),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: kYellow, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              mediaWidget,
              if (showCaption)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('caption_${m.person}_${m.caption}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 25 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Text(
                        m.caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                ),
              if (composerOpen)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: messageInputBuilder(m, dark),
                ),
              if (m.username == ref.watch(sessionProvider).user.username)
                Positioned(
                  top: 18,
                  right: 18,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        final path = await ref
                            .read(downloadRepositoryProvider)
                            .downloadMemoryVideo(m);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Video downloaded successfully to: $path',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
