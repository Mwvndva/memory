import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'media_cache_manager.dart';
import 'playback_coordinator.dart';

class UnifiedImageWidget extends ConsumerWidget {
  const UnifiedImageWidget({
    super.key,
    required this.imageUrl,
    this.fallbackWidget,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final String imageUrl;
  final Widget? fallbackWidget;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl.isEmpty) {
      return fallbackWidget ?? const SizedBox.shrink();
    }

    final cacheManager = ref.read(mediaCacheManagerProvider);

    return ClipRRect(
      borderRadius: borderRadius,
      child: FutureBuilder<File?>(
        future: cacheManager.getCachedFile(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final file = snapshot.data;
          if (file == null || !file.existsSync()) {
            if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
              return Image.network(
                imageUrl,
                fit: fit,
                errorBuilder: (context, error, stackTrace) =>
                    fallbackWidget ?? const Icon(Icons.error_outline_rounded),
              );
            }
            return fallbackWidget ?? const Icon(Icons.broken_image_outlined);
          }
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                fallbackWidget ?? const Icon(Icons.error_outline_rounded),
          );
        },
      ),
    );
  }
}

class UnifiedVideoWidget extends ConsumerStatefulWidget {
  const UnifiedVideoWidget({
    super.key,
    required this.videoKey,
    required this.videoUrl,
    required this.fallbackWidget,
    this.autoPlay = false,
  });

  final String videoKey;
  final String videoUrl;
  final Widget fallbackWidget;
  final bool autoPlay;

  @override
  ConsumerState<UnifiedVideoWidget> createState() => _UnifiedVideoWidgetState();
}

class _UnifiedVideoWidgetState extends ConsumerState<UnifiedVideoWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final coordinator = ref.read(playbackCoordinatorProvider);
    final controller = await coordinator.getOrCreateController(widget.videoKey, widget.videoUrl);

    if (mounted && controller != null) {
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      if (widget.autoPlay) {
        coordinator.play(widget.videoKey);
      }
    }
  }

  @override
  void dispose() {
    // Only release focus here, actual controller disposal is managed by PlaybackCoordinator on dispose/shutdown.
    final coordinator = ref.read(playbackCoordinatorProvider);
    coordinator.pause(widget.videoKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return widget.fallbackWidget;
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
