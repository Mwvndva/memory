import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../models/memory_item.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../core/api_config.dart';
import '../../repositories/auth_repository.dart';
import 'package:share_plus/share_plus.dart';
import '../../repositories/circles_repository.dart';
import '../../models/user_profile.dart';
import 'streak_milestones.dart';

String _formatImageUrl(String url) {
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    return url.replaceFirst(uri.authority, baseUri.authority);
  }
  return url;
}

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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18 + MediaQuery.paddingOf(context).bottom,
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
        gradient: LinearGradient(
          colors: dark
              ? [kDarkPaper.withValues(alpha: 0.95), kCharcoal.withValues(alpha: 0.9)]
              : [Colors.white.withValues(alpha: 0.92), kCream.withValues(alpha: 0.88)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: kCoral.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
                gradient: active
                    ? LinearGradient(
                        colors: dark
                            ? [const Color(0xFFE84F3B), const Color(0xFFE84F3B).withValues(alpha: 0.75)]
                            : [const Color(0xFFFF6B57), const Color(0xFFFF826E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: kCoral.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active
                        ? Colors.white
                        : (dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : (dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62)),
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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
                  backgroundColor: active ? Colors.white : kCoral,
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: active ? kCoral : Colors.white,
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
  int? _enqueuedIndex;
  bool _isMuted = false;
  bool _feedReady = false; // gates gradient: prevents purple flash before first video init

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(authProvider.notifier).fetchProfile();
      }
    });
  }

  @override
  void dispose() {
    _feedVideoController?.dispose();
    super.dispose();
  }

  void _nextMemory(int count) {
    if (count == 0) return;
    setState(() {
      _activeMemoryIndex = (_activeMemoryIndex + 1) % count;
      _feedReady = false;
    });
  }

  void _previousMemory(int count) {
    if (count == 0) return;
    setState(() {
      _activeMemoryIndex = (_activeMemoryIndex - 1 + count) % count;
      _feedReady = false;
    });
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
    if (index != _activeMemoryIndex) return;

    final oldController = _feedVideoController;
    _feedVideoController = null;
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }

    if (m.videoPath == null || m.videoPath!.isEmpty) {
      // No video — mark ready immediately so the gradient/caption shows
      if (mounted) setState(() { _feedReady = true; });
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
          _enqueuedIndex = index;
          _feedReady = true;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing feed video at index $index: $e');
      controller.dispose();
      // Still mark ready so UI doesn't stay permanently black on error
      if (mounted) setState(() { _feedReady = true; });
    }
  }

  void _showInviteSheet(BuildContext context) {
    final dark = ref.read(isDarkProvider);
    final user = ref.read(authProvider);
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    final inviteLink = 'https://memory.app/invite/$displayUsername';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: dark ? kDarkPaper : kPaper,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite friends to share memories',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await SharePlus.instance.share(
                            ShareParams(
                              text: 'Join my circle on Memory! $inviteLink',
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF058A0).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                              SizedBox(width: 6),
                              Text(
                                'Instagram',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await SharePlus.instance.share(
                            ShareParams(
                              text: 'Join my circle on Memory! $inviteLink',
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 15),
                              SizedBox(width: 6),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied!')),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? kCream : kCharcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Copy invite link',
                      style: TextStyle(
                        color: dark ? kCharcoal : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final feedMemories = ref.watch(feedMemoriesProvider);
    final archivedMemories = ref.watch(archivedMemoriesProvider);
    final top = MediaQuery.paddingOf(context).top;

    ref.listen<UserProfile>(authProvider, (previous, next) {
      if (next.isAuthenticated && context.mounted) {
        checkMilestones(context, ref, next.streakDays);
      }
    });

    if (feedMemories.isEmpty) {
      final circleMembers = ref.watch(circlesProvider);

      if (circleMembers.isEmpty) {
        // Show '+' invite layout only if the user has no friends in their circle
        return Scaffold(
          backgroundColor: dark ? kCharcoal : kCream,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showInviteSheet(context),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: kCoral,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kCoral.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'invite friends to share memories',
                  style: TextStyle(
                    color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Show standard placeholder if they have friends but no active memories shared in the last 24h
        return Scaffold(
          backgroundColor: dark ? kCharcoal : kCream,
          body: const Center(
            child: Text('No memories shared yet. Capture one!'),
          ),
        );
      }
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

    final isUrlCaption = m.caption.startsWith('http://') || m.caption.startsWith('https://');
    final isVideoLoading = m.videoPath != null && m.videoPath!.isNotEmpty && (_feedVideoController == null || !_feedVideoController!.value.isInitialized);
    final showCaption = m.caption.isNotEmpty && !isUrlCaption && !isVideoLoading;

    // Trigger video initialization if active index changed
    if (activeIndex != _enqueuedIndex) {
      _enqueuedIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initFeedVideo(m, activeIndex);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black, // prevent Material3 theme lavender from bleeding through
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
                  // Always show black until feed is ready — prevents purple gradient flash
                  if (!_feedReady)
                    Container(color: Colors.black)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: m.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  if (m.videoPath != null && m.videoPath!.isNotEmpty && (_feedVideoController == null || !_feedVideoController!.value.isInitialized))
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: kCoral),
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
                () {
                  if (_fromGrid && !_gridOpen) {
                    setState(() {
                      _fromGrid = false;
                      _activeMemoryIndex = 0;
                    });
                  } else {
                    _setGridOpen(true);
                  }
                },
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
              child: TweenAnimationBuilder<double>(
                key: ValueKey('header_${m.person}_${m.caption}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -15 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: m.avatar,
                      backgroundImage: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                          ? NetworkImage(_formatImageUrl(m.avatarUrl!)) as ImageProvider
                          : null,
                      child: m.avatarUrl == null || m.avatarUrl!.isEmpty
                          ? Text(
                              m.initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.person,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      m.time,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showCaption)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('caption_${m.person}_${m.caption}'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
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
            if (_composerOpen)
              Positioned(
                left: 44,
                right: 16,
                bottom: 94 + MediaQuery.paddingOf(context).bottom,
                child: _messageComposer(m),
              ),
            if (_gridOpen)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 50 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _memoryGrid(archivedMemories, dark),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memoryGrid(List<MemoryItem> archived, bool dark) {
    if (archived.isEmpty) {
      return Container(
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
                _smallClose(() => _setGridOpen(false), dark),
              ],
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'No archived memories yet.\nMemories older than 24h will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 200 + (i * 30)), // Staggered scale-in!
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _fromGrid = true;
                          _activeMemoryIndex = i % archived.length;
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
      height: 210,
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
                          fontWeight: FontWeight.w600,
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
                          fontWeight: FontWeight.w700,
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
            width: 44,
            height: 210,
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
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap(emoji);
        },
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
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
