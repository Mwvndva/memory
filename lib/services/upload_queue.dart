import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart'; // contains sharedPreferencesProvider
import '../core/structured_logger.dart';
import 'compression_service.dart';
import 'media_processor.dart';
import 'storage_service.dart';

enum UploadStatus { queued, compressing, uploading, paused, completed, failed }

class UploadItem {
  final String id;
  final String filePath;
  final UploadStatus status;
  final double progress;
  final String? error;
  final String? resultUrl;
  final int retries;
  final DateTime createdAt;

  UploadItem({
    required this.id,
    required this.filePath,
    required this.status,
    required this.progress,
    this.error,
    this.resultUrl,
    required this.retries,
    required this.createdAt,
  });

  UploadItem copyWith({
    String? id,
    String? filePath,
    UploadStatus? status,
    double? progress,
    String? error,
    String? resultUrl,
    int? retries,
    DateTime? createdAt,
  }) {
    return UploadItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      resultUrl: resultUrl ?? this.resultUrl,
      retries: retries ?? this.retries,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'status': status.name,
      'progress': progress,
      'error': error,
      'resultUrl': resultUrl,
      'retries': retries,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UploadItem.fromJson(Map<String, dynamic> json) {
    return UploadItem(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      status: UploadStatus.values.byName(json['status'] as String),
      progress: (json['progress'] as num).toDouble(),
      error: json['error'] as String?,
      resultUrl: json['resultUrl'] as String?,
      retries: json['retries'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class UploadQueueNotifier extends StateNotifier<List<UploadItem>> {
  final SharedPreferences prefs;
  final CompressionService compressionService;
  final StorageService storageService;
  final MediaProcessor mediaProcessor;

  static const String _storageKey = 'upload_queue_items';
  static const int _maxRetries = 3;

  final Map<String, CancelToken> _cancelTokens = {};
  bool _isProcessing = false;

  UploadQueueNotifier({
    required this.prefs,
    required this.compressionService,
    required this.storageService,
    required this.mediaProcessor,
  })  : super([]) {
    _loadQueue();
  }

  void _loadQueue() {
    try {
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null) {
        final List<dynamic> list = json.decode(dataStr);
        state = list.map((item) => UploadItem.fromJson(item as Map<String, dynamic>)).toList();
        
        // Reset any actively uploading/compressing states back to queued on load
        bool modified = false;
        state = state.map((item) {
          if (item.status == UploadStatus.uploading || item.status == UploadStatus.compressing) {
            modified = true;
            return item.copyWith(status: UploadStatus.queued, progress: 0.0);
          }
          return item;
        }).toList();

        if (modified) {
          _saveQueue();
        }

        // Start processing automatically
        _processNext();
      }
    } catch (e, st) {
      StructuredLogger.logError('Failed to load upload queue', category: 'UploadQueue', error: e, stackTrace: st);
    }
  }

  void _saveQueue() {
    try {
      final list = state.map((item) => item.toJson()).toList();
      prefs.setString(_storageKey, json.encode(list));
    } catch (e, st) {
      StructuredLogger.logError('Failed to save upload queue', category: 'UploadQueue', error: e, stackTrace: st);
    }
  }

  /// Adds a new file path to the upload queue.
  void queueUpload(String filePath) {
    final newItem = UploadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: filePath,
      status: UploadStatus.queued,
      progress: 0.0,
      retries: 0,
      createdAt: DateTime.now(),
    );

    state = [...state, newItem];
    _saveQueue();
    _processNext();
  }

  /// Cancels an ongoing upload or removes it from the queue.
  void cancelUpload(String id) {
    _cancelTokens[id]?.cancel('Cancelled by user');
    _cancelTokens.remove(id);

    state = state.where((item) => item.id != id).toList();
    _saveQueue();
  }

  /// Retries a failed or paused upload.
  void retryUpload(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(status: UploadStatus.queued, error: null, progress: 0.0);
      }
      return item;
    }).toList();
    _saveQueue();
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (true) {
        // Find next eligible item
        final index = state.indexWhere((item) => item.status == UploadStatus.queued);
        if (index == -1) break;

        final item = state[index];
        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(UploadItem item) async {
    String currentPath = item.filePath;
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    try {
      // 1. Identify file metadata
      final metadata = await mediaProcessor.extractMetadata(currentPath);

      // 2. Compress if it's a video
      if (metadata.isVideo) {
        state = state.map((i) => i.id == item.id ? i.copyWith(status: UploadStatus.compressing, progress: 0.0) : i).toList();
        _saveQueue();

        final compressResult = await compressionService.compressVideo(
          path: currentPath,
          onProgress: (progress) {
            state = state.map((i) => i.id == item.id ? i.copyWith(progress: progress * 0.3) : i).toList();
          },
        );
        currentPath = compressResult.compressedPath;
      }

      if (cancelToken.isCancelled) return;

      // 3. Upload the file
      state = state.map((i) => i.id == item.id ? i.copyWith(status: UploadStatus.uploading, progress: 0.3) : i).toList();
      _saveQueue();

      final url = await storageService.uploadFile(
        filePath: currentPath,
        uploadId: item.id,
        cancelToken: cancelToken,
        onProgress: (prog) {
          // Map upload progress from 30% to 100% of the total process bar
          final overallProgress = 0.3 + (prog.fraction * 0.7);
          state = state.map((i) => i.id == item.id ? i.copyWith(progress: overallProgress) : i).toList();
        },
      );

      // Clean up compressed temp file if it was created
      if (currentPath != item.filePath) {
        try {
          final tempFile = File(currentPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          StructuredLogger.logWarning('Failed to delete temp compressed file', category: 'UploadQueue', error: e);
        }
      }

      state = state.map((i) => i.id == item.id ? i.copyWith(status: UploadStatus.completed, progress: 1.0, resultUrl: url) : i).toList();
      _saveQueue();
    } catch (e, st) {
      if (cancelToken.isCancelled) {
        StructuredLogger.log('Upload ${item.id} cancelled.', category: 'UploadQueue');
        return;
      }

      StructuredLogger.logError('Failed processing upload item ${item.id}', category: 'UploadQueue', error: e, stackTrace: st);

      final nextRetries = item.retries + 1;
      final nextStatus = nextRetries < _maxRetries ? UploadStatus.queued : UploadStatus.failed;

      state = state.map((i) => i.id == item.id ? i.copyWith(
        status: nextStatus,
        retries: nextRetries,
        error: e.toString(),
        progress: 0.0,
      ) : i).toList();
      
      _saveQueue();

      // If it failed and is queued again, backoff slightly before next run
      if (nextStatus == UploadStatus.queued) {
        await Future.delayed(Duration(seconds: nextRetries * 2));
      }
    } finally {
      _cancelTokens.remove(item.id);
    }
  }
}

final uploadQueueProvider = StateNotifierProvider<UploadQueueNotifier, List<UploadItem>>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final compression = ref.read(compressionServiceProvider);
  final storage = ref.read(storageServiceProvider);
  final media = ref.read(mediaProcessorProvider);

  return UploadQueueNotifier(
    prefs: prefs,
    compressionService: compression,
    storageService: storage,
    mediaProcessor: media,
  );
});
