import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AttachmentService {
  Future<String?> uploadAttachment(String filePath);
}

abstract class VoiceMessageService {
  Future<void> startRecording();
  Future<String?> stopRecording();
  Future<void> playVoiceMessage(String messageId, String url);
}

abstract class MessageQueue {
  void enqueueMessage(String contactName, String text);
  Future<void> processQueue();
}

class AttachmentServiceImpl implements AttachmentService {
  final Ref _ref;
  AttachmentServiceImpl(this._ref);

  @override
  Future<String?> uploadAttachment(String filePath) async {
    // Stub implementation or mock upload
    await Future.delayed(const Duration(milliseconds: 500));
    return 'https://example.com/attachments/${Uri.parse(filePath).pathSegments.last}';
  }
}

class VoiceMessageServiceImpl implements VoiceMessageService {
  final Ref _ref;
  VoiceMessageServiceImpl(this._ref);

  @override
  Future<void> startRecording() async {
    // Stub recording start
  }

  @override
  Future<String?> stopRecording() async {
    // Stub recording stop
    await Future.delayed(const Duration(milliseconds: 500));
    return 'voice-memo.m4a';
  }

  @override
  Future<void> playVoiceMessage(String messageId, String url) async {
    // Stub playback
  }
}

class MessageQueueImpl implements MessageQueue {
  final Ref _ref;
  final List<Map<String, String>> _queue = [];

  MessageQueueImpl(this._ref);

  @override
  void enqueueMessage(String contactName, String text) {
    _queue.add({'contactName': contactName, 'text': text});
  }

  @override
  Future<void> processQueue() async {
    if (_queue.isEmpty) return;
    final items = List<Map<String, String>>.from(_queue);
    _queue.clear();
    for (final item in items) {
      try {
        // Will transmit using the main repository / notifier
      } catch (_) {
        // Re-enqueue on failure
        _queue.add(item);
      }
    }
  }
}

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentServiceImpl(ref);
});

final voiceMessageServiceProvider = Provider<VoiceMessageService>((ref) {
  return VoiceMessageServiceImpl(ref);
});

final messageQueueProvider = Provider<MessageQueue>((ref) {
  return MessageQueueImpl(ref);
});
