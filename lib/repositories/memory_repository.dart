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
import '../core/error_handler.dart';

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
        await box.put('feed', jsonEncode(rawList));
      } catch (e) {
        debugPrint('Failed to save feed cache: $e');
      }
    } catch (e, stack) {
      final mapped = mapException(e, stack);
      throw mapped;
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
      _ref.read(sessionProvider.notifier).updateProfile(
        _ref.read(authProvider).copyWith(streakDays: currentStreak + 1),
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
              throw ValidationException('Video file size exceeds the 50MB limit.', null, StackTrace.current);
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
        await _ref.read(sessionProvider.notifier).fetchProfile();

        // Re-fetch clean list from backend to keep local UI exactly in sync
        await fetchFeed();
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        throw mapped;
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

enum UploadStatus {
  idle,
  preparing,
  validating,
  uploading,
  waitingForResponse,
  succeeded,
  failed,
  cancelled,
}

class UploadState {
  final UploadStatus status;
  final double progress;
  final String? errorMessage;

  UploadState({
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
  });

  factory UploadState.idle() => UploadState(status: UploadStatus.idle);

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier(this._ref) : super(UploadState.idle());

  final Ref _ref;
  CancelToken? _cancelToken;

  void cancelUpload() {
    if (state.status == UploadStatus.uploading || 
        state.status == UploadStatus.preparing || 
        state.status == UploadStatus.validating) {
      _cancelToken?.cancel('User cancelled the upload');
      state = state.copyWith(status: UploadStatus.cancelled);
    }
  }

  void reset() {
    state = UploadState.idle();
  }

  Future<void> uploadMemory(
    String caption,
    List<Color> colors, {
    String? videoPath,
  }) async {
    if (state.status == UploadStatus.preparing ||
        state.status == UploadStatus.validating ||
        state.status == UploadStatus.uploading ||
        state.status == UploadStatus.waitingForResponse) {
      return;
    }

    _cancelToken = CancelToken();

    state = state.copyWith(status: UploadStatus.preparing, progress: 0.0, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 100));

    state = state.copyWith(status: UploadStatus.validating);
    try {
      if (videoPath != null && videoPath.isNotEmpty) {
        final file = File(videoPath);
        if (!await file.exists()) {
          throw ValidationException('Recorded video file does not exist on disk.', null, StackTrace.current);
        }
        final size = await file.length();
        const maxSizeBytes = 50 * 1024 * 1024;
        if (size > maxSizeBytes) {
          throw ValidationException('Video file size exceeds the 50MB limit.', null, StackTrace.current);
        }
      }
    } catch (e) {
      state = state.copyWith(status: UploadStatus.failed, errorMessage: e.toString());
      return;
    }

    state = state.copyWith(status: UploadStatus.uploading);

    if (kUseMockBackend) {
      try {
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          if (_cancelToken?.isCancelled == true) return;
          state = state.copyWith(progress: i / 10);
        }
        state = state.copyWith(status: UploadStatus.waitingForResponse);
        await Future.delayed(const Duration(milliseconds: 200));

        final user = _ref.read(authProvider);
        final name = user.firstName.isNotEmpty ? user.firstName : 'You';
        final initial = name.isNotEmpty ? name[0] : 'Y';
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
          avatarUrl: user.avatarUrl,
        );

        _ref.read(memoryProvider.notifier).state = [newItem, ..._ref.read(memoryProvider.notifier).state];
        final feedItems = _ref.read(memoryProvider.notifier).state.where((m) => m.ageHours < 24).toList();
        WidgetManager.syncLatestMemory(feedItems);

        final currentStreak = _ref.read(authProvider).streakDays;
        _ref.read(sessionProvider.notifier).updateProfile(
          _ref.read(authProvider).copyWith(streakDays: currentStreak + 1),
        );

        state = state.copyWith(status: UploadStatus.succeeded);
      } catch (e) {
        state = state.copyWith(status: UploadStatus.failed, errorMessage: e.toString());
      }
    } else {
      try {
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

        await dio.post(
          '/memories/upload',
          data: formData,
          cancelToken: _cancelToken,
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              if (progress >= 1.0) {
                state = state.copyWith(
                  status: UploadStatus.waitingForResponse,
                  progress: 1.0,
                );
              } else {
                if (progress - state.progress > 0.02) {
                  state = state.copyWith(
                    status: UploadStatus.uploading,
                    progress: progress,
                  );
                }
              }
            }
          },
        );

        state = state.copyWith(status: UploadStatus.waitingForResponse);

        await _ref.read(sessionProvider.notifier).fetchProfile();
        await _ref.read(memoryProvider.notifier).fetchFeed();

        state = state.copyWith(status: UploadStatus.succeeded);
      } on DioException catch (e, stack) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        final mapped = mapException(e, stack);
        state = state.copyWith(status: UploadStatus.failed, errorMessage: mapped.message);
      } catch (e, stack) {
        final mapped = mapException(e, stack);
        state = state.copyWith(status: UploadStatus.failed, errorMessage: mapped.message);
      }
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});
