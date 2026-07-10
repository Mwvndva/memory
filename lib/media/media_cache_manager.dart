import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memory_app/core/api_client.dart';

class MediaCacheManager {
  MediaCacheManager(this._ref);

  final Ref _ref;
  final Map<String, File> _memoryCache = {};

  Future<File?> getCachedFile(String url) async {
    if (url.isEmpty) return null;

    // Check memory cache first
    if (_memoryCache.containsKey(url)) {
      final file = _memoryCache[url]!;
      if (await file.exists()) {
        return file;
      }
    }

    try {
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'cached_media_${url.hashCode}';

      // Target directory
      final cacheDir = await getTemporaryDirectory();
      final targetFile = File('${cacheDir.path}/$filename');

      // Return local cache if it exists on disk
      if (await targetFile.exists()) {
        _memoryCache[url] = targetFile;
        return targetFile;
      }

      // Download from backend/CDN otherwise
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final dio = _ref.read(apiClientProvider);
        await dio.download(url, targetFile.path);
        _memoryCache[url] = targetFile;
        return targetFile;
      }

      // Fallback: If it's already a local file path
      final localFile = File(url);
      if (await localFile.exists()) {
        return localFile;
      }
    } catch (e) {
      debugPrint('Error loading cached media file: $e');
    }

    return null;
  }

  Future<void> prefetch(List<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty) continue;
      // Fetch in background asynchronously
      unawaited(getCachedFile(url));
    }
  }

  void clearCache() {
    _memoryCache.clear();
  }
}

final mediaCacheManagerProvider = Provider<MediaCacheManager>((ref) {
  return MediaCacheManager(ref);
});
