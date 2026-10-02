// 添加 URL 对话框
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/providers.dart';
import '../../core/models/models.dart';
import '../../core/services/cookie_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/permission_helper.dart';
import '../../core/utils/url_utils.dart';
import '../../shared/i18n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

class AddUrlDialog extends ConsumerStatefulWidget {
  const AddUrlDialog({super.key});

  @override
  ConsumerState<AddUrlDialog> createState() => _AddUrlDialogState();
}

class _AddUrlDialogState extends ConsumerState<AddUrlDialog> {
  final _urlController = TextEditingController();
  bool _isAudioOnly = false;
  final CookieService _cookieService = CookieService();
  // 控制格式列表滚动状态：是否还有更多选项在列表下方。
  final ScrollController _formatScrollController = ScrollController();
  bool _showMoreFade = false;
  // 避免在 build 期间每帧都重新测量；仅在内容变化时重置。
  bool _formatListMeasured = false;
  // 解析完成后缓存当前域名是否已有 Cookie，避免在格式列表中对每个 chip 反复异步查询
  bool _hasCookieForDomain = false;
  // 解析成功时锁定的 URL；下载时优先使用，避免用户清空输入框后变成 https://
  String? _parsedUrl;

  @override
  void initState() {
    super.initState();
    _formatScrollController.addListener(_onFormatListScroll);
  }

