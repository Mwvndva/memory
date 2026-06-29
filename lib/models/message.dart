import 'message_status.dart';

class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isMine,
    this.isRead = true,
    this.isPending = false,
    this.isFailed = false,
    this.attachmentUrl,
    this.attachmentLocalPath,
    this.uploadProgress,
    this.status,
  });

  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isMine;
  final bool isRead;
  final bool isPending;
  final bool isFailed;
  final String? attachmentUrl;
  final String? attachmentLocalPath;
  final double? uploadProgress;
  final MessageStatus? status;

  MessageStatus get messageStatus {
    if (status != null) return status!;
    if (isFailed) return MessageStatus.draft;
    if (isPending) return MessageStatus.sending;
    if (isRead) return MessageStatus.read;
    return MessageStatus.sent;
  }

  Message copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? timestamp,
    bool? isMine,
    bool? isRead,
    bool? isPending,
    bool? isFailed,
    String? attachmentUrl,
    String? attachmentLocalPath,
    double? uploadProgress,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMine: isMine ?? this.isMine,
      isRead: isRead ?? this.isRead,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentLocalPath: attachmentLocalPath ?? this.attachmentLocalPath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      status: status ?? this.status,
    );
  }
}

