import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../models/memory_item.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/memory_repository.dart';

class MainAppScaffold extends ConsumerWidget {
  const MainAppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(isDarkProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final bg = dark ? kDarkCream : kCream;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: _tabBar(context, currentPath, dark, ref),
          ),
        ],
      ),
    );
  }

  Widget _tabBar(BuildContext context, String path, bool dark, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final unread = chatState.unreadNotifications;

    return Container(
      height: 58,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: (dark ? kDarkPaper : kPaper).withValues(alpha: .9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _tab(context, path == '/feed', '/feed', Icons.more_horiz_rounded, 'Memory', dark),
          _tab(
            context,
            path == '/capture',
            '/capture',
            Icons.radio_button_checked_rounded,
            'Capture',
            dark,
            wide: true,
          ),
          _tab(
            context,
            path == '/circle',
            '/circle',
            Icons.circle_outlined,
            'Circle',
            dark,
            badge: unread > 0 ? '$unread' : null,
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    bool active,
    String route,
    IconData icon,
    String label,
    bool dark, {
    bool wide = false,
    String? badge,
  }) {
    return Expanded(
      flex: wide ? 12 : 10,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? (dark ? const Color(0xFF4A2B27) : const Color(0xFFFFE7DD))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active
                        ? kCoral
                        : (dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? kCoral
                          : (dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                right: 8,
                top: -3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: kCoral,
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MemoryFeedView extends ConsumerStatefulWidget {
  const MemoryFeedView({super.key});

  @override
  ConsumerState<MemoryFeedView> createState() => _MemoryFeedViewState();
}

class _MemoryFeedViewState extends ConsumerState<MemoryFeedView> {
  int _activeMemoryIndex = 0;
  bool _composerOpen = false;
  bool _gridOpen = false;
  bool _fromGrid = false;

  VideoPlayerController? _feedVideoController;
  int? _lastInitializedIndex;
  bool _isMuted = false;

  @override
  void dispose() {
    _feedVideoController?.dispose();
    super.dispose();
  }

  void _nextMemory(int count) {
    if (count == 0) return;
    setState(() => _activeMemoryIndex = (_activeMemoryIndex + 1) % count);
  }

  void _previousMemory(int count) {
    if (count == 0) return;
    setState(() => _activeMemoryIndex = (_activeMemoryIndex - 1 + count) % count);
  }

  void _setGridOpen(bool open) {
    setState(() {
      _gridOpen = open;
      _composerOpen = false;
    });
    if (open) {
      _feedVideoController?.pause();
    } else {
      _feedVideoController?.play();
    }
  }

  Future<void> _initFeedVideo(MemoryItem m, int index) async {
    if (index == _lastInitializedIndex) return;

    final oldController = _feedVideoController;
    _feedVideoController = null;
    _lastInitializedIndex = null;
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }

    if (m.videoPath == null || m.videoPath!.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    final String path = m.videoPath!;
    final VideoPlayerController controller;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      final file = File(path);
      if (!file.existsSync()) {
        if (mounted) setState(() {});
        return;
      }
      controller = VideoPlayerController.file(file);
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.play();

      if (mounted && _activeMemoryIndex == index) {
        setState(() {
          _feedVideoController = controller;
          _lastInitializedIndex = index;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing feed video at index $index: $e');
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final feedMemories = ref.watch(feedMemoriesProvider);
    final archivedMemories = ref.watch(archivedMemoriesProvider);
    final top = MediaQuery.paddingOf(context).top;

    if (feedMemories.isEmpty) {
      return Scaffold(
        backgroundColor: dark ? kCharcoal : kCream,
        body: const Center(
          child: Text('No memories shared yet. Capture one!'),
        ),
      );
    }

    // Determine current active memory
    final listToUse = _fromGrid ? archivedMemories : feedMemories;
    if (listToUse.isEmpty) {
      // Fallback
      return Scaffold(
        backgroundColor: dark ? kCharcoal : kCream,
        body: const Center(child: Text('No memories in this view.')),
      );
    }
    final activeIndex = _activeMemoryIndex % listToUse.length;
    final m = listToUse[activeIndex];

    // Trigger video initialization if active index changed
    if (activeIndex != _lastInitializedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initFeedVideo(m, activeIndex);
      });
    }

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < 0) _nextMemory(listToUse.length);
          if ((details.primaryVelocity ?? 0) > 0) _previousMemory(listToUse.length);
        },
        onTap: () => setState(() => _composerOpen = !_composerOpen),
        child: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: m.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  if (_feedVideoController != null && _feedVideoController!.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _feedVideoController!.value.size.width,
                        height: _feedVideoController!.value.size.height,
                        child: VideoPlayer(_feedVideoController!),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: top + 16,
              left: 22,
              child: _roundIcon(
                _fromGrid && !_gridOpen ? Icons.arrow_back_ios_new_rounded : Icons.grid_view_rounded,
                () => _setGridOpen(true),
              ),
            ),
            Positioned(
              top: top + 16,
              right: 22,
              child: _roundIcon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _feedVideoController?.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
              ),
            ),
            Positioned(
              top: top + 34,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: m.avatar,
                    child: Text(
                      m.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.person,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    m.time,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
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
            if (_composerOpen)
              Positioned(
                left: 44,
                right: 16,
                bottom: 94,
                child: _messageComposer(m),
              ),
            if (_gridOpen)
              Positioned.fill(
                child: _memoryGrid(archivedMemories, dark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memoryGrid(List<MemoryItem> archived, bool dark) {
    // Generate a fixed 12 grid items repeating if archived is short
    final gridItems = List.generate(12, (i) => archived[i % archived.length]);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) setState(() => _gridOpen = false);
      },
      child: Container(
        color: dark ? kCharcoal : kPaper,
        padding: const EdgeInsets.fromLTRB(26, 82, 26, 90),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                Text(
                  'All memories',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _smallClose(() {
                  _setGridOpen(false);
                  if (_fromGrid) {
                    setState(() {
                      _fromGrid = false;
                      _activeMemoryIndex = 0;
                    });
                  }
                }, dark),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: gridItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: .74,
                ),
                itemBuilder: (_, i) {
                  final m = gridItems[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _fromGrid = true;
                        _activeMemoryIndex = i;
                      });
                      _setGridOpen(false);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: m.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: m.avatar,
                            child: Text(
                              m.initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageComposer(MemoryItem m) {
    final dark = ref.read(isDarkProvider);

    void sendQuickReaction(String emoji) {
      ref.read(chatProvider.notifier).sendMessage(m.person, "Reacted $emoji to your memory: \"${m.caption}\"");
      setState(() => _composerOpen = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction sent to ${m.person}!')),
      );
    }

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Open direct message with person
                context.push('/chat/${m.person}');
              },
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: dark ? kDarkPaper : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Send ${m.person} a message',
                        style: TextStyle(
                          color: dark ? kCream.withValues(alpha: 0.6) : kCharcoal.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kCoral,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            height: 132,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _emojiButton('❤️', sendQuickReaction),
                _emojiButton('😂', sendQuickReaction),
                _emojiButton('🔥', sendQuickReaction),
                _emojiButton('😭', sendQuickReaction),
                _emojiButton('✨', sendQuickReaction),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiButton(String emoji, Function(String) onTap) => GestureDetector(
        onTap: () => onTap(emoji),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 15, height: 1)),
          ),
        ),
      );

  Widget _roundIcon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .22),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _smallClose(VoidCallback onTap, bool dark) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dark ? kDarkCream : kCream,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            color: dark ? kCream : kCharcoal,
            size: 18,
          ),
        ),
      );
}