  @override
  void dispose() {
    _formatScrollController.removeListener(_onFormatListScroll);
    _formatScrollController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// 监听格式列表滚动位置：在列表末尾时隐藏"更多选项"渐变提示。
  void _onFormatListScroll() {
    if (!_formatScrollController.hasClients) return;
    final position = _formatScrollController.position;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    if (atEnd != _showMoreFade) {
      setState(() => _showMoreFade = !atEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(isLoadingVideoInfoProvider);
    final videoInfo = ref.watch(currentVideoInfoProvider);
    final selectedFormat = ref.watch(selectedFormatProvider);
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(loc.addUrl),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: loc.pasteUrl,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link_outlined),
                ),
                autofocus: true,
                maxLines: null,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(loc.audioOnly),
                value: _isAudioOnly,
onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _isAudioOnly = value;
                            // 列表内容变化，重新测量是否可滚动
                            _formatListMeasured = false;
                            _showMoreFade = false;
                          });
                        },
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(loc.parsingVideo),
                    ],
                  ),
                ),
              ],
              if (videoInfo != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildVideoPreview(videoInfo),
                const SizedBox(height: 16),
                _buildFormatSelector(videoInfo, selectedFormat),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => _resetAndClose(),
          child: Text(loc.cancel),
        ),
        if (videoInfo == null)
          FilledButton(
            onPressed: isLoading ? null : _parseUrl,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc.parse),
          )
        else
          FilledButton(
            onPressed: isLoading
                ? null
                : () => _startDownload(videoInfo, selectedFormat),
            child: Text(loc.download),
          ),
      ],
    );
  }

  Widget _buildVideoPreview(VideoInfo videoInfo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (videoInfo.thumbnail != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: videoInfo.thumbnail!,
              width: 120,
              height: 68,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 68,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.videocam_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              placeholder: (context, url) => Container(
                width: 120,
                height: 68,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                videoInfo.title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (videoInfo.uploader != null)
                Text(
                  videoInfo.uploader!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (videoInfo.duration != null)
                Text(
                  videoInfo.durationFormatted,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector(
    VideoInfo videoInfo,
    VideoFormat? selectedFormat,
  ) {
    final formats = _isAudioOnly
        ? videoInfo.bestAudioFormats
        : videoInfo.bestVideoFormats;

    if (formats.isEmpty) {
      return Text(AppLocalizations.of(context)!.noAvailableFormat);
    }

    final loc = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = dark
        ? const Color(0xFF1B1D19)
        : const Color(0xFFF3EFE7);
    final url = resolveDownloadUrl(
      parsedUrl: _parsedUrl,
      webpageUrl: videoInfo.webpageUrl,
      inputText: _urlController.text,
    );
    final domain = _cookieService.extractDomain(url);
    final needsLoginHint =
        !_hasCookieForDomain && _cookieService.isBilibiliDomain(domain);

    // 列表内容变化后重新测量是否可滚动，决定是否展示底部"更多选项"提示。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _formatListMeasured) return;
      _formatListMeasured = true;
      if (!_formatScrollController.hasClients) return;
      final position = _formatScrollController.position;
      final canScroll = position.maxScrollExtent > position.minScrollExtent;
      if (_showMoreFade != canScroll) {
        setState(() => _showMoreFade = canScroll);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isAudioOnly
                  ? Icons.music_note_outlined
                  : Icons.high_quality_outlined,
              size: 18,
              color: QvaColors.olive,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isAudioOnly
                    ? loc.selectAudioQuality
                    : loc.selectVideoQuality,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: QvaColors.olive.withValues(alpha: dark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${formats.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: QvaColors.olive,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark
                  ? const Color(0xFF2A2D27)
                  : const Color(0xFFE6E0D4),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  controller: _formatScrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: formats.length,
                  itemBuilder: (context, index) {
                    final format = formats[index];
                    final isSelected =
                        selectedFormat?.formatId == format.formatId;
                    // 对于 Bilibili，只有第一个（最高质量）格式需要登录
                    final requiresLogin =
                        _cookieService.isBilibiliDomain(domain) && index == 0;
                    final isDisabled = requiresLogin && !_hasCookieForDomain;
                    return _FormatRow(
                      key: ValueKey(format.formatId),
                      format: format,
                      selected: isSelected,
                      disabled: isDisabled,
                      loggedIn: _hasCookieForDomain,
                      requiresLogin: requiresLogin,
                      onTap: isDisabled
                          ? null
                          : () {
                              ref.read(selectedFormatProvider.notifier).state =
                                  format;
                            },
                      loc: loc,
                    );
                  },
                ),
              ),
              // 底部渐变 + "更多选项"提示，仅有更多内容时才显示
              if (_showMoreFade)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _MoreOptionsFade(
                    panelColor: panelColor,
                    onScrollDown: () {
                      _formatScrollController.animateTo(
                        _formatScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    label: loc.moreOptions,
                  ),
                ),
            ],
          ),
        ),
        if (needsLoginHint) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc.highQualityRequiresLogin,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _parseUrl() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;

    // 自动补全 URL
    url = normalizeVideoUrl(url);
    if (!isValidHttpUrl(url)) {
      AppLogger.error(
        'Invalid URL before parsing: raw=${_urlController.text}, normalized=$url',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.parseFailedDefault),
          duration: const Duration(seconds: 5),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    AppLogger.info('User started parsing URL: $url');

    ref.read(isLoadingVideoInfoProvider.notifier).state = true;
    ref.read(currentVideoInfoProvider.notifier).state = null;
    ref.read(selectedFormatProvider.notifier).state = null;
    setState(() {
      _parsedUrl = null;
      _hasCookieForDomain = false;
      _formatListMeasured = false;
      _showMoreFade = false;
    });

    final ytDlpService = ref.read(ytDlpServiceProvider);
    // 获取自定义UA
    final prefs = await SharedPreferences.getInstance();
    final customUA = prefs.getString('custom_ua') ?? '';
    final defaultVideoQuality =
        prefs.getString('default_video_quality') ?? '1080p';
    final videoInfo = await ytDlpService.getVideoInfo(url, customUA: customUA);
    // 标准化为 Cookie 查找域名（如 youtu.be → youtube.com），保证后续
    // hasCookie 与错误提示分支都按同一域名判断
    final domain = _cookieService.cookieLookupDomain(
      _cookieService.extractDomain(url),
    );
    final domainHasCookie = await _cookieService.hasCookie(domain);
    if (videoInfo != null) {
      AppLogger.info(
        'User parsed successfully: domain=$domain, hasCookie=$domainHasCookie, '
        'formats=${videoInfo.formats.length}, title=${videoInfo.title}',
      );
    }

    if (mounted) {
      ref.read(isLoadingVideoInfoProvider.notifier).state = false;
      setState(() {
        _hasCookieForDomain = domainHasCookie;
        // 解析成功时锁定 URL；即使之后输入框被清空，下载仍用此 URL
        _parsedUrl = videoInfo != null ? url : null;
      });
      if (videoInfo != null) {
        ref.read(currentVideoInfoProvider.notifier).state = videoInfo;
        // 根据默认质量设置预选格式
        final formats = _isAudioOnly
            ? videoInfo.bestAudioFormats
            : videoInfo.bestVideoFormats;
        if (formats.isNotEmpty) {
          ref.read(selectedFormatProvider.notifier).state = _isAudioOnly
              ? formats.first
              : _pickDefaultVideoFormat(formats, defaultVideoQuality);
        }
      } else {
        final hasCookie = await _cookieService.hasCookie(domain);
        AppLogger.error(
          'User parse failed: domain=$domain, hasCookie=$hasCookie, url=$url',
        );
        if (!mounted) return;
        final loc = AppLocalizations.of(context)!;

        String errorMessage;
        if (domain.contains('douyin.com') || domain.contains('youtube.com')) {
          if (hasCookie) {
            errorMessage = loc.parseFailedExpired;
          } else {
            errorMessage = loc.parseFailedFresh;
          }
        } else if (_cookieService.isBilibiliDomain(domain)) {
          errorMessage = loc.parseFailedBilibili;
        } else {
          errorMessage = loc.parseFailedDefault;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 8),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 根据默认视频质量设置，从已排序（从高到低）的格式列表中选择最合适的格式。
  /// 选择不超过目标高度的最高画质；若都高于目标，则退回到最低的一个，
  /// 'best' 或无法解析时直接用最高画质（列表首项）。
  VideoFormat _pickDefaultVideoFormat(
    List<VideoFormat> sortedFormats,
    String quality,
  ) {
    if (quality == 'best') return sortedFormats.first;

    final targetHeight = int.tryParse(quality.replaceAll('p', ''));
    if (targetHeight == null) return sortedFormats.first;

    // 列表已按高度从高到低排序，找到第一个 <= 目标高度的格式
    for (final format in sortedFormats) {
      final h = format.height;
      if (h != null && h > 0 && h <= targetHeight) {
        return format;
      }
    }

    // 没有任何格式 <= 目标高度，说明都是更高画质：选最低的那个（列表末项）
    return sortedFormats.last;
  }

  Future<void> _startDownload(
    VideoInfo videoInfo,
    VideoFormat? selectedFormat,
  ) async {
    // 先检查是否有管理存储权限
    final hasPermission =
        await PermissionHelper.checkManageExternalStoragePermission();
    if (!hasPermission && mounted) {
      final loc = AppLocalizations.of(context)!;
      // 如果没有权限，提示用户去设置
      await PermissionHelper.showPermissionDialog(
        context,
        title: loc.needStoragePermission,
        message: loc.storagePermissionMessage,
        onGranted: () async {
          await PermissionHelper.openManageExternalStorageSettings();
        },
      );
      return;
    }

    // 优先使用解析时锁定的 URL，避免输入框被清空后变成 https://
    final url = resolveDownloadUrl(
      parsedUrl: _parsedUrl,
      webpageUrl: videoInfo.webpageUrl,
      inputText: _urlController.text,
    );
    if (!isValidHttpUrl(url)) {
      AppLogger.error(
        'Invalid URL before download: parsed=$_parsedUrl, '
        'webpage=${videoInfo.webpageUrl}, input=${_urlController.text}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.parseFailedDefault),
          duration: const Duration(seconds: 5),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    AppLogger.debug('Submitting download task: $url');

    final downloadService = ref.read(downloadServiceProvider);
    final downloadPath = ref.read(downloadPathProvider);

    await downloadService.addTask(
      url: url,
      type: _isAudioOnly ? DownloadType.audio : DownloadType.video,
      selectedFormat: selectedFormat,
      title: videoInfo.title,
      thumbnail: videoInfo.thumbnail,
      channel: videoInfo.uploader,
      duration: videoInfo.duration?.toString(),
      // filesize 常为空；优先 filesize，其次近似值，完成后再用落盘实测覆盖
      fileSize: selectedFormat?.filesize ?? selectedFormat?.filesizeApprox,
      downloadPath: downloadPath,
    );

    // 刷新任务列表
    ref.read(downloadTasksProvider.notifier).state = downloadService
        .getAllTasks();

    if (mounted) {
      _resetAndClose();
    }
  }

  void _resetAndClose() {
    ref.read(isLoadingVideoInfoProvider.notifier).state = false;
    ref.read(currentVideoInfoProvider.notifier).state = null;
    ref.read(selectedFormatProvider.notifier).state = null;
    _parsedUrl = null;
    Navigator.of(context).pop();
  }
}

/// 单个格式选项行：分辨率/码率 + 扩展名/大小 + 选中状态。
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    super.key,
    required this.format,
    required this.selected,
    required this.disabled,
    required this.loggedIn,
    required this.requiresLogin,
    required this.onTap,
    required this.loc,
  });

  final VideoFormat format;
  final bool selected;
  final bool disabled;
  final bool loggedIn;
  final bool requiresLogin;
  final VoidCallback? onTap;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _buildTitle();
    final subtitle = _buildSubtitle();
    final textColor = disabled
        ? (isDark ? const Color(0xFF70746B) : const Color(0xFF9B988F))
        : (isDark ? const Color(0xFFEDEDEC) : QvaColors.ink);
    final subtitleColor = disabled
        ? (isDark ? const Color(0xFF585C55) : const Color(0xFFB4AFA3))
        : (isDark ? const Color(0xFF8F8F89) : QvaColors.muted);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Material(
        color: selected
            ? QvaColors.olive.withValues(alpha: isDark ? 0.32 : 0.16)
            : (isDark ? const Color(0xFF262825) : const Color(0xFFFAF7F0)),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? QvaColors.olive
                    : (isDark
                          ? const Color(0xFF32352E)
                          : const Color(0xFFE7E1D4)),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: selected
                      ? QvaColors.olive
                      : (isDark
                            ? const Color(0xFF6F7469)
                            : const Color(0xFFB9B4A8)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (requiresLogin) ...[
                  const SizedBox(width: 6),
                  Icon(
                    loggedIn ? Icons.verified : Icons.lock,
                    size: 14,
                    color: loggedIn
                        ? Colors.green
                        : (isDark
                              ? const Color(0xFFD07A68)
                              : const Color(0xFFD24D3C)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildTitle() {
    if (!format.hasVideo) {
      // 音频格式：优先显示比特率
      if (format.tbr != null) return '${format.tbr}k';
      if (format.formatNote != null && format.formatNote!.isNotEmpty) {
        return format.formatNote!;
      }
      return loc.audio;
    }
    // 视频格式：优先显示分辨率
    if (format.height != null && format.height! > 0) return '${format.height}p';
    if (format.width != null &&
        format.height != null &&
        format.width! > 0 &&
        format.height! > 0) {
      return '${format.width}x${format.height}';
    }
    if (format.formatNote != null && format.formatNote!.isNotEmpty) {
      return format.formatNote!;
    }
    return format.formatId;
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (format.ext.isNotEmpty) {
      parts.add(format.ext.toUpperCase());
    }
    if (format.fps != null && format.fps! > 0) {
      parts.add('${format.fps}fps');
    }
    if (format.filesize != null) {
      parts.add(_formatBytes(format.filesize!));
    } else if (format.filesizeApprox != null) {
      parts.add(_formatBytes(format.filesizeApprox!));
    }
    return parts.join('  •  ');
  }
}

/// 列表底部"还有更多选项"的渐变遮罩 + 向下箭头提示。
class _MoreOptionsFade extends StatelessWidget {
  const _MoreOptionsFade({
    required this.panelColor,
    required this.onScrollDown,
    required this.label,
  });

  final Color panelColor;
  final VoidCallback onScrollDown;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                panelColor.withValues(alpha: 0),
                panelColor.withValues(alpha: 0.9),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: onScrollDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2F28)
                    : const Color(0xFF17181A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFEDEDEC) : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFEDEDEC) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 格式化字节数为可读文本（B / KB / MB / GB）。
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
