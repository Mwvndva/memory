import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/theme.dart';
import '../models/memory_item.dart';
import 'auth_repository.dart';

class MemoryNotifier extends StateNotifier<List<MemoryItem>> {
  MemoryNotifier(this._ref) : super(kUseMockBackend ? _defaultMemories : const []) {
    if (!kUseMockBackend) {
      fetchFeed();
    }
  }

  final Ref _ref;

  static final _defaultMemories = [
    const MemoryItem(
      person: 'Amara',
      initial: 'A',
      time: '8 min ago',
      caption: 'The ridiculous cake moment',
      avatar: kCoral,
      colors: [Color(0xFFFF826E), kAmber, kMint],
      ageHours: .13,
    ),
    const MemoryItem(
      person: 'Mum',
      initial: 'M',
      time: 'Yesterday',
      caption: 'Found your old school song',
      avatar: kMint,
      colors: [kMint, kSky, Color(0xFFFFF0B8)],
      ageHours: 26,
    ),
    const MemoryItem(
      person: 'Leo',
      initial: 'L',
      time: 'Friday',
      caption: 'Rainy walk after class',
      avatar: kSky,
      colors: [kSky, kLavender, Color(0xFFFFB23E)],
      ageHours: 72,
    ),
    const MemoryItem(
      person: 'Nia',
      initial: 'N',
      time: '2 days ago',
      caption: 'Sunset on the way home',
      avatar: kLavender,
      colors: [kLavender, kCoral, kAmber],
      ageHours: 48,
    ),
  ];

  Future<void> fetchFeed() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get('/memories/feed');

      // Backend returns: { "memories": [...], "meta": {...} }
      final rawList = (response.data['memories'] as List? ?? []);

      final list = rawList.map((item) {
        // gradient_colors is a list of hex strings like "#FF6B57"
        final List<Color> colors = (item['gradient_colors'] as List? ?? []).map((colorStr) {
          final clean = (colorStr as String).replaceFirst('#', '');
          final hexInt = int.tryParse(clean, radix: 16) ?? 0xFFFF6B57;
          return Color(0xFF000000 | hexInt);
        }).toList();

        // avatar is a single deterministic hex string from the backend
        final avatarStr = (item['avatar'] as String? ?? '').replaceFirst('#', '');
        final avatarHex = int.tryParse(avatarStr, radix: 16) ?? 0xFFFF6B57;
        final avatarColor = Color(0xFF000000 | avatarHex);

        return MemoryItem(
          person:    item['person']    as String? ?? '',
          initial:   item['initial']   as String? ?? '',
          time:      item['time']      as String? ?? '',
          caption:   item['caption']   as String? ?? '',
          avatar:    avatarColor,
          colors:    colors.isEmpty ? [avatarColor] : colors,
          ageHours:  (item['age_hours'] as num?)?.toDouble() ?? 0.0,
          videoPath: item['video_url'] as String?,
        );
      }).toList();

      state = list;
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
        initial: initial,
        time: 'Just now',
        caption: caption,
        avatar: kCoral,
        colors: colors,
        ageHours: 0.01,
        videoPath: videoPath,
      );

      state = [newItem, ...state];
    } else {
      try {
        final dio = _ref.read(apiClientProvider);
        final List<String> colorsHex = colors.map((c) {
          return '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
        }).toList();

        final formData = FormData.fromMap({
          'caption': caption,
          'colors': colorsHex,
          if (videoPath != null && videoPath.isNotEmpty)
            'video': await MultipartFile.fromFile(videoPath, filename: 'captured_memory.mp4'),
        });

        await dio.post('/memories/upload', data: formData);
        
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
  return list.where((m) => m.ageHours < 24).toList();
});

final archivedMemoriesProvider = Provider<List<MemoryItem>>((ref) {
  final list = ref.watch(memoryProvider);
  return list.where((m) => m.ageHours >= 24).toList();
});
