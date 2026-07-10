import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/structured_logger.dart';
import 'media_processor.dart';

class ThumbnailService {
  final MediaProcessor _mediaProcessor;

  ThumbnailService(this._mediaProcessor);

  /// Generates or retrieves a cached thumbnail for the media file.
  Future<File> getThumbnail(String mediaPath) async {
    final file = File(mediaPath);
    if (!await file.exists()) {
      throw FileNotFoundException(
        'Media file not found for thumbnail: $mediaPath',
      );
    }

    final cacheDir = await getTemporaryDirectory();
    final hash = md5.convert(utf8.encode(mediaPath)).toString();
    final thumbnailPath = p.join(cacheDir.path, 'thumb_$hash.png');
    final thumbnailFile = File(thumbnailPath);

    if (await thumbnailFile.exists()) {
      StructuredLogger.log(
        'Returning cached thumbnail for: $mediaPath',
        category: 'ThumbnailService',
      );
      return thumbnailFile;
    }

    StructuredLogger.log(
      'Generating new thumbnail for: $mediaPath',
      category: 'ThumbnailService',
    );
    final metadata = await _mediaProcessor.extractMetadata(mediaPath);

    final bytes = await _generateThumbnailBytes(metadata);
    await thumbnailFile.writeAsBytes(bytes);

    return thumbnailFile;
  }

  Future<List<int>> _generateThumbnailBytes(MediaMetadata metadata) async {
    if (!metadata.isVideo) {
      try {
        final originalBytes = await File(metadata.path).readAsBytes();
        final codec = await ui.instantiateImageCodec(
          originalBytes,
          targetWidth: 200,
        );
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      } catch (e) {
        StructuredLogger.logWarning(
          'Failed to downscale image thumbnail, falling back to original bytes',
          category: 'ThumbnailService',
          error: e,
        );
      }
      return File(metadata.path).readAsBytes();
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 320, 240));

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(320, 240),
        [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 240), paint);

    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(145, 100)
      ..lineTo(185, 120)
      ..lineTo(145, 140)
      ..close();
    canvas.drawPath(path, iconPaint);

    if (metadata.duration != null) {
      final minutes = metadata.duration!.inMinutes.toString().padLeft(2, '0');
      final seconds = (metadata.duration!.inSeconds % 60).toString().padLeft(
        2,
        '0',
      );
      final durationStr = '$minutes:$seconds';

      final textPainter = TextPainter(
        text: TextSpan(
          text: durationStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(260, 205));
    }

    final name = p.basename(metadata.path);
    final namePainter = TextPainter(
      text: TextSpan(
        text: name.length > 25 ? '${name.substring(0, 22)}...' : name,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(canvas, const Offset(10, 215));

    final picture = recorder.endRecording();
    final img = await picture.toImage(320, 240);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (pngBytes == null) {
      throw Exception('Failed to generate thumbnail PNG bytes');
    }
    return pngBytes.buffer.asUint8List();
  }
}

final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  final mediaProcessor = ref.read(mediaProcessorProvider);
  return ThumbnailService(mediaProcessor);
});
