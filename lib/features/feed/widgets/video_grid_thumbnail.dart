import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallbackColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    return UnifiedVideoWidget(
      videoKey: 'thumb_$videoUrl',
      videoUrl: videoUrl,
      fallbackWidget: fallback,
      autoPlay: false,
    );
  }
}
