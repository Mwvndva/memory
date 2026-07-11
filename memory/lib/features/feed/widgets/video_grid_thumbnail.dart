import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/media/unified_media_widgets.dart';

class VideoGridThumbnail extends ConsumerWidget {
  const VideoGridThumbnail({
    super.key,
    required this.videoUrl,
    required this.fallbackColors,
  });

  final String videoUrl;
  final List<Color> fallbackColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedVideoWidget(
      videoKey: 'thumb_$videoUrl',
      videoUrl: videoUrl,
      fallbackWidget: MemoryGradientSurface(colors: fallbackColors),
      autoPlay: false,
    );
  }
}
