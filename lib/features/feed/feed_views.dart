import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
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
import '../../core/error_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../repositories/circles_repository.dart';
import '../../models/user_profile.dart';
import '../../features/notification/notification_provider.dart';
import '../../media/playback_coordinator.dart';
import '../../media/unified_media_widgets.dart';
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
    return child;
  }

  Widget _tabBar(BuildContext context, String path, bool dark, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final unread = chatState.unreadNotifications;

    return Container(
      height: 58,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: kBlack.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: kBlack.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _tab(
            context,
            path == '/feed',
            '/feed',
            Icons.view_agenda_rounded, // Stacked rectangles
            'Memory',
            dark,
          ),
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
                color: active ? (dark ? kYellow : kBlack) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: icon == Icons.view_agenda_rounded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _rect(active, dark),
                          const SizedBox(height: 3),
                          _rect(active, dark),
                        ],
                      )
                    : Icon(
                        icon,
                        size: 24, // Increased size since label is gone
                        color: active
                            ? (dark ? kBlack : kYellow)
                            : kBlack.withValues(alpha: 0.4),
                      ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 8,
                top: -3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.red,
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

  Widget _rect(bool active, bool dark) {
    return Container(
      width: 22,
      height: 9,
      decoration: BoxDecoration(
        color: active ? (dark ? kBlack : kYellow) : kBlack.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class MemoryFeedView extends ConsumerStatefulWidget {
  const MemoryFeedView({super.key});

  @override
  ConsumerState<MemoryFeedView> createState() => _MemoryFeedViewState();
}

class _MemoryFeedViewState extends ConsumerState<MemoryFeedView> with WidgetsBindingObserver {
  int _activeMemoryIndex = 0;
  bool _composerOpen = false;
  bool _gridOpen = false;
  bool _fromGrid = false;

  VideoPlayerController? _feedVideoController;
  int? _enqueuedIndex;
  bool _isMuted = false;
  bool _feedReady = false; // gates gradient: prevents purple flash before first video init

  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gridScrollController.addListener(_onGridScroll);
    Future.microtask(() {
      if (mounted) {
        ref.read(sessionProvider.notifier).fetchProfile();
        ref.read(feedProvider.notifier).fetchFeed(force: true).catchError((err) {
          if (mounted) {
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
      final bool isStale = lastRefresh == null || 
          DateTime.now().difference(lastRefresh).inSeconds > 300;

      if (isStale) {
        ref.read(feedProvider.notifier).fetchFeed(force: true).catchError((err) {
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
    // Do not call _feedVideoController?.dispose() directly here since
    // PlaybackCoordinator owns the controller and manages its caching and disposal.
    // Pause the active key to stop audio/video resource consumption cleanly on exit.
    if (_enqueuedIndex != null) {
      final key = 'feed_video_$_enqueuedIndex';
      ref.read(playbackCoordinatorProvider).pause(key);
    }
    super.dispose();
  }

  void _nextMemory(int count) {
    if (count == 0) return;
    final isNearEnd = _activeMemoryIndex >= count - 2;
    if (isNearEnd) {
      ref.read(feedProvider.notifier).loadMore();
    }
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

    if (m.videoPath == null || m.videoPath!.isEmpty) {
      // No video — mark ready immediately so the gradient/caption shows
      if (mounted) setState(() { _feedReady = true; });
      return;
    }

    final String path = m.videoPath!;
    final coordinator = ref.read(playbackCoordinatorProvider);

    try {
      final key = 'feed_video_$index';
      final controller = await coordinator.getOrCreateController(key, path);

      if (controller == null) {
        if (mounted) setState(() { _feedReady = true; });
        return;
      }

      if (mounted && _activeMemoryIndex == index) {
        setState(() {
          _feedVideoController = controller;
          _enqueuedIndex = index;
          _feedReady = true;
        });
        coordinator.play(key);
      }
    } catch (e) {
      debugPrint('Error initializing feed video at index $index via PlaybackCoordinator: $e');
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
              color: dark ? kBlack : kYellow,
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
                      isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                      size: 76,
                      color: dark ? kBlack : kCharcoal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isOffline
                          ? 'No internet connection.\nPlease check your network settings.'
                          : 'Unable to load your memories.\nPlease try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? kBlack : kCharcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dark ? kBlack : kCharcoal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      onPressed: () {
                        ref.read(feedProvider.notifier).retryCurrentFailure();
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        color: dark ? kYellow : kBlack,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (dark ? kYellow : kBlack).withValues(alpha: 0.4),
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
                    isOffline ? Icons.wifi_off_rounded : Icons.history_toggle_off_rounded,
                    size: 76,
                    color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOffline
                        ? 'no internet connection\nshowing cached state if available'
                        : 'no memories posted in last 24hrs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
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

    final isUrlCaption = m != null && (m.caption.startsWith('http://') || m.caption.startsWith('https://'));
    final isVideoLoading = m != null && m.videoPath != null && m.videoPath!.isNotEmpty && (_feedVideoController == null || !_feedVideoController!.value.isInitialized);
    final showCaption = m != null && m.caption.isNotEmpty && !isUrlCaption && !isVideoLoading;

    // Trigger video initialization if active index changed
    if (!isEmptyFeed && m != null && activeIndex != _enqueuedIndex) {
      _enqueuedIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initFeedVideo(m, activeIndex);
      });
    }

    // Phase 5: Structured vertical PageView swipe pagination snapping cleanly between memories
    final PageController pageController = PageController(initialPage: activeIndex);

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
                controller: pageController,
                itemCount: listToUse.length,
                onPageChanged: (idx) {
                  // Pause old video controller before switching pages
                  if (_enqueuedIndex != null && _enqueuedIndex != idx) {
                    final oldKey = 'feed_video_$_enqueuedIndex';
                    ref.read(playbackCoordinatorProvider).pause(oldKey);
                  }
                  setState(() {
                    _activeMemoryIndex = idx;
                    _feedReady = false;
                  });
                },
                itemBuilder: (context, index) {
                  final item = listToUse[index];
                  final showCap = item.caption.isNotEmpty &&
                      !(item.caption.startsWith('http://') || item.caption.startsWith('https://')) &&
                      !(item.videoPath != null && item.videoPath!.isNotEmpty && (_feedVideoController == null || !_feedVideoController!.value.isInitialized));
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
                                      color: const Color(0xFFFADA5E).withValues(alpha: 0.14),
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
                  color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            Positioned(
              top: top + 16,
              left: 22,
              child: _roundIcon(
                Icons.arrow_back_ios_new_rounded,
                () {
                  if (_fromGrid && !_gridOpen) {
                    _feedVideoController?.pause();
                    _setGridOpen(true);
                  } else {
                    _feedVideoController?.pause();
                    context.go('/capture');
                  }
                },
              ),
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
                      CircleAvatar(
                        radius: 20,
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
        Container(
          color: Colors.black.withValues(alpha: 0.68),
        ),
        // Vignette overlay
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black87,
              ],
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
    if (m.videoPath != null && m.videoPath!.isNotEmpty && (_feedVideoController == null || !_feedVideoController!.value.isInitialized)) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: dark ? kYellow : kBlack),
        ),
      );
    }
    if (_feedVideoController != null && _feedVideoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _feedVideoController!.value.size.width,
          height: _feedVideoController!.value.size.height,
          child: VideoPlayer(_feedVideoController!),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: m.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _memoryGrid(List<MemoryItem> archived, bool dark) {
    if (archived.isEmpty) {
      return Container(
        color: dark ? kBlack : kYellow,
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

    // Use real archived memories directly
    final gridItems = archived;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) setState(() => _gridOpen = false);
      },
      child: Container(
        color: dark ? kBlack : kYellow,
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
                    _feedVideoController?.pause();
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
                    duration: Duration(milliseconds: 200 + (i * 30)), // Staggered scale-in!
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
                        _setGridOpen(false);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // First-frame thumbnail from video, gradient fallback
                            if (m.videoPath != null && m.videoPath!.isNotEmpty)
                              _VideoGridThumbnail(
                                videoUrl: _formatImageUrl(m.videoPath!),
                                fallbackColors: m.colors,
                              )
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
                            // Avatar badge at bottom-left using stored avatar URL
                            Positioned(
                              left: 7,
                              bottom: 7,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: m.avatar,
                                backgroundImage: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                                    ? NetworkImage(_formatImageUrl(m.avatarUrl!)) as ImageProvider
                                    : null,
                                child: m.avatarUrl == null || m.avatarUrl!.isEmpty
                                    ? Text(
                                        m.initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : null,
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
                      ref.watch(feedProvider).errorCategory == FeedErrorCategory.network
                          ? 'Connection lost. '
                          : 'Load failed. ',
                      style: TextStyle(
                        color: dark ? kCream.withValues(alpha: 0.6) : kCharcoal.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ref.read(feedProvider.notifier).retryCurrentFailure();
                      },
                      child: const Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: kYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
          color: (dark ? kBlack : Colors.white).withValues(alpha: 0.92),
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
              width: 42,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kYellow,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.send_rounded, color: kBlack, size: 18),
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
        if (context.mounted) {
          showAppError(context, 'Failed to post reaction');
        }
      }
      setState(() => _composerOpen = false);
    }

    // Phase 3: Existing reaction style check
    // If the user has already reacted (any of the reaction counts are > 0), display only the selected one.
    final userReactions = m.reactions.entries.where((e) => e.value > 0).map((e) => e.key).toList();
    if (userReactions.isNotEmpty) {
      final selectedEmoji = userReactions.first;
      return Center(
        child: GestureDetector(
          onTap: () => setState(() => _composerOpen = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: (dark ? kBlack : Colors.white).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kYellow.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selectedEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                Text(
                  '${m.reactions[selectedEmoji]}',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
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
          color: (dark ? kBlack : Colors.white).withValues(alpha: 0.82),
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
                  builder: (ctx) => AlertDialog(
                    backgroundColor: dark ? kBlack : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(
                      'React to ${m.person}',
                      style: TextStyle(color: dark ? Colors.white : kCharcoal, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    content: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: ['👍', '🎉', '💡', '😍', '👏', '🤔', '👀', '🥳'].map((emoji) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            sendQuickReaction(emoji);
                          },
                          child: Text(emoji, style: const TextStyle(fontSize: 32)),
                        );
                      }).toList(),
                    ),
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
                child: Icon(Icons.add, color: dark ? kCream : kCharcoal, size: 16),
              ),
            ),
          ],
        ),
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

  Widget _roundIcon(IconData icon, VoidCallback onTap, {int badgeCount = 0}) => GestureDetector(
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

// ── First-frame video thumbnail for the memory grid ──────────────────────────

class _VideoGridThumbnail extends ConsumerWidget {
  const _VideoGridThumbnail({
    required this.videoUrl,
    required this.fallbackColors,
  });

  final String videoUrl;
  final List<Color> fallbackColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallbackColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    return UnifiedVideoWidget(
      videoKey: 'thumb_$videoUrl',
      videoUrl: videoUrl,
      fallbackWidget: fallback,
      autoPlay: false,
    );
  }
}

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
    // Watch only the properties that can change dynamically inside this specific MemoryFrame.
    // By using select, this widget will only rebuild if the matching item isLiked, likeCount,
    // or reactions/bookmark values modify, preventing unrelated card updates.
    final m = ref.watch(feedProvider.select((state) {
      final index = state.memories.indexWhere((item) => item.id == memory.id);
      return index != -1 ? state.memories[index] : memory;
    }));

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
          ],
        ),
      ),
    ),
  );
}
}
