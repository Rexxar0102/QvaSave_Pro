// yt-dlp 服务封装
// 基于 extractor 插件实现的视频下载引擎

import 'dart:async';
import 'dart:io';
import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_info.dart' as qvasave;
import '../models/download_task.dart' as qvasave;
import '../utils/app_logger.dart';
import '../utils/download_filename.dart';
import '../utils/event_bus.dart';
import '../utils/media_scanner.dart';
import '../utils/permission_helper.dart';
import 'cookie_service.dart';

class YtDlpUpdateResult {
  const YtDlpUpdateResult({required this.success, this.version, this.message});

  final bool success;
  final String? version;
  final String? message;
}

/// yt-dlp 服务类
class YtDlpService {
  static final YtDlpService _instance = YtDlpService._internal();
  factory YtDlpService() => _instance;
  YtDlpService._internal();

  /// Bilibili 等站点强制使用的桌面端 UA，避免 yt-dlp 重定向到移动端导致解析失败
  static const String _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const String _prefLastYtDlpUpdateCheck = 'last_ytdlp_update_check';
  static const String _bundledYtDlpVersion = '2026.07.04';
  static const Duration _ytDlpUpdateCheckInterval = Duration(hours: 24);

  /// yt-dlp 自动更新的最大重试次数与每次重试间隔。
  static const int _ytDlpUpdateMaxRetries = 3;
  static const Duration _ytDlpUpdateRetryDelay = Duration(seconds: 2);

  /// 默认音频质量（0=最佳，9=最差），与设置页默认值保持一致。
  static const int _defaultAudioQuality = 3;

  final YoutubeDLFlutter _youtubeDL = YoutubeDLFlutter.instance;
  bool _isInitialized = false;
  Future<bool>? _initializeFuture;
  Future<YtDlpUpdateResult>? _updateFuture;
  final Map<String, StreamSubscription> _subscriptions = {};

  /// 初始化服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    final currentInitialization = _initializeFuture;
    if (currentInitialization != null) return currentInitialization;

