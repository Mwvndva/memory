import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'media_cache_manager.dart';

class PlaybackCoordinator {
  PlaybackCoordinator(this._ref);

  final Ref _ref;
  final Map<String, VideoPlayerController> _activeControllers = {};
  final Map<String, Future<VideoPlayerController?>> _pendingControllers = {};
  String? _currentlyPlayingKey;
  bool _isMuted = false;

  /// Bumped by [releaseAll] so a controller that finishes initializing after a
  /// release can tell that nothing owns it any more.
  int _generation = 0;

  bool get isMuted => _isMuted;

  void setMuted(bool mute) {
    _isMuted = mute;
    for (final controller in _activeControllers.values) {
      controller.setVolume(mute ? 0.0 : 1.0);
    }
  }

  Future<VideoPlayerController?> getOrCreateController(String key, String url) {
    final existing = _activeControllers[key];
    if (existing != null) return Future.value(existing);

    // Two callers can ask for the same key while the first is still awaiting
    // initialize(). Share the in-flight future so only one controller is built.
    final inFlight = _pendingControllers[key];
    if (inFlight != null) return inFlight;

    final future = _createController(key, url);
    _pendingControllers[key] = future;
    future.whenComplete(() => _pendingControllers.remove(key));
    return future;
  }

  Future<VideoPlayerController?> _createController(
    String key,
    String url,
  ) async {
    final generation = _generation;
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

      if (generation != _generation) {
        // Released while we were initializing; nothing will ever dispose this.
        await controller.dispose();
        return null;
      }

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

  /// Releases every cached controller whose key satisfies [test].
  ///
  /// Callers must only match keys whose controllers they own — releasing a
  /// controller that a mounted widget still renders will dispose it out from
  /// under that widget.
  void releaseControllersWhere(bool Function(String key) test) {
    final doomed = _activeControllers.keys.where(test).toList(growable: false);
    for (final key in doomed) {
      releaseController(key);
    }
  }

  void releaseAll() {
    _generation++;
    _pendingControllers.clear();
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
