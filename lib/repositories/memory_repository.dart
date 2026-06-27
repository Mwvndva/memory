import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/theme.dart';
import '../models/memory_item.dart';
import '../core/widget_manager.dart';
import 'auth_repository.dart';

Color parseHexColor(String hexStr) {
  var clean = hexStr.replaceAll('#', '').trim();
  if (clean.length == 6) {
    clean = 'FF$clean';
  } else if (clean.length == 8) {
    clean = 'FF${clean.substring(clean.length - 6)}';
  } else {
    return const Color(0xFFFADA5E);
  }
  return Color(int.tryParse(clean, radix: 16) ?? 0xFFFADA5E);
}

class MemoryNotifier extends StateNotifier<List<MemoryItem>> {
  MemoryNotifier(this._ref) : super(kUseMockBackend ? _defaultMemories : const []) {
    if (!kUseMockBackend) {
      _loadCachedFeed();
      fetchFeed();
    } else {
      // Sync mock memories on startup in mock mode
      Future.microtask(() {
        final feedItems = _defaultMemories.where((m) => m.ageHours < 24).toList();
        WidgetManager.syncLatestMemory(feedItems);
      });
    }
  }

  void _loadCachedFeed() {
    try {
      final box = Hive.box('feed_cache');
      final cachedJson = box.get('feed') as String?;
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(cachedJson);
        final list = _parseJsonFeed(rawList);
        state = list;
      }
    } catch (_) {
      // Ignore cache loading errors
    }
  }

  List<MemoryItem> _parseJsonFeed(List<dynamic> rawList) {
    return rawList.map((item) {
      final List<Color> colors = (item['gradient_colors'] as List? ?? []).map((colorStr) {
        return parseHexColor(colorStr as String);
      }).toList();

      final avatarStr = item['avatar'] as String? ?? '';
      final avatarColor = parseHexColor(avatarStr);

      final creatorObj = item['creator'] as Map<String, dynamic>?;
      final avatarUrl = creatorObj?['avatar_url'] as String?;

      return MemoryItem(
        person:    item['person']    as String? ?? '',
        username:  creatorObj?['username'] as String? ?? '',
        initial:   item['initial']   as String? ?? '',
        time:      item['time']      as String? ?? '',
        caption:   item['caption']   as String? ?? '',
        avatar:    avatarColor,
        colors:    colors.isEmpty ? [avatarColor] : colors,
        ageHours:  (item['age_hours'] as num?)?.toDouble() ?? 0.0,
        videoPath: item['video_url'] as String?,
        avatarUrl: avatarUrl,
      );
    }).toList();
  }

  final Ref _ref;

  static final _defaultMemories = [
    const MemoryItem(
      person: 'Amara',
      username: 'amara',
      initial: 'A',
      time: '8 min ago',
      caption: 'The ridiculous cake moment',
      avatar: kYellow,
      colors: [Color(0xFFFF826E), kAmber, kMint],
      ageHours: .13,
    ),
    const MemoryItem(
      person: 'Mum',
      username: 'mum',
      initial: 'M',
      time: 'Yesterday',
      caption: 'Found your old school song',
      avatar: kMint,
      colors: [kMint, kSky, Color(0xFFFADA5E)],
      ageHours: 26,
    ),
    const MemoryItem(
      person: 'Leo',
      username: 'leo',
      initial: 'L',
      time: 'Friday',
      caption: 'Rainy walk after class',
      avatar: kSky,
      colors: [kSky, kLavender, Color(0xFFFADA5E)],
      ageHours: 72,
    ),
    const MemoryItem(
      person: 'Nia',
      username: 'nia',
      initial: 'N',
      time: '2 days ago',
      caption: 'Sunset on the way home',
      avatar: kLavender,
      colors: [kLavender, kYellow, kAmber],
      ageHours: 48,
    ),
  ];

  Future<void> fetchFeed() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/memories/feed?limit=100');

      // Backend returns: { "memories": [...], "meta": {...} }
      final rawList = (response.data['memories'] as List? ?? []);

      final list = _parseJsonFeed(rawList);

      state = list;
      final feedItems = list.where((m) => m.ageHours < 24).toList();
      WidgetManager.syncLatestMemory(feedItems);

      // Save to Hive cache
      try {
        final box = Hive.box('feed_cache');
        box.put('feed', jsonEncode(rawList));
      } catch (_) {
        // Ignore cache saving errors
      }
    } catch (_) {
      // Keep existing state (fallback or empty) on error
    }
  }

  Future<void> addMemory(String caption, List<Color> colors, {String? videoPath}) async {
    final user = _ref.read(authProvider);
    final name = user.firstName.isNotEmpty ? user.firstName : 'You';
    final initial = name.isNotEmpty ? name[0] : 'Y';

    if (kUseMockBackend) {
      final newItem = MemoryItem(
        person: name,
        username: user.username,
        initial: initial,
        time: 'Just now',
        caption: caption,
        avatar: kYellow,
        colors: colors,
        ageHours: 0.01,
        videoPath: videoPath,
      );

      state = [newItem, ...state];
      final feedItems = state.where((m) => m.ageHours < 24).toList();
      WidgetManager.syncLatestMemory(feedItems);
      // Increment local streakDays to easily test milestones in mock mode
      final currentStreak = _ref.read(authProvider).streakDays;
      _ref.read(authProvider.notifier).state = _ref.read(authProvider).copyWith(
        streakDays: currentStreak + 1,
      );
    } else {
      try {
        // Pre-validate video size client-side (max 50MB)
        if (videoPath != null && videoPath.isNotEmpty) {
          final file = File(videoPath);
          if (await file.exists()) {
            final size = await file.length();
            const maxSizeBytes = 50 * 1024 * 1024; // 50MB
            if (size > maxSizeBytes) {
              throw Exception('Video file size exceeds the 50MB limit.');
            }
          }
        }

        final dio = _ref.read(apiClientProvider);
        final List<String> colorsHex = colors.map((c) {
          return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        }).toList();

        final formData = FormData.fromMap({
          'caption': caption,
          'colors': colorsHex,
          if (videoPath != null && videoPath.isNotEmpty)
            'video': await MultipartFile.fromFile(videoPath, filename: 'captured_memory.mp4'),
        });

        await dio.post('/memories/upload', data: formData);
        
        // Fetch updated profile stats to update user streakDays
        await _ref.read(authProvider.notifier).fetchProfile();

        // Re-fetch clean list from backend to keep local UI exactly in sync
        await fetchFeed();
      } catch (_) {
        rethrow;
      }
    }
  }
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, List<MemoryItem>>((ref) {
  return MemoryNotifier(ref);
});

final feedMemoriesProvider = Provider<List<MemoryItem>>((ref) {
  final list = ref.watch(memoryProvider);
  final filtered = list.where((m) => m.ageHours < 24).toList();
  filtered.sort((a, b) => a.ageHours.compareTo(b.ageHours));
  return filtered;
});

final archivedMemoriesProvider = Provider<List<MemoryItem>>((ref) {
  final list = ref.watch(memoryProvider);
  return list.where((m) => m.ageHours >= 24).toList();
});