    _initializeFuture = _initialize().whenComplete(() {
      _initializeFuture = null;
    });
    return _initializeFuture!;
  }

  Future<bool> _initialize() async {
    try {
      final result = await _youtubeDL.initialize(
        enableFFmpeg: true,
        enableAria2c: true,
      );

      if (result.success) {
        _isInitialized = true;
        _setupEventListeners();

        // 后台限频检查更新，避免启动和首次解析被网络更新阻塞。
        unawaited(_ensureYtDlpUpdatedIfNeeded());

        return true;
      } else {
        AppLogger.error(
          'YtDlpService initialization failed',
          result.errorMessage,
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('YtDlpService initialization exception', e);
      return false;
    }
  }

  /// 限频后台检查 yt-dlp 更新。
  Future<void> _ensureYtDlpUpdatedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastChecked = prefs.getInt(_prefLastYtDlpUpdateCheck) ?? 0;
    if (now - lastChecked < _ytDlpUpdateCheckInterval.inMilliseconds) {
      return;
    }

    final versionInfo = await getVersionInfo();
    final currentVersion = versionInfo['yt-dlp'] ?? '';
    if (_isYtDlpVersionAtLeast(currentVersion, _bundledYtDlpVersion)) {
      await prefs.setInt(_prefLastYtDlpUpdateCheck, now);
      AppLogger.debug(
        'Current yt-dlp is already the bundled new version $currentVersion, skipping auto-update',
      );
      return;
    }

    await prefs.setInt(_prefLastYtDlpUpdateCheck, now);
    final currentUpdate = _updateFuture;
    if (currentUpdate != null) {
      await currentUpdate;
      return;
    }
    _updateFuture = _updateYtDlpWithRetry().whenComplete(() {
      _updateFuture = null;
    });
    await _updateFuture;
  }

  /// 确保 yt-dlp 更新到最新版本（带重试机制）
  Future<YtDlpUpdateResult> _updateYtDlpWithRetry() async {
    YtDlpUpdateResult lastResult = const YtDlpUpdateResult(
      success: false,
      message: 'Update failed',
    );
    for (int i = 0; i < _ytDlpUpdateMaxRetries; i++) {
      AppLogger.debug(
        'Auto-updating yt-dlp (attempt ${i + 1}/$_ytDlpUpdateMaxRetries)...',
      );
      lastResult = await _updateYtDlpOnce();
      if (lastResult.success) return lastResult;
      AppLogger.error('yt-dlp update failed', lastResult.message);
      // 等待后重试
      await Future.delayed(_ytDlpUpdateRetryDelay);
    }
    AppLogger.error('yt-dlp auto-update failed, will use the bundled version');
    return lastResult;
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    // 进度更新
    _subscriptions['progress'] = _youtubeDL.onProgress.listen((progress) {
      final event = DownloadProgressEvent(
        taskId: progress.processId,
        progress: progress.progress.toDouble(),
        eta: progress.eta.inSeconds,
      );
      eventBus.fire(event);
    });

    // 状态变化
    _subscriptions['state'] = _youtubeDL.onStateChanged.listen((state) {
      qvasave.DownloadStatus status;
      if (state.state == DownloadStateType.started) {
        status = qvasave.DownloadStatus.downloading;
      } else if (state.state == DownloadStateType.completed) {
        status = qvasave.DownloadStatus.completed;
      } else if (state.state == DownloadStateType.cancelled) {
        status = qvasave.DownloadStatus.cancelled;
      } else {
        status = qvasave.DownloadStatus.pending;
      }
      final event = DownloadStatusChangedEvent(
        taskId: state.processId,
        status: status,
      );
      eventBus.fire(event);
    });

    // 错误事件
    _subscriptions['error'] = _youtubeDL.onError.listen((error) {
      final event = DownloadErrorEvent(
        taskId: error.processId,
        error: error.error,
      );
      eventBus.fire(event);
    });
  }

  /// 构建 yt-dlp 请求选项（解析与下载共用）。
  ///
  /// 返回标准化后的 URL 及对应的命令行选项：
  /// - Bilibili 强制桌面端域名与 UA，并附加 Referer
  /// - 应用自定义 UA（若提供且有效）
  /// - 按域名查找并附加 Cookie 文件
  /// - 抖音/TikTok 启用浏览器指纹模拟
  Future<({String url, Map<String, String> options})> _buildRequestOptions(
    String url,
    String? customUA,
  ) async {
    final cookieService = CookieService();
    final options = <String, String>{};
    var effectiveUrl = url;
    var effectiveUA = customUA ?? '';

    final originalDomain = cookieService.extractDomain(effectiveUrl);
    final isBilibili = cookieService.isBilibiliDomain(originalDomain);
    if (isBilibili) {
      effectiveUrl = effectiveUrl.replaceFirst(
        'm.bilibili.com',
        'www.bilibili.com',
      );
      // Bilibili 必须使用桌面端 UA，否则 yt-dlp 会重定向到移动端导致解析失败
      if (!_isDesktopUA(effectiveUA)) {
        effectiveUA = _desktopUA;
        AppLogger.debug('Bilibili forced to use desktop UA');
      } else {
        AppLogger.debug('Bilibili using user-provided desktop UA');
      }
    }

    if (effectiveUA.isNotEmpty) {
      options['--user-agent'] = effectiveUA;
      if (!isBilibili) AppLogger.debug('Using custom UA');
    }

    // 按站点查找 Cookie 文件（Google 系等多域名站点会自动合并相关域名，
    // 避免按域名拆分导致登录态不完整，例如 YouTube 的 CookieMismatch）
    final cookieFilePath = await cookieService.getCookieFileForUrl(
      effectiveUrl,
    );
    if (cookieFilePath != null && cookieFilePath.isNotEmpty) {
      final cookieFile = File(cookieFilePath);
      if (await cookieFile.exists() && await cookieFile.length() > 0) {
        options['--cookies'] = cookieFilePath;
        AppLogger.debug('Using cookie file: $cookieFilePath');
      }
    }

    if (isBilibili) {
      options['--referer'] = 'https://www.bilibili.com';
    }

    if (effectiveUrl.contains('douyin.com') ||
        effectiveUrl.contains('tiktok.com')) {
      options['--extractor-args'] = 'generic:impersonate=chrome';
    }

    return (url: effectiveUrl, options: options);
  }

  /// 获取视频信息
  Future<qvasave.VideoInfo?> getVideoInfo(
    String url, {
    String? customUA,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      final request = await _buildRequestOptions(url, customUA);
      final effectiveUrl = request.url;
      final options = request.options;

      final domain = CookieService().extractDomain(effectiveUrl);

      // 使用 getVideoInfoWithOptions 传递自定义选项
      VideoInfo info;
      AppLogger.info(
        'Preparing to parse video: domain=$domain, url=$effectiveUrl',
      );
      if (options.isNotEmpty) {
        AppLogger.debug('Parse options set: ${options.keys.join(', ')}');
        info = await _youtubeDL.getVideoInfoWithOptions(effectiveUrl, options);
      } else {
        info = await _youtubeDL.getVideoInfo(effectiveUrl);
      }

      final converted = _convertToQvaSaveVideoInfo(info);
      AppLogger.info(
        'Video parsed successfully: domain=$domain, formats=${converted.formats.length}, '
        'title=${converted.title}',
      );
      return converted;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get video info: url=$url', e, stackTrace);
      return null;
    }
  }

  /// 开始下载
  Future<String?> startDownload(
    qvasave.DownloadTask task, {
    String? customUA,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      // 优先使用任务中的下载路径，如果没有则使用默认路径
      String downloadPath = task.downloadPath ?? '';

      if (downloadPath.isEmpty) {
        // 直接使用系统 Downloads 目录，这样其他应用也能看到。
        downloadPath = await PermissionHelper.getDefaultDownloadPath();
      }

      if (!await PermissionHelper.isDirectoryWritable(downloadPath)) {
        AppLogger.error(
          'Download directory not writable, trying fallback directory',
          downloadPath,
        );
        try {
          final appDir = await getExternalStorageDirectory();
          if (appDir == null) return null;

          downloadPath = '${appDir.path}/Download/QvaSave';
          if (!await PermissionHelper.isDirectoryWritable(downloadPath)) {
            AppLogger.error(
              'Fallback download directory not writable',
              downloadPath,
            );
            return null;
          }
          AppLogger.debug('Using fallback download directory: $downloadPath');
        } catch (e) {
          AppLogger.error('Failed to create fallback directory', e);
          return null;
        }
      }

      AppLogger.debug('Starting download: ${task.url}');
      AppLogger.debug('Download path: $downloadPath');

      final prefs = await SharedPreferences.getInstance();
      final configuredAudioQuality =
          int.tryParse(
            prefs.getString('default_audio_quality') ?? '$_defaultAudioQuality',
          ) ??
          _defaultAudioQuality;

      // 使用QvaSave_前缀 + 视频标题作为文件名，既保留标题又避免问题
      final outputTemplate = 'QvaSave_%(title)s.%(ext)s';
      AppLogger.debug('Output filename: $outputTemplate');

      // 构建请求选项（与解析共用逻辑：Bilibili/UA/Cookie/Referer 等）
      final built = await _buildRequestOptions(task.url, customUA);
      final downloadUrl = built.url;
      final customOptions = built.options;

      final request = createDownloadRequest(
        task: task,
        downloadUrl: downloadUrl,
        downloadPath: downloadPath,
        outputTemplate: outputTemplate,
        configuredAudioQuality: configuredAudioQuality,
        customOptions: customOptions,
      );

      AppLogger.debug(
        'Download format: ${request.format}, embed thumbnail: ${request.embedThumbnail}',
      );

      final result = await _youtubeDL.download(request);

      if (result.status == OperationStatus.success) {
        // 优先采用插件返回的真实输出路径；若其为空或仍是模板，则在下载目录中
        // 按 QvaSave_<标题> 安全化匹配。
        // 切勿把含 %(title)s 的模板路径写回任务/历史。
        final actualPath = await _resolveOutputPath(
          result.outputPath,
          downloadPath,
          task.title,
        );
        if (actualPath == null) {
          AppLogger.error(
            'Download succeeded but failed to resolve the actual file path: '
            'pluginOutput=${result.outputPath}, title=${task.title}, '
            'dir=$downloadPath',
          );
          // 默认允许并发下载，不能用目录中“最新文件”兜底：它可能属于
          // 另一个任务，进而把错误文件写入当前任务历史并误报成功。
          return null;
        }
        AppLogger.debug('Download succeeded: $actualPath');

        // 通知系统媒体库扫描新文件（相册可见的关键步骤）
        await MediaScanner.scanFile(actualPath);

        return actualPath;
      } else {
        AppLogger.error('Download failed', result.errorMessage);
        return null;
      }
    } catch (e) {
      AppLogger.error('Download exception', e);
      return null;
    }
  }

  /// 构建 yt-dlp [DownloadRequest]。
  ///
  /// 修复视频在 QQ 频道等平台播放时拉伸变扁的关键设计：
  /// 1. [embedThumbnail] 仅对纯音频下载启用；视频下载严禁嵌入缩略图。
  ///    若视频启用 --embed-thumbnail，ffmpeg 会将缩略图作为包含封面图像的
  ///    attached_pic 视频流封装进 MP4。当视频为竖屏(如 9:16)而封面为横屏(如 16:9)时，
  ///    QQ 频道等富媒体解析器会误读封面流的 16:9 分辨率作为消息卡片尺寸，
  ///    导致播放器在横屏卡片中播放竖屏视频，画面被强行拉伸变扁。
  /// 2. 视频下载时向 customOptions 注入 `--merge-output-format mp4`，
  ///    避免 yt-dlp 默认将分离流合并为 mkv 导致容器元数据与比例解析异常。
  @visibleForTesting
  static DownloadRequest createDownloadRequest({
    required qvasave.DownloadTask task,
    required String downloadUrl,
    required String downloadPath,
    required String outputTemplate,
    required int configuredAudioQuality,
    Map<String, String>? customOptions,
  }) {
    final isAudio = task.type == qvasave.DownloadType.audio;
    final effectiveOptions = <String, String>{...?customOptions};

    // 确定下载格式
    String format;
    if (isAudio) {
      format = 'bestaudio/best';
    } else if (task.selectedFormat != null) {
      format = '${task.selectedFormat!.formatId}+bestaudio/best';
    } else {
      format = 'bestvideo+bestaudio/best';
    }

    if (!isAudio) {
      effectiveOptions['--merge-output-format'] = 'mp4';
    }

    return DownloadRequest(
      url: downloadUrl,
      outputPath: downloadPath,
      outputTemplate: outputTemplate,
      format: format,
      processId: task.id,
      embedThumbnail: isAudio,
      embedMetadata: true,
      extractAudio: isAudio,
      audioFormat: isAudio ? 'mp3' : null,
      audioQuality: isAudio ? configuredAudioQuality : null,
      customOptions: effectiveOptions.isEmpty ? null : effectiveOptions,
    );
  }

  /// 解析下载产物的真实路径。
  ///
  /// 优先级：插件返回的真实路径 > 按标题安全化匹配 > null。
  /// 不再使用"目录中最新文件"的启发式，避免多任务并发写入同一目录时张冠李戴。
  /// 也绝不返回含 `%(...)` 的未展开模板。
  Future<String?> _resolveOutputPath(
    String? pluginOutputPath,
    String downloadPath,
    String? title,
  ) async {
    // 1. 插件已返回真实存在的文件路径（且不是未展开的模板）
    if (pluginOutputPath != null &&
        pluginOutputPath.isNotEmpty &&
        !isYtDlpTemplatePath(pluginOutputPath)) {
      final pluginFile = File(pluginOutputPath);
      if (await pluginFile.exists()) {
        return pluginOutputPath;
      }
      // 有时插件只回文件名，拼到下载目录再试
      final joined = '$downloadPath/${fileNameFromPath(pluginOutputPath)}';
      if (joined != pluginOutputPath && await File(joined).exists()) {
        return joined;
      }
    }

    // 2. 按 QvaSave_<标题> 在下载目录中安全化匹配
    return _findDownloadedFileByTitle(downloadPath, title);
  }

  /// 在下载目录中按 QvaSave_<标题> 查找已完成文件（安全化比对）。
  Future<String?> _findDownloadedFileByTitle(
    String downloadPath,
    String? title,
  ) async {
    try {
      final dir = Directory(downloadPath);
      if (!await dir.exists()) return null;

      final candidatePaths = <String>[];
      final modifiedMsByPath = <String, int>{};
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.part') || entity.path.endsWith('.ytdl')) {
          continue;
        }
        candidatePaths.add(entity.path);
        final stat = await entity.stat();
        modifiedMsByPath[entity.path] = stat.modified.millisecondsSinceEpoch;
      }

      final matched = matchDownloadedFileByTitle(
        candidatePaths: candidatePaths,
        title: title,
        modifiedMsByPath: modifiedMsByPath,
        allowNewestFallback: false,
      );
      if (matched == null) {
        AppLogger.debug(
          'No downloaded file matched by title: dir=$downloadPath, title=$title, '
          'candidates=${candidatePaths.length}',
        );
      }
      return matched;
    } catch (e) {
      AppLogger.error('Failed to find downloaded file', e);
      return null;
    }
  }

  /// 取消下载
  Future<bool> cancelDownload(String taskId) async {
    try {
      final cancelled = await _youtubeDL.cancelDownload(taskId);
      return cancelled;
    } catch (e) {
      AppLogger.error('Failed to cancel download', e);
      return false;
    }
  }

  /// 更新 yt-dlp
  Future<YtDlpUpdateResult> updateYtDlp() async {
    final initialized = await initialize();
    if (!initialized) {
      return const YtDlpUpdateResult(
        success: false,
        message: 'yt-dlp initialization failed',
      );
    }
    final currentUpdate = _updateFuture;
    if (currentUpdate != null) return currentUpdate;

    _updateFuture = _updateYtDlpOnce().whenComplete(() {
      _updateFuture = null;
    });
    return _updateFuture!;
  }

  Future<YtDlpUpdateResult> _updateYtDlpOnce() async {
    try {
      final result = await _youtubeDL.updateYoutubeDL(
        channel: UpdateChannel.stable,
      );
      final success = result.status == OperationStatus.success;
      if (success) {
        AppLogger.debug('yt-dlp updated successfully: ${result.version}');
      } else {
        AppLogger.error('yt-dlp update failed', result.errorMessage);
      }
      return YtDlpUpdateResult(
        success: success,
        version: result.version,
        message: result.errorMessage,
      );
    } catch (e) {
      AppLogger.error('Failed to update yt-dlp', e);
      return YtDlpUpdateResult(success: false, message: e.toString());
    }
  }

  /// 获取版本信息
  Future<Map<String, String>> getVersionInfo() async {
    final initialized = await initialize();
    if (!initialized) return {};

    try {
      final versionInfo = await _youtubeDL.getVersion();
      return {
        'yt-dlp': versionInfo.youtubeDlVersion ?? 'Unknown',
        'ffmpeg': versionInfo.ffmpegVersion ?? 'Unknown',
        'python': versionInfo.pythonVersion ?? 'Unknown',
      };
    } catch (e) {
      AppLogger.error('Failed to get version info', e);
      return {};
    }
  }

  /// 诊断测试 - 用于排查解析问题
  Future<Map<String, dynamic>> diagnose(String url) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return {'success': false, 'error': 'Initialization failed'};
      }
    }

    final result = <String, dynamic>{};

    // 1. 获取 yt-dlp 版本
    try {
      final version = await getVersionInfo();
      result['version'] = version;
      AppLogger.debug('Current yt-dlp version: ${version['yt-dlp']}');
    } catch (e) {
      result['version_error'] = e.toString();
    }

    // 2. 尝试解析视频
    try {
      AppLogger.debug('Testing parsing: $url');
      final info = await _youtubeDL.getVideoInfo(url);
      result['parse_success'] = true;
      result['title'] = info.title;
      result['duration'] = info.duration;
      result['uploader'] = info.uploader;
      result['formats_count'] = info.formats?.length ?? 0;
      AppLogger.debug('Parsing succeeded: ${info.title}');
    } catch (e) {
      result['parse_success'] = false;
      result['parse_error'] = e.toString();
      AppLogger.error('Parsing failed', e);
    }

    // 3. 检查是否需要更新
    try {
      final updateResult = await _youtubeDL.updateYoutubeDL(
        channel: UpdateChannel.stable,
      );
      result['update_status'] = updateResult.status.toString();
      result['update_version'] = updateResult.version;
      if (updateResult.status == OperationStatus.success) {
        AppLogger.debug('yt-dlp updated to: ${updateResult.version}');
      } else {
        AppLogger.error('yt-dlp update failed', updateResult.errorMessage);
        result['update_error'] = updateResult.errorMessage;
      }
    } catch (e) {
      result['update_error'] = e.toString();
      AppLogger.error('Update error', e);
    }

    return result;
  }

  /// 转换为 QvaSave VideoInfo 格式
  qvasave.VideoInfo _convertToQvaSaveVideoInfo(VideoInfo info) {
    final formats =
        info.formats
            ?.where((f) => f != null)
            .map(
              (f) => qvasave.VideoFormat(
                formatId: f!.formatId ?? '',
                ext: f.ext ?? '',
                width: f.width,
                height: f.height,
                fps: f.fps,
                vcodec: f.vcodec,
                acodec: f.acodec,
                filesize: f.filesize,
                filesizeApprox: null,
                formatNote: f.formatNote,
                tbr: f.tbr,
                quality: null,
                protocol: null,
                language: null,
                videoExt: null,
                audioExt: null,
              ),
            )
            .toList() ??
        [];

    return qvasave.VideoInfo(
      id: info.id ?? '',
      title: info.title ?? '',
      thumbnail: info.thumbnail,
      duration: info.duration,
      extractorKey: null,
      webpageUrl: info.url,
      description: info.description,
      viewCount: info.viewCount,
      uploader: info.uploader,
      tags: null,
      formats: formats,
    );
  }

  bool _isYtDlpVersionAtLeast(String actual, String required) {
    final actualParts = _parseYtDlpDateVersion(actual);
    final requiredParts = _parseYtDlpDateVersion(required);
    if (actualParts == null || requiredParts == null) return false;

    for (var i = 0; i < requiredParts.length; i++) {
      if (actualParts[i] > requiredParts[i]) return true;
      if (actualParts[i] < requiredParts[i]) return false;
    }
    return true;
  }

  List<int>? _parseYtDlpDateVersion(String value) {
    final match = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})').firstMatch(value);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  /// 检查 UA 是否为桌面端 UA
  /// 返回 true 如果是 Windows、Mac 或 Linux 桌面端 UA
  bool _isDesktopUA(String ua) {
    if (ua.isEmpty) return false;
    final lowerUA = ua.toLowerCase();
    // 检查是否包含桌面端标识
    final desktopKeywords = [
      'windows nt',
      'macintosh',
      'mac os x',
      'linux x86_64',
      'linux i686',
      'x11; linux',
    ];
    // 检查是否包含移动端标识
    final mobileKeywords = [
      'mobile',
      'android',
      'iphone',
      'ipad',
      'ipod',
      'windows phone',
    ];
    // 如果包含桌面端标识且不包含移动端标识，认为是桌面端 UA
    final hasDesktop = desktopKeywords.any(
      (keyword) => lowerUA.contains(keyword),
    );
    final hasMobile = mobileKeywords.any(
      (keyword) => lowerUA.contains(keyword),
    );
    return hasDesktop && !hasMobile;
  }

  /// 清理资源
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
