import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class CacheCoordinator {
  CacheCoordinator(this._ref);

  final Ref _ref;
  final Map<String, dynamic> _memoryCache = {};

  Future<void> write(String key, dynamic value) async {
    _memoryCache[key] = value;
    try {
      final box = Hive.box('feed_cache');
      await box.put(key, jsonEncode(value));
    } catch (e) {
      debugPrint('Failed to save to disk cache: $e');
    }
  }

  dynamic read(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final box = Hive.box('feed_cache');
      final cachedString = box.get(key) as String?;
      if (cachedString != null) {
        final decoded = jsonDecode(cachedString);
        _memoryCache[key] = decoded;
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  void invalidate(String key) {
    _memoryCache.remove(key);
    try {
      final box = Hive.box('feed_cache');
      box.delete(key);
    } catch (_) {}
  }

  void clearAll() {
    _memoryCache.clear();
    try {
      final box = Hive.box('feed_cache');
      box.clear();
    } catch (_) {}
  }
}

final cacheCoordinatorProvider = Provider<CacheCoordinator>((ref) {
  return CacheCoordinator(ref);
});
