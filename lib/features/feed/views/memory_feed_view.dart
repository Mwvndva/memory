import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/core/api_config.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/media/playback_coordinator.dart';

class MemoryFeedView extends ConsumerStatefulWidget {
  const MemoryFeedView({super.key});

  @override
  ConsumerState<MemoryFeedView> createState() => _MemoryFeedViewState();
}

/// Namespace for this view's [PlaybackCoordinator] keys, so the feed can
/// release its own controllers without touching anyone else's.
const String _feedVideoKeyPrefix = 'feed_video_';

class _MemoryFeedViewState extends ConsumerState<MemoryFeedView>
    with WidgetsBindingObserver {
  int _activeMemoryIndex = 0;
  bool _composerOpen = false;
  bool _gridOpen = false;
  bool _fromGrid = false;

  VideoPlayerController? _feedVideoController;
  int? _enqueuedIndex;
  bool _isMuted = false;
  bool _feedReady =
      false; // gates gradient: prevents purple flash before first video init

  final ScrollController _gridScrollController = ScrollController();
  final PageController _pageController = PageController();

  /// Moves the feed PageView to [index] after the current frame, once the
  /// PageView has rebuilt with the item count for the list it is showing.
  /// Jumping synchronously can target an index the old list does not contain.
  void _syncPageTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gridScrollController.addListener(_onGridScroll);
    Future.microtask(() {
      if (mounted) {
        ref.read(sessionProvider.notifier).fetchProfile();
        ref.read(feedProvider.notifier).fetchFeed(force: true).catchError((
          err,
        ) {
          if (mounted && context.mounted) {
            showAppError(context, err.toString());
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final feedState = ref.read(feedProvider);
      final lastRefresh = feedState.lastRefreshTime;

      // Automatic Refresh: staleness limit is set to 5 minutes (300 seconds)
      final bool isStale =
          lastRefresh == null ||
          DateTime.now().difference(lastRefresh).inSeconds > 300;

      if (isStale) {
        ref.read(feedProvider.notifier).fetchFeed(force: true).catchError((
          err,
        ) {
          debugPrint('Silent lifecycle refresh failed: $err');
        });
      }
    }
  }

  void _onGridScroll() {
    if (!_gridScrollController.hasClients) return;
    final maxScroll = _gridScrollController.position.maxScrollExtent;
    final currentScroll = _gridScrollController.position.pixels;
    // Trigger loadMore when scrolled to 85% of the list height
    if (currentScroll >= maxScroll * 0.85) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gridScrollController.removeListener(_onGridScroll);
    _gridScrollController.dispose();
    _pageController.dispose();
    // Do not call _feedVideoController?.dispose() directly here since
    // PlaybackCoordinator owns the controller and manages its caching and disposal.
    // Pause the active key to stop audio/video resource consumption cleanly on exit.
    if (_enqueuedIndex != null) {
      final key = '$_feedVideoKeyPrefix$_enqueuedIndex';
      ref.read(playbackCoordinatorProvider).pause(key);
    }
    super.dispose();
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

    if (m.videoPath == null || m.videoPath!.isEmpty) {
      // No video — mark ready immediately so the gradient/caption shows
      if (mounted) {
        setState(() {
          _feedReady = true;
        });
      }
      return;
    }

    final String path = m.videoPath!;
    final coordinator = ref.read(playbackCoordinatorProvider);

    try {
      final key = '$_feedVideoKeyPrefix$index';
      final controller = await coordinator.getOrCreateController(key, path);

      if (controller == null) {
        if (mounted) {
          setState(() {
            _feedReady = true;
          });
        }
        return;
      }

      if (mounted && _activeMemoryIndex == index) {
        setState(() {
          _feedVideoController = controller;
          _enqueuedIndex = index;
          _feedReady = true;
        });
        coordinator.play(key);

        // Only the active memory's controller is ever rendered, so every other
        // feed controller is a decoder held open for nothing. Release them once
        // the new one is live.
        coordinator.releaseControllersWhere(
          (k) => k.startsWith(_feedVideoKeyPrefix) && k != key,
        );
      }
    } catch (e) {
      debugPrint(
        'Error initializing feed video at index $index via PlaybackCoordinator: $e',
      );
      if (mounted) {
        setState(() {
          _feedReady = true;
        });
      }
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: dark ? MemoryColors.ink : MemoryColors.accent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite friends to share memories',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? MemoryColors.cream : MemoryColors.charcoal,
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
                              colors: [
                                Color(0xFFF058A0),
                                Color(0xFFBD3EFF),
                                Color(0xFFFF6B00),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFF058A0,
                                ).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
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
                                color: const Color(
                                  0xFF25D366,
                                ).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
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
                    showAppMessage(context, 'Invite link copied!');
                  },
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Copy invite link',
                      style: TextStyle(
                        color: dark ? MemoryColors.charcoal : Colors.white,
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

    ref.listen<FeedState>(feedProvider, (previous, next) {
      // If we failed to refresh but have memories already, show an unobtrusive notification toast
      if (next.status == FeedLoadStatus.error && next.memories.isNotEmpty) {
        final isOffline = next.errorCategory == FeedErrorCategory.network;
        showAppError(
          context,
          isOffline
              ? 'Network connection lost. Showing cached memories.'
              : 'Could not refresh feed: ${next.errorMessage}',
        );
      }
    });

    final feedState = ref.watch(feedProvider);
    final circleMembers = ref.watch(circlesProvider);

    // Initial Load Failure (No cached memories & error state active)
    if (feedMemories.isEmpty && feedState.status == FeedLoadStatus.error) {
      final isOffline = feedState.errorCategory == FeedErrorCategory.network;
      return Scaffold(
        backgroundColor: const Color(0xFFF4C430),
        body: Stack(
          children: [
            Positioned(
              top: top + 16,
              left: 22,
              child: _roundIcon(
                Icons.arrow_back_ios_new_rounded,
                () => context.go('/capture'),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOffline
                          ? Icons.wifi_off_rounded
                          : Icons.error_outline_rounded,
                      size: 76,
                      color: dark ? MemoryColors.ink : MemoryColors.charcoal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isOffline
                          ? 'No internet connection.\nPlease check your network settings.'
                          : 'Unable to load your memories.\nPlease try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? MemoryColors.ink : MemoryColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    MemoryButton(
                      label: 'Retry',
                      dark: dark,
                      width: 180,
                      onPressed: () {
                        ref.read(feedProvider.notifier).retryCurrentFailure();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (circleMembers.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4C430),
        body: Stack(
          children: [
            Positioned(
              top: top + 16,
              left: 22,
              child: _roundIcon(
                Icons.arrow_back_ios_new_rounded,
                () => context.go('/capture'),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showInviteSheet(context),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: dark ? MemoryColors.accent : MemoryColors.ink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (dark ? MemoryColors.accent : MemoryColors.ink)
                                    .withValues(alpha: 0.4),
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
                      color: dark
                          ? MemoryColors.cream.withValues(alpha: 0.8)
                          : MemoryColors.charcoal.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (feedMemories.isEmpty && !_gridOpen && !_fromGrid) {
      final isOffline = feedState.isOffline;
      return Scaffold(
        backgroundColor: const Color(0xFFF4C430),
        body: Stack(
          children: [
            Positioned(
              top: top + 16,
              left: 22,
              child: _roundIcon(
                Icons.arrow_back_ios_new_rounded,
                () => context.go('/capture'),
              ),
            ),
            Positioned(
              top: top + 16,
              right: 22,
              child: _roundIcon(
                Icons.grid_view_rounded,
                () => setState(() => _gridOpen = true),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.history_toggle_off_rounded,
                    size: 76,
                    color: dark
                        ? MemoryColors.cream.withValues(alpha: 0.8)
                        : MemoryColors.charcoal.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOffline
                        ? 'no internet connection\nshowing cached state if available'
                        : 'no memories posted in last 24hrs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark
                          ? MemoryColors.cream.withValues(alpha: 0.8)
                          : MemoryColors.charcoal.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Determine current active memory
    final listToUse = _fromGrid ? archivedMemories : feedMemories;
    final bool isEmptyFeed = listToUse.isEmpty;
    final activeIndex = isEmptyFeed ? 0 : _activeMemoryIndex % listToUse.length;
    final m = isEmptyFeed ? null : listToUse[activeIndex];

    // Trigger video initialization if active index changed
    if (!isEmptyFeed && m != null && activeIndex != _enqueuedIndex) {
      _enqueuedIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initFeedVideo(m, activeIndex);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // GPU reflection background
          Positioned.fill(
            child: isEmptyFeed || m == null
                ? Container(color: const Color(0xFFFADA5E))
                : _memoryReflectionBackground(m, dark),
          ),
          // Clean vertical snapping PageView between memories
          if (!isEmptyFeed)
            Positioned.fill(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                itemCount: listToUse.length,
                onPageChanged: (idx) {
                  // Pause old video controller before switching pages
                  if (_enqueuedIndex != null && _enqueuedIndex != idx) {
                    final oldKey = '$_feedVideoKeyPrefix$_enqueuedIndex';
                    ref.read(playbackCoordinatorProvider).pause(oldKey);
                  }
                  setState(() {
                    _activeMemoryIndex = idx;
                    _feedReady = false;
                  });
                },
                itemBuilder: (context, index) {
                  final item = listToUse[index];
                  final showCap =
                      item.caption.isNotEmpty &&
                      !(item.caption.startsWith('http://') ||
                          item.caption.startsWith('https://')) &&
                      !(item.videoPath != null &&
                          item.videoPath!.isNotEmpty &&
                          (_feedVideoController == null ||
                              !_feedVideoController!.value.isInitialized));
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: top + 104,
                        bottom: 120 + MediaQuery.paddingOf(context).bottom,
                        left: 28,
                        right: 28,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 3 / 4.3,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(74.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFADA5E,
                                      ).withValues(alpha: 0.14),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: MemoryFrame(
                                  key: ValueKey('memory_card_${item.id}'),
                                  memory: item,
                                  dark: dark,
                                  showCaption: showCap,
                                  mediaWidget: _memoryMedia(item, dark),
                                  reactionCarouselBuilder: _reactionCarousel,
                                  messageInputBuilder: _messageInput,
                                  composerOpen: _composerOpen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _reactionCarousel(item),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (isEmptyFeed)
            Center(
              child: Text(
                'No active memories in the last 24h.\nTap the grid icon to view history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark
                      ? MemoryColors.cream.withValues(alpha: 0.8)
                      : MemoryColors.charcoal.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          Positioned(
            top: top + 16,
            left: 22,
            child: _roundIcon(Icons.arrow_back_ios_new_rounded, () {
              if (_fromGrid && !_gridOpen) {
                _feedVideoController?.pause();
                _setGridOpen(true);
              } else {
                _feedVideoController?.pause();
                context.go('/capture');
              }
            }),
          ),
          if (!_gridOpen) ...[
            Positioned(
              top: top + 16,
              right: 22,
              child: _roundIcon(
                Icons.grid_view_rounded,
                () => _setGridOpen(true),
              ),
            ),
            if (!isEmptyFeed)
              Positioned(
                top: top + 16,
                right: 78,
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
          ],
          if (!isEmptyFeed && m != null)
            Positioned(
              top: top + 24,
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
                    MemoryAvatar(
                      radius: 20,
                      dark: dark,
                      imageUrl: m.avatarUrl == null || m.avatarUrl!.isEmpty
                          ? null
                          : formatImageUrl(m.avatarUrl!),
                      initial: m.initial,
                      background: m.avatar,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.person,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    Text(
                      m.time,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
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
    );
  }

  Widget _memoryReflectionBackground(MemoryItem m, bool dark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1.2x Scaled blurred background representation
        Transform.scale(
          scale: 1.2,
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: _memoryMedia(m, dark),
          ),
        ),
        // GPU accelerated blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: const SizedBox.expand(),
        ),
        // Adaptive brightness overlay
        Container(color: Colors.black.withValues(alpha: 0.68)),
        // Vignette overlay
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.transparent, Colors.black87],
              center: Alignment.center,
              radius: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _memoryMedia(MemoryItem m, bool dark) {
    if (!_feedReady) {
      return Container(color: Colors.black);
    }
    if (m.videoPath != null &&
        m.videoPath!.isNotEmpty &&
        (_feedVideoController == null ||
            !_feedVideoController!.value.isInitialized)) {
      return ColoredBox(
        color: Colors.black,
        child: MemoryLoading.block(
          color: dark ? MemoryColors.accent : MemoryColors.ink,
        ),
      );
    }
    if (_feedVideoController != null &&
        _feedVideoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _feedVideoController!.value.size.width,
          height: _feedVideoController!.value.size.height,
          child: VideoPlayer(_feedVideoController!),
        ),
      );
    }
    return MemoryGradientSurface(colors: m.colors);
  }

  Widget _memoryGrid(List<MemoryItem> archived, bool dark) {
    if (archived.isEmpty) {
      return Container(
        color: dark ? MemoryColors.ink : MemoryColors.accent,
        padding: const EdgeInsets.fromLTRB(26, 82, 26, 90),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                Text(
                  'All memories',
                  style: TextStyle(
                    color: dark ? MemoryColors.cream : MemoryColors.charcoal,
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Use real archived memories directly
    final gridItems = archived;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) {
          setState(() => _gridOpen = false);
        }
      },
      child: Container(
        color: dark ? MemoryColors.ink : MemoryColors.accent,
        padding: const EdgeInsets.fromLTRB(26, 82, 26, 90),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                Text(
                  'All memories',
                  style: TextStyle(
                    color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _smallClose(() {
                  _setGridOpen(false);
                  if (_fromGrid) {
                    _feedVideoController?.pause();
                    setState(() {
                      _fromGrid = false;
                      _activeMemoryIndex = 0;
                    });
                    _syncPageTo(0);
                  }
                }, dark),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                controller: _gridScrollController,
                itemCount: gridItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: .74,
                ),
                itemBuilder: (_, i) {
                  final m = gridItems[i];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                      milliseconds: 200 + (i * 30),
                    ), // Staggered scale-in!
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _fromGrid = true;
                          _activeMemoryIndex = i;
                        });
                        _syncPageTo(i);
                        _setGridOpen(false);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // First-frame thumbnail from video, gradient fallback
                            if (m.videoPath != null && m.videoPath!.isNotEmpty)
                              VideoGridThumbnail(
                                videoUrl: formatImageUrl(m.videoPath!),
                                fallbackColors: m.colors,
                              )
                            else
                              MemoryGradientSurface(colors: m.colors),
                            // Avatar badge at bottom-left using stored avatar URL
                            Positioned(
                              left: 7,
                              bottom: 7,
                              child: MemoryAvatar(
                                radius: 11,
                                dark: dark,
                                imageUrl:
                                    m.avatarUrl == null || m.avatarUrl!.isEmpty
                                    ? null
                                    : formatImageUrl(m.avatarUrl!),
                                initial: m.initial,
                                background: m.avatar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (ref.watch(feedProvider).status == FeedLoadStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ref.watch(feedProvider).errorCategory ==
                              FeedErrorCategory.network
                          ? 'Connection lost. '
                          : 'Load failed. ',
                      style: MemoryTypography.mutedOnSurface(
                        MemoryTypography.caption,
                        dark,
                      ),
                    ),
                    MemoryButton(
                      label: 'Tap to retry',
                      dark: dark,
                      variant: MemoryButtonVariant.text,
                      size: MemoryButtonSize.compact,
                      onPressed: () {
                        ref.read(feedProvider.notifier).retryCurrentFailure();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageInput(MemoryItem m, bool dark) {
    return GestureDetector(
      onTap: () => context.push('/chat/${m.username}'),
      child: Container(
        height: 50,
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: BoxDecoration(
          color: (dark ? MemoryColors.ink : Colors.white).withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Send ${m.person} a message',
                style: TextStyle(
                  color: dark
                      ? MemoryColors.cream.withValues(alpha: 0.6)
                      : MemoryColors.charcoal.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 42,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MemoryColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: MemoryColors.ink,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionCarousel(MemoryItem m) {
    final dark = ref.read(isDarkProvider);

    void sendQuickReaction(String emoji) async {
      try {
        await ref.read(feedProvider.notifier).sendReaction(m.id, emoji);
      } catch (err) {
        if (mounted) {
          showAppError(context, 'Failed to post reaction');
        }
      }
      setState(() => _composerOpen = false);
    }

    // Phase 3: Existing reaction style check
    // If the user has already reacted (any of the reaction counts are > 0), display only the selected one.
    final userReactions = m.reactions.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();
    if (userReactions.isNotEmpty) {
      final selectedEmoji = userReactions.first;
      return Center(
        child: GestureDetector(
          onTap: () => setState(() => _composerOpen = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: (dark ? MemoryColors.ink : Colors.white).withValues(
                alpha: 0.85,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: MemoryColors.accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selectedEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                Text(
                  '${m.reactions[selectedEmoji]}',
                  style: TextStyle(
                    color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        height: 52,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (dark ? MemoryColors.ink : Colors.white).withValues(
            alpha: 0.82,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _emojiButton('❤️', sendQuickReaction),
            _emojiButton('😂', sendQuickReaction),
            _emojiButton('🔥', sendQuickReaction),
            _emojiButton('😭', sendQuickReaction),
            _emojiButton('✨', sendQuickReaction),
            // '+' Emoji action opens native dialog emoji simulation
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                showDialog(
                  context: context,
                  builder: (ctx) => MemoryDialog(
                    title: 'React to ${m.person}',
                    dark: dark,
                    content: Wrap(
                      spacing: MemorySpacing.xl,
                      runSpacing: MemorySpacing.xl,
                      children: ['👍', '🎉', '💡', '😍', '👏', '🤔', '👀', '🥳']
                          .map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                sendQuickReaction(emoji);
                              },
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    actions: const [],
                  ),
                );
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dark ? Colors.white10 : Colors.black12,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiButton(String emoji, Function(String) onTap) => BouncyTap(
    // Punchier pop for the signature reaction tap; keep the medium haptic.
    haptic: false,
    pressedScale: 0.78,
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

  Widget _roundIcon(IconData icon, VoidCallback onTap, {int badgeCount = 0}) =>
      BouncyTap(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _smallClose(VoidCallback onTap, bool dark) => BouncyTap(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: dark ? MemoryColors.ink : MemoryColors.cream,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.close_rounded,
        color: dark ? MemoryColors.cream : MemoryColors.charcoal,
        size: 18,
      ),
    ),
  );
}
