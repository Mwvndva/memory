import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/notification/notification.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(notificationProvider.notifier).loadInitial();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.9) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? kDarkCream : kCream;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: dark ? kYellow : kBlack,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: dark ? kYellow : kBlack,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              child: Text(
                'Read All',
                style: TextStyle(
                  color: dark ? kYellow : kBlack,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : state.notifications.isEmpty
          ? _buildEmptyState(dark)
          : _buildList(state.notifications, dark),
    );
  }

  Widget _buildEmptyState(bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: (dark ? kYellow : kBlack).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(
              color: (dark ? kYellow : kBlack).withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<NotificationItem> items, bool dark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildRow(item, dark);
      },
    );
  }

  Widget _buildRow(NotificationItem item, bool dark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isRead
            ? Colors.transparent
            : (dark ? kBlack.withValues(alpha: 0.4) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (dark ? kYellow : kBlack).withValues(
            alpha: item.isRead ? 0.05 : 0.15,
          ),
          width: 1.5,
        ),
        boxShadow: item.isRead
            ? []
            : [
                BoxShadow(
                  color: kBlack.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(notificationProvider.notifier).markAsRead(item.id);
            NotificationRouter.routeToDestination(context, item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildTypeBadge(item.type, dark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: dark ? kYellow : kBlack,
                          fontWeight: item.isRead
                              ? FontWeight.w700
                              : FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        style: TextStyle(
                          color: (dark ? kYellow : kBlack).withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(NotificationType type, bool dark) {
    IconData icon;
    Color color;
    switch (type) {
      case NotificationType.message:
        icon = Icons.chat_bubble_outline_rounded;
        color = kYellow;
      case NotificationType.reaction:
        icon = Icons.favorite_outline_rounded;
        color = Colors.redAccent;
      case NotificationType.memory:
        icon = Icons.camera_alt_outlined;
        color = Colors.lightBlueAccent;
      case NotificationType.circleRequest:
        icon = Icons.group_add_outlined;
        color = Colors.tealAccent;
      case NotificationType.circleMilestone:
        icon = Icons.celebration_outlined;
        color = Colors.orangeAccent;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: dark ? kBlack : color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: dark
              ? kYellow.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: dark
            ? kYellow
            : (dark ? Colors.white : color.withValues(alpha: 0.95)),
        size: 18,
      ),
    );
  }
}
