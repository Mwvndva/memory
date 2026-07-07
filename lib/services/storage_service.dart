import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/structured_logger.dart';

class UploadProgress {
  final int bytesSent;
  final int totalBytes;
  final double fraction;

  UploadProgress({
    required this.bytesSent,
    required this.totalBytes,
    required this.fraction,
  });
}

class StorageService {
  final Dio _dio;

  StorageService(this._dio);

  /// Performs a chunked/multipart upload of the file at [filePath] to [uploadUrl] or via the central API client.
  /// If [uploadId] is provided, it can be used for resuming or tracking the session.
  Future<String> uploadFile({
    required String filePath,
    required String uploadId,
    String? uploadUrl,
    void Function(UploadProgress progress)? onProgress,
    CancelToken? cancelToken,
    int chunkSize = 1024 * 1024, // 1MB chunks
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Upload target file does not exist: $filePath');
    }

    final totalBytes = await file.length();
    final randomAccessFile = await file.open(mode: FileMode.read);

    try {
      int bytesSent = 0;
      int chunkIndex = 0;
      final totalChunks = (totalBytes / chunkSize).ceil();

      StructuredLogger.log(
        'Starting chunked upload of $filePath ($totalBytes bytes) in $totalChunks chunks.',
        category: 'StorageService',
      );

      while (bytesSent < totalBytes) {
        if (cancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: uploadUrl ?? '/upload/chunk'),
            type: DioExceptionType.cancel,
            message: 'Upload cancelled by user',
          );
        }

        final remaining = totalBytes - bytesSent;
        final currentChunkSize = remaining < chunkSize ? remaining : chunkSize;

        await randomAccessFile.setPosition(bytesSent);
        final List<int> chunkBytes = await randomAccessFile.read(currentChunkSize);

        final response = await _dio.post(
          uploadUrl ?? '/upload/chunk',
          data: Stream.fromIterable([chunkBytes]),
          options: Options(
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Range': 'bytes $bytesSent-${bytesSent + currentChunkSize - 1}/$totalBytes',
              'X-Upload-ID': uploadId,
              'X-Chunk-Index': chunkIndex.toString(),
              'X-Total-Chunks': totalChunks.toString(),
            },
          ),
          cancelToken: cancelToken,
        );

        if (response.statusCode == null || response.statusCode! >= 300) {
          throw Exception('Failed to upload chunk $chunkIndex. Status: ${response.statusCode}');
        }

        bytesSent += currentChunkSize;
        chunkIndex++;

        if (onProgress != null) {
          onProgress(UploadProgress(
            bytesSent: bytesSent,
            totalBytes: totalBytes,
            fraction: bytesSent / totalBytes,
          ));
        }
      }

      final completionResponse = await _dio.post(
        '/upload/complete',
        data: {
          'uploadId': uploadId,
          'totalChunks': totalChunks,
          'fileName': file.path.split(Platform.pathSeparator).last,
        },
        cancelToken: cancelToken,
      );

      if (completionResponse.statusCode == null || completionResponse.statusCode! >= 300) {
        throw Exception('Failed to finalize chunked upload. Status: ${completionResponse.statusCode}');
      }

      final fileUrl = completionResponse.data['fileUrl'] as String? ?? 'https://example.com/uploads/$uploadId';
      
      StructuredLogger.log(
        'Successfully completed chunked upload for $uploadId. URL: $fileUrl',
        category: 'StorageService',
      );

      return fileUrl;
    } finally {
      await randomAccessFile.close();
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  final dio = ref.read(apiClientProvider);
  return StorageService(dio);
});
