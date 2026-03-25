import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import 'instagram_service.dart';

class DownloadService {
  static Future<DownloadItem> downloadReel(DownloadItem item) async {
    try {
      final info = await InstagramService.getVideoInfo(item.url);
      final videoUrl = info['videoUrl'];

      if (videoUrl == null || videoUrl.isEmpty) {
        return item.copyWith(
          status: DownloadStatus.failed,
          error: 'Could not extract video URL. The post may be private.',
          thumbnailUrl: info['thumbnailUrl'],
          caption: info['caption'],
        );
      }

      final response = await http.get(
        Uri.parse(videoUrl),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return item.copyWith(
          status: DownloadStatus.failed,
          error: 'Download failed (HTTP ${response.statusCode})',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'instagrab_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Save to gallery using Gal
      await Gal.putVideo(tempFile.path, album: 'InstaGrab');

      final savedPath = tempFile.path;

      try {
        await tempFile.delete();
      } catch (_) {}

      return item.copyWith(
        status: DownloadStatus.completed,
        videoUrl: videoUrl,
        filePath: savedPath,
        thumbnailUrl: info['thumbnailUrl'],
        caption: info['caption'],
      );
    } catch (e) {
      return item.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
    }
  }
}
