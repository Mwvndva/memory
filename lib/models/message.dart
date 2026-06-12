class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isMine,
  });

  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isMine;

  Message copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? timestamp,
    bool? isMine,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMine: isMine ?? this.isMine,
    );
  }
}
