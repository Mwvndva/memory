import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/notification/widgets/notification_card.dart';
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
    final bg = dark ? MemoryColors.ink : MemoryColors.cream;

    return Scaffold(
      backgroundColor: bg,
      appBar: MemoryAppBar(
        title: 'Notifications',
        dark: dark,
        foreground: dark ? MemoryColors.accent : MemoryColors.ink,
        leading: MemoryIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: 'Back',
          color: dark ? MemoryColors.accent : MemoryColors.ink,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            MemoryButton(
              label: 'Read All',
              dark: dark,
              variant: MemoryButtonVariant.text,
              size: MemoryButtonSize.compact,
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? MemoryLoading.block(color: dark ? null : MemoryColors.ink)
          : state.notifications.isEmpty
          ? _buildEmptyState(dark)
          : _buildList(state.notifications, dark),
    );
  }

  Widget _buildEmptyState(bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MemorySpacing.section),
        child: MemoryEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'All caught up!',
          message: 'New reactions, messages and circle requests land here.',
          dark: dark,
        ),
      ),
    );
  }

  Widget _buildList(List<NotificationItem> items, bool dark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: MemorySpacing.gutter,
        vertical: MemorySpacing.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildRow(item, dark);
      },
    );
  }

  Widget _buildRow(NotificationItem item, bool dark) {
    return NotificationCard(
      item: item,
      dark: dark,
      onTap: () {
        ref.read(notificationProvider.notifier).markAsRead(item.id);
        NotificationRouter.routeToDestination(context, item);
      },
    );
  }
}
