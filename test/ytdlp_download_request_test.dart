import 'package:flutter_test/flutter_test.dart';
import 'package:vidbee_flutter/core/models/download_task.dart';
import 'package:vidbee_flutter/core/models/video_info.dart';
import 'package:vidbee_flutter/core/services/ytdlp_service.dart';

void main() {
  group('YtDlpService.createDownloadRequest', () {
    test('视频任务禁用嵌入缩略图并强制 mp4 合并以防止画面拉伸变扁', () {
      final task = const DownloadTask(
        id: 'task_video_1',
        url: 'https://www.bilibili.com/video/BV1xx411c7mD',
        title: '测试视频',
        type: DownloadType.video,
        status: DownloadStatus.pending,
        createdAt: 1000,
      );

      final request = YtDlpService.createDownloadRequest(
        task: task,
        downloadUrl: task.url,
        downloadPath: '/storage/emulated/0/Download',
        outputTemplate: 'VidBee_%(title)s.%(ext)s',
        configuredAudioQuality: 3,
        customOptions: {'--referer': 'https://www.bilibili.com'},
      );

      // 核心防拉伸断言：视频必须为 false，绝不能在 MP4 中生成 attached_pic 视频流
      expect(request.embedThumbnail, isFalse);
      expect(request.embedMetadata, isTrue);
      expect(request.extractAudio, isFalse);
      expect(request.audioFormat, isNull);
      expect(request.audioQuality, isNull);
      expect(request.format, 'bestvideo+bestaudio/best');
      expect(request.customOptions?['--merge-output-format'], 'mp4');
      expect(request.customOptions?['--referer'], 'https://www.bilibili.com');
    });

    test('指定清晰度的视频任务保持防拉伸配置并正确合并音频流', () {
      final task = const DownloadTask(
        id: 'task_video_2',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'YouTube Clip',
        type: DownloadType.video,
        status: DownloadStatus.pending,
        selectedFormat: VideoFormat(
          formatId: '137',
          ext: 'mp4',
          height: 1080,
        ),
        createdAt: 2000,
      );

      final request = YtDlpService.createDownloadRequest(
        task: task,
        downloadUrl: task.url,
        downloadPath: '/storage/emulated/0/Download',
        outputTemplate: 'VidBee_%(title)s.%(ext)s',
        configuredAudioQuality: 3,
      );

      expect(request.embedThumbnail, isFalse);
      expect(request.format, '137+bestaudio/best');
      expect(request.customOptions?['--merge-output-format'], 'mp4');
    });

    test('纯音频任务保持开启嵌入封面与提取配置', () {
      final task = const DownloadTask(
        id: 'task_audio_1',
        url: 'https://www.bilibili.com/video/BV1xx411c7mD',
        title: '测试音频',
        type: DownloadType.audio,
        status: DownloadStatus.pending,
        createdAt: 3000,
      );

      final request = YtDlpService.createDownloadRequest(
        task: task,
        downloadUrl: task.url,
        downloadPath: '/storage/emulated/0/Download',
        outputTemplate: 'VidBee_%(title)s.%(ext)s',
        configuredAudioQuality: 2,
      );

      // 音频需要封面
      expect(request.embedThumbnail, isTrue);
      expect(request.extractAudio, isTrue);
      expect(request.audioFormat, 'mp3');
      expect(request.audioQuality, 2);
      expect(request.format, 'bestaudio/best');
      expect(request.customOptions?['--merge-output-format'], isNull);
    });
  });
}
