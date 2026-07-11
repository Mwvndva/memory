import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:memory_app/core/structured_logger.dart';

class CacheCoordinator {
  CacheCoordinator();

  final Map<String, dynamic> _memoryCache = {};

  Future<void> write(String key, dynamic value) async {
    _memoryCache[key] = value;
    try {
      if (Hive.isBoxOpen('feed_cache')) {
        final box = Hive.box('feed_cache');
        await box.put(key, jsonEncode(value));
      }
    } catch (e, st) {
      StructuredLogger.logError(
        'Failed to save to disk cache',
        category: 'CacheCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  dynamic read(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      if (Hive.isBoxOpen('feed_cache')) {
        final box = Hive.box('feed_cache');
        final cachedString = box.get(key) as String?;
        if (cachedString != null) {
          final decoded = jsonDecode(cachedString);
          _memoryCache[key] = decoded;
          return decoded;
        }
      }
    } catch (e, st) {
      StructuredLogger.logError(
        'Failed to read from disk cache',
        category: 'CacheCoordinator',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  void invalidate(String key) {
    _memoryCache.remove(key);
    try {
      if (Hive.isBoxOpen('feed_cache')) {
        final box = Hive.box('feed_cache');
        box.delete(key);
      }
    } catch (e, st) {
      StructuredLogger.logError(
        'Failed to invalidate disk cache key $key',
        category: 'CacheCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  void clearAll() {
    _memoryCache.clear();
    try {
      if (Hive.isBoxOpen('feed_cache')) {
        final box = Hive.box('feed_cache');
        box.clear();
      }
    } catch (e, st) {
      StructuredLogger.logError(
        'Failed to clear disk cache',
        category: 'CacheCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final cacheCoordinatorProvider = Provider<CacheCoordinator>((ref) {
  return CacheCoordinator();
});
