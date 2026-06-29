import 'dart:io';
import 'dart:ui' as ui;
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/structured_logger.dart';

class MediaMetadata {
  final String path;
  final String mimeType;
  final int sizeInBytes;
  final int? width;
  final int? height;
  final Duration? duration;
  final bool isVideo;

  MediaMetadata({
    required this.path,
    required this.mimeType,
    required this.sizeInBytes,
    this.width,
    this.height,
    this.duration,
    required this.isVideo,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'mimeType': mimeType,
      'sizeInBytes': sizeInBytes,
      'width': width,
      'height': height,
      'durationMs': duration?.inMilliseconds,
      'isVideo': isVideo,
    };
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      path: json['path'] as String,
      mimeType: json['mimeType'] as String,
      sizeInBytes: json['sizeInBytes'] as int,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
      isVideo: json['isVideo'] as bool,
    );
  }
}

class MediaProcessor {
  const MediaProcessor();

  Future<MediaMetadata> extractMetadata(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileNotFoundException('File not found at: $path');
    }

    final int sizeInBytes = await file.length();
    final String extension = path.split('.').last.toLowerCase();
    
    final String mimeType = _getMimeType(extension);
    final bool isVideo = mimeType.startsWith('video/');

    int? width;
    int? height;
    Duration? duration;

    try {
      if (isVideo) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        duration = controller.value.duration;
        width = controller.value.size.width.toInt();
        height = controller.value.size.height.toInt();
        await controller.dispose();
      } else if (mimeType.startsWith('image/')) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        width = frameInfo.image.width;
        height = frameInfo.image.height;
        frameInfo.image.dispose();
      }
    } catch (e, st) {
      StructuredLogger.logError('Failed to parse media dimensions/duration for $path', category: 'MediaProcessor', error: e, stackTrace: st);
    }

    return MediaMetadata(
      path: path,
      mimeType: mimeType,
      sizeInBytes: sizeInBytes,
      width: width,
      height: height,
      duration: duration,
      isVideo: isVideo,
    );
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}

final mediaProcessorProvider = Provider<MediaProcessor>((ref) {
  return const MediaProcessor();
});
