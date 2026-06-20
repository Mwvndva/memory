import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:dio/dio.dart';

import 'api_config.dart';
import '../models/memory_item.dart';

Future<String> _renderMemoryCard(MemoryItem memory) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, 400, 400));
  
  // Draw gradient background
  final paint = ui.Paint();
  if (memory.colors.length >= 2) {
    paint.shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(400, 400),
      memory.colors,
    );
  } else {
    paint.color = const Color(0xFFF4C430); // fallback yellow (#F4C430)
  }
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, 400, 400), paint);

  // Draw overlay scrim at the bottom
  final scrimPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      const ui.Offset(0, 260),
      const ui.Offset(0, 400),
      [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.85)],
    );
  canvas.drawRect(ui.Rect.fromLTWH(0, 260, 400, 140), scrimPaint);

  // Draw caption text
  if (memory.caption.isNotEmpty) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: memory.caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 4,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: 320);
    // Center the text vertically and horizontally
    final dx = (400 - textPainter.width) / 2;
    final dy = (400 - textPainter.height) / 2;
    textPainter.paint(canvas, ui.Offset(dx, dy));
  }

  // Convert to image
  final picture = recorder.endRecording();
  final img = await picture.toImage(400, 400);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw Exception('Failed to convert canvas to image byte data');
  }
  final bytes = byteData.buffer.asUint8List();

  // Save to file
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/widget_memory_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String?> _downloadAvatar(String? url) async {
  if (url == null || url.isEmpty) return null;
  
  // Format local/mock url
  var targetUrl = url;
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    targetUrl = url.replaceFirst(uri.authority, baseUri.authority);
  }
  
  try {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/widget_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    await Dio().download(targetUrl, path);
    return path;
  } catch (e) {
    debugPrint('Error downloading avatar for widget: $e');
    return null;
  }
}

class WidgetManager {
  static Future<void> syncLatestMemory(List<MemoryItem> memories) async {
    // Register the iOS App Group container identifier
    await HomeWidget.setAppGroupId('group.com.memory.memoryApp');

    if (memories.isEmpty) {
      // Clear data
      await HomeWidget.saveWidgetData('widget_username', 'Memory App');
      await HomeWidget.saveWidgetData('widget_timestamp', 'No memories yet');
      await HomeWidget.saveWidgetData('widget_image', null);
      await HomeWidget.saveWidgetData('widget_avatar', null);
      await HomeWidget.updateWidget(
        name: 'MemoryWidgetProvider',
        androidName: 'MemoryWidgetProvider',
        iOSName: 'MemoryWidget',
      );
      return;
    }

    // Get the first memory in the list (this represents the latest memory in the feed)
    final latestMemory = memories.first;

    try {
      // 1. Render memory card preview image
      final imagePath = await _renderMemoryCard(latestMemory);
      
      // 2. Download avatar if available
      final avatarPath = await _downloadAvatar(latestMemory.avatarUrl);

      // 3. Save key-value pairs in HomeWidget
      await HomeWidget.saveWidgetData('widget_username', latestMemory.person);
      await HomeWidget.saveWidgetData('widget_timestamp', latestMemory.time);
      await HomeWidget.saveWidgetData('widget_image', imagePath);
      await HomeWidget.saveWidgetData('widget_avatar', avatarPath);

      // 4. Trigger Widget Update
      await HomeWidget.updateWidget(
        name: 'MemoryWidgetProvider',
        androidName: 'MemoryWidgetProvider',
        iOSName: 'MemoryWidget',
      );
    } catch (e) {
      debugPrint('Error syncing memory to home widget: $e');
    }
  }
}
