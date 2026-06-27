import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'media_cache_manager.dart';

class PlaybackCoordinator {
  PlaybackCoordinator(this._ref);

  final Ref _ref;
  final Map<String, VideoPlayerController> _activeControllers = {};
  String? _currentlyPlayingKey;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  void setMuted(bool mute) {
    _isMuted = mute;
    for (final controller in _activeControllers.values) {
      controller.setVolume(mute ? 0.0 : 1.0);
    }
  }

  Future<VideoPlayerController?> getOrCreateController(String key, String url) async {
    if (_activeControllers.containsKey(key)) {
      return _activeControllers[key];
    }

    try {
      final cacheManager = _ref.read(mediaCacheManagerProvider);
      final cachedFile = await cacheManager.getCachedFile(url);

      VideoPlayerController controller;
      if (cachedFile != null) {
        controller = VideoPlayerController.file(cachedFile);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        final localFile = File(url);
        if (!await localFile.exists()) return null;
        controller = VideoPlayerController.file(localFile);
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      _activeControllers[key] = controller;
      return controller;
    } catch (e) {
      debugPrint('PlaybackCoordinator failed to init controller: $e');
      return null;
    }
  }

  void play(String key) {
    if (_currentlyPlayingKey != null && _currentlyPlayingKey != key) {
      pause(_currentlyPlayingKey!);
    }

    _currentlyPlayingKey = key;
    final controller = _activeControllers[key];
    if (controller != null && !controller.value.isPlaying) {
      controller.play();
    }
  }

  void pause(String key) {
    final controller = _activeControllers[key];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
    if (_currentlyPlayingKey == key) {
      _currentlyPlayingKey = null;
    }
  }

  void releaseController(String key) {
    final controller = _activeControllers.remove(key);
    if (controller != null) {
      controller.pause();
      controller.dispose();
    }
    if (_currentlyPlayingKey == key) {
      _currentlyPlayingKey = null;
    }
  }

  void releaseAll() {
    for (final controller in _activeControllers.values) {
      controller.pause();
      controller.dispose();
    }
    _activeControllers.clear();
    _currentlyPlayingKey = null;
  }
}

final playbackCoordinatorProvider = Provider<PlaybackCoordinator>((ref) {
  final coordinator = PlaybackCoordinator(ref);
  ref.onDispose(() => coordinator.releaseAll());
  return coordinator;
});
