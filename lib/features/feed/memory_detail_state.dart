import 'package:memory_app/features/feed/feed.dart';

enum MemoryDetailLoadStatus {
  idle,
  loading,
  loaded,
  error,
}

class MemoryDetailState {
  final MemoryItem? memory;
  final List<CommentItem> comments;
  final MemoryDetailLoadStatus status;
  final bool isCommentsLoading;
  final bool hasMoreComments;
  final String? commentCursor;
  final String? errorMessage;
  final bool isPostingComment;
  final bool isEditing;
  final bool isSavingEdit;
  final bool isDeleting;
  final String? draftCaption;

  MemoryDetailState({
    this.memory,
    this.comments = const [],
    this.status = MemoryDetailLoadStatus.idle,
    this.isCommentsLoading = false,
    this.hasMoreComments = true,
    this.commentCursor,
    this.errorMessage,
    this.isPostingComment = false,
    this.isEditing = false,
    this.isSavingEdit = false,
    this.isDeleting = false,
    this.draftCaption,
  });

  MemoryDetailState copyWith({
    MemoryItem? memory,
    List<CommentItem>? comments,
    MemoryDetailLoadStatus? status,
    bool? isCommentsLoading,
    bool? hasMoreComments,
    Object? commentCursor = _kUnset,
    Object? errorMessage = _kUnset,
    bool? isPostingComment,
    bool? isEditing,
    bool? isSavingEdit,
    bool? isDeleting,
    Object? draftCaption = _kUnset,
  }) {
    return MemoryDetailState(
      memory: memory ?? this.memory,
      comments: comments ?? this.comments,
      status: status ?? this.status,
      isCommentsLoading: isCommentsLoading ?? this.isCommentsLoading,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      commentCursor: commentCursor == _kUnset ? this.commentCursor : commentCursor as String?,
      errorMessage: errorMessage == _kUnset ? this.errorMessage : errorMessage as String?,
      isPostingComment: isPostingComment ?? this.isPostingComment,
      isEditing: isEditing ?? this.isEditing,
      isSavingEdit: isSavingEdit ?? this.isSavingEdit,
      isDeleting: isDeleting ?? this.isDeleting,
      draftCaption: draftCaption == _kUnset ? this.draftCaption : draftCaption as String?,
    );
  }
}

const Object _kUnset = Object();
