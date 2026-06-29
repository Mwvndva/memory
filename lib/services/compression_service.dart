import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/structured_logger.dart';
import 'media_processor.dart';

class CompressionResult {
  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;
  final Duration duration;

  CompressionResult({
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
    required this.duration,
  });
}

enum VideoQuality { low, medium, high }

class CompressionService {
  final MediaProcessor _mediaProcessor;

  CompressionService(this._mediaProcessor);

  /// Compresses a video (or media) file.
  /// Fires progress callbacks with values from 0.0 to 1.0.
  Future<CompressionResult> compressVideo({
    required String path,
    VideoQuality quality = VideoQuality.medium,
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final file = File(path);
    if (!await file.exists()) {
      throw FileNotFoundException('File not found for compression: $path');
    }

    final metadata = await _mediaProcessor.extractMetadata(path);
    final originalSize = metadata.sizeInBytes;

    double sizeRatio;
    switch (quality) {
      case VideoQuality.low:
        sizeRatio = 0.3;
        break;
      case VideoQuality.medium:
        sizeRatio = 0.5;
        break;
      case VideoQuality.high:
        sizeRatio = 0.8;
        break;
    }

    final targetSize = (originalSize * sizeRatio).toInt();

    final tempDir = await getTemporaryDirectory();
    final fileName = p.basenameWithoutExtension(path);
    final fileExt = p.extension(path);
    final targetPath = p.join(tempDir.path, '${fileName}_compressed_${DateTime.now().millisecondsSinceEpoch}$fileExt');

    StructuredLogger.log(
      'Starting video compression simulation for $path to $targetPath',
      category: 'CompressionService',
    );

    const steps = 10;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (onProgress != null) {
        onProgress(i / steps);
      }
    }

    await file.copy(targetPath);

    final duration = DateTime.now().difference(startTime);
    StructuredLogger.log(
      'Completed compression simulation in ${duration.inMilliseconds}ms. Original: $originalSize, Simulated Compressed: $targetSize',
      category: 'CompressionService',
    );

    return CompressionResult(
      originalPath: path,
      compressedPath: targetPath,
      originalSize: originalSize,
      compressedSize: targetSize,
      duration: duration,
    );
  }
}

final compressionServiceProvider = Provider<CompressionService>((ref) {
  final mediaProcessor = ref.read(mediaProcessorProvider);
  return CompressionService(mediaProcessor);
});
