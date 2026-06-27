class CommentItem {
  final String id;
  final String memoryId;
  final String person;
  final String username;
  final String text;
  final DateTime timestamp;
  final String? avatarUrl;

  const CommentItem({
    required this.id,
    required this.memoryId,
    required this.person,
    required this.username,
    required this.text,
    required this.timestamp,
    this.avatarUrl,
  });

  CommentItem copyWith({
    String? id,
    String? memoryId,
    String? person,
    String? username,
    String? text,
    DateTime? timestamp,
    String? avatarUrl,
  }) {
    return CommentItem(
      id: id ?? this.id,
      memoryId: memoryId ?? this.memoryId,
      person: person ?? this.person,
      username: username ?? this.username,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
