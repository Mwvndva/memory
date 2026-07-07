import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memory_item.dart';
import 'auth_repository.dart';

class DownloadRepository {
  final Ref _ref;
  DownloadRepository(this._ref);

  Future<String?> downloadMemoryVideo(MemoryItem memory) async {
    final session = _ref.read(sessionProvider);
    final currentUser = session.user;
    if (memory.username != currentUser.username) {
      throw Exception("You can only download your own memories.");
    }

    final videoUrl = memory.videoPath;
    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception("This memory does not have a video to download.");
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = 'memory_video_${memory.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(videoUrl, savePath);
      
      return savePath;
    } catch (e) {
      throw Exception("Failed to download video: $e");
    }
  }
}

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref);
});
