import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/core/theme.dart';
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
        body: Center(child: CircularProgressIndicator(color: kYellow)),
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
              const SizedBox(height: 16),
              Text(
                detailState.errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(memoryDetailProvider(widget.memoryId).notifier)
                      .loadMemory();
                },
                style: ElevatedButton.styleFrom(backgroundColor: kYellow),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final m = detailState.memory!;

    return Scaffold(
      backgroundColor: dark ? kBlack : const Color(0xFFFADA5E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: dark ? Colors.white : kCharcoal,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (m.username == ref.watch(sessionProvider).user.username)
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: dark ? Colors.white : kCharcoal,
              ),
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
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: dark ? Colors.white : kCharcoal,
            ),
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
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Memory Card View Frame
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 3 / 2.2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      colors: m.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (detailState.isEditing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            padding: const EdgeInsets.all(16),
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
                                    TextButton(
                                      onPressed: () {
                                        ref
                                            .read(
                                              memoryDetailProvider(
                                                widget.memoryId,
                                              ).notifier,
                                            )
                                            .setEditing(false);
                                      },
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        ref
                                            .read(
                                              memoryDetailProvider(
                                                widget.memoryId,
                                              ).notifier,
                                            )
                                            .saveCaptionEdit();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kYellow,
                                      ),
                                      child: detailState.isSavingEdit
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : const Text(
                                              'Save',
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
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
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
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
            const SizedBox(height: 16),
            // Comments Section Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: dark ? Colors.white : kCharcoal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (detailState.isCommentsLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kYellow,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List of Comments
            Expanded(
              child: detailState.comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet. Be the first!',
                        style: TextStyle(
                          color: dark
                              ? Colors.white38
                              : kCharcoal.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _commentScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount:
                          detailState.comments.length +
                          (detailState.hasMoreComments ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == detailState.comments.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(color: kYellow),
                            ),
                          );
                        }
                        final c = detailState.comments[index];
                        final isOptimistic = c.id.startsWith('local-comment-');
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOptimistic
                                ? Colors.white.withValues(alpha: 0.05)
                                : (dark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.white.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(16),
                            border: isOptimistic
                                ? Border.all(
                                    color: kYellow.withValues(alpha: 0.3),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.person,
                                          style: TextStyle(
                                            color: dark
                                                ? Colors.white
                                                : kCharcoal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '@${c.username}',
                                          style: TextStyle(
                                            color: dark
                                                ? Colors.white38
                                                : kCharcoal.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.text,
                                      style: TextStyle(
                                        color: dark
                                            ? Colors.white70
                                            : kCharcoal,
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
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Text(
                  detailState.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            // Comment input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? kBlack : Colors.white,
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
                      style: TextStyle(color: dark ? Colors.white : kCharcoal),
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: kYellow),
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
