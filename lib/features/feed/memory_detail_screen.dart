import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/error_handler.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String memoryId;

  const MemoryDetailScreen({super.key, required this.memoryId});

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCaptionController = TextEditingController();
  final ScrollController _commentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _commentScrollController.addListener(_onCommentsScroll);
  }

  void _onCommentsScroll() {
    if (!_commentScrollController.hasClients) return;
    final maxScroll = _commentScrollController.position.maxScrollExtent;
    final currentScroll = _commentScrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.85) {
      ref.read(memoryDetailProvider(widget.memoryId).notifier).loadComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCaptionController.dispose();
    _commentScrollController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    final dark = ref.read(isDarkProvider);
    MemoryDialog.show(
      context: context,
      builder: (ctx) => MemoryDialog(
        title: 'Delete Memory',
        dark: dark,
        isDestructive: true,
        message:
            'Are you sure you want to permanently delete this memory? This cannot be undone.',
        actions: [
          MemoryDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MemoryDialogAction(
            label: 'Delete',
            isDestructive: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(memoryDetailProvider(widget.memoryId).notifier)
                  .deleteMemory();
              if (success && mounted) {
                context.pop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(memoryDetailProvider(widget.memoryId));
    final dark = ref.watch(isDarkProvider);

    if (detailState.status == MemoryDetailLoadStatus.loading &&
        detailState.memory == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: MemoryLoading.block(),
      );
    }

    if (detailState.status == MemoryDetailLoadStatus.error &&
        detailState.memory == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: MemorySpacing.gutter),
              Text(
                detailState.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MemorySpacing.gutter),
              MemoryButton(
                label: 'Retry',
                dark: true,
                width: 160,
                onPressed: () {
                  ref
                      .read(memoryDetailProvider(widget.memoryId).notifier)
                      .loadMemory();
                },
              ),
            ],
          ),
        ),
      );
    }

    final m = detailState.memory!;

    return Scaffold(
      backgroundColor: dark ? MemoryColors.ink : MemoryColors.accentWarm,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: MemoryIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: 'Back',
          color: dark ? Colors.white : MemoryColors.charcoal,
          onPressed: () => context.pop(),
        ),
        actions: [
          if (m.username == ref.watch(sessionProvider).user.username)
            MemoryIconButton(
              icon: Icons.download_rounded,
              semanticLabel: 'Download video',
              color: dark ? Colors.white : MemoryColors.charcoal,
              onPressed: () async {
                try {
                  final path = await ref
                      .read(downloadRepositoryProvider)
                      .downloadMemoryVideo(m);
                  if (context.mounted) {
                    showAppMessage(
                      context,
                      'Video downloaded successfully to: $path',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppError(context, e.toString());
                  }
                }
              },
            ),
          // Deletion and Editing permissions: only owner can edit/delete
          MemoryIconButton(
            icon: Icons.edit_rounded,
            semanticLabel: 'Edit caption',
            color: dark ? Colors.white : MemoryColors.charcoal,
            onPressed: () {
              ref
                  .read(memoryDetailProvider(widget.memoryId).notifier)
                  .setDraftCaption(m.caption);
              _editCaptionController.text = m.caption;
              // Toggle edit mode via public notifier method
              ref
                  .read(memoryDetailProvider(widget.memoryId).notifier)
                  .setEditing(!detailState.isEditing);
            },
          ),
          MemoryIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: 'Delete memory',
            color: MemoryColors.danger,
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Memory Card View Frame
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MemorySpacing.gutter,
              ),
              child: AspectRatio(
                aspectRatio: 3 / 2.2,
                child: MemoryGradientSurface(
                  colors: m.colors,
                  borderRadius: BorderRadius.circular(MemoryRadius.xxl),
                  shadows: MemoryShadows.raised(dark),
                  child: Stack(
                    children: [
                      if (detailState.isEditing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            padding: const EdgeInsets.all(MemorySpacing.gutter),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextField(
                                  controller: _editCaptionController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Edit caption...',
                                    hintStyle: TextStyle(color: Colors.white38),
                                    border: InputBorder.none,
                                  ),
                                  maxLines: 2,
                                  onChanged: (val) {
                                    ref
                                        .read(
                                          memoryDetailProvider(
                                            widget.memoryId,
                                          ).notifier,
                                        )
                                        .setDraftCaption(val);
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    MemoryButton(
                                      label: 'Cancel',
                                      dark: true,
                                      variant: MemoryButtonVariant.text,
                                      size: MemoryButtonSize.compact,
                                      onPressed: () {
                                        ref
                                            .read(
                                              memoryDetailProvider(
                                                widget.memoryId,
                                              ).notifier,
                                            )
                                            .setEditing(false);
                                      },
                                    ),
                                    const SizedBox(width: MemorySpacing.md),
                                    MemoryButton(
                                      label: 'Save',
                                      dark: true,
                                      width: 96,
                                      size: MemoryButtonSize.compact,
                                      isLoading: detailState.isSavingEdit,
                                      onPressed: () {
                                        ref
                                            .read(
                                              memoryDetailProvider(
                                                widget.memoryId,
                                              ).notifier,
                                            )
                                            .saveCaptionEdit();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Text(
                              m.caption,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        // Quick Reactions panel
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Row(
                            children: ['❤️', '😂', '🔥', '✨'].map((emoji) {
                              final count = m.reactions[emoji] ?? 0;
                              return GestureDetector(
                                onTap: () {
                                  ref
                                      .read(
                                        memoryDetailProvider(
                                          widget.memoryId,
                                        ).notifier,
                                      )
                                      .sendReaction(emoji);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: MemorySpacing.xs,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: MemorySpacing.md,
                                    vertical: MemorySpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    count > 0 ? '$emoji $count' : emoji,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: MemorySpacing.gutter),
            // Comments Section Title
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MemorySpacing.section,
              ),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: dark ? Colors.white : MemoryColors.charcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (detailState.isCommentsLoading)
                    const MemoryLoading(size: 14),
                ],
              ),
            ),
            const SizedBox(height: MemorySpacing.md),
            // List of Comments
            Expanded(
              child: detailState.comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet. Be the first!',
                        style: TextStyle(
                          color: dark
                              ? Colors.white38
                              : MemoryColors.charcoal.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _commentScrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MemorySpacing.gutter,
                      ),
                      itemCount:
                          detailState.comments.length +
                          (detailState.hasMoreComments ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == detailState.comments.length) {
                          return const MemoryLoading.block();
                        }
                        final c = detailState.comments[index];
                        final isOptimistic = c.id.startsWith('local-comment-');
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: MemorySpacing.sm,
                          ),
                          padding: const EdgeInsets.all(MemorySpacing.xl),
                          decoration: BoxDecoration(
                            color: isOptimistic
                                ? Colors.white.withValues(alpha: 0.05)
                                : (dark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.white.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(
                              MemoryRadius.md,
                            ),
                            border: isOptimistic
                                ? Border.all(
                                    color: MemoryColors.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MemoryAvatar(
                                radius: 16,
                                dark: dark,
                                imageUrl:
                                    c.avatarUrl == null || c.avatarUrl!.isEmpty
                                    ? null
                                    : c.avatarUrl,
                                initial: c.person,
                                background: MemoryColors.accent,
                              ),
                              const SizedBox(width: MemorySpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.person,
                                          style: MemoryTypography.bodySmall
                                              .copyWith(
                                                color: dark
                                                    ? Colors.white
                                                    : MemoryColors.charcoal,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: MemorySpacing.sm),
                                        Text(
                                          '@${c.username}',
                                          style: TextStyle(
                                            color: dark
                                                ? Colors.white38
                                                : MemoryColors.charcoal
                                                      .withValues(alpha: 0.5),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: MemorySpacing.xs),
                                    Text(
                                      c.text,
                                      style: TextStyle(
                                        color: dark
                                            ? Colors.white70
                                            : MemoryColors.charcoal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Error Indicator Bar if any error happened
            if (detailState.errorMessage != null)
              Container(
                color: Colors.redAccent,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: MemorySpacing.md,
                  horizontal: MemorySpacing.gutter,
                ),
                child: Text(
                  detailState.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            // Comment input bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MemorySpacing.gutter,
                vertical: MemorySpacing.md,
              ),
              decoration: BoxDecoration(
                color: dark ? MemoryColors.ink : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: dark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(
                        color: dark ? Colors.white : MemoryColors.charcoal,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  MemoryIconButton(
                    icon: Icons.send_rounded,
                    semanticLabel: 'Send comment',
                    color: MemoryColors.accent,
                    onPressed: () {
                      final text = _commentController.text.trim();
                      if (text.isNotEmpty) {
                        ref
                            .read(
                              memoryDetailProvider(widget.memoryId).notifier,
                            )
                            .postComment(text);
                        _commentController.clear();
                      }
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
}
