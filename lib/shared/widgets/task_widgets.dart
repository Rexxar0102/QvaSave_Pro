import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../i18n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 任务缩略图：带占位与错误回退，下载页与历史页共用（尺寸可配）。
///
/// [thumbnailUrl] 为 null 时返回零尺寸占位，行为与原先的
/// `if (task.thumbnail != null) ...` 一致（外层间距不变）。
class TaskThumbnail extends StatelessWidget {
  const TaskThumbnail({
    super.key,
    required this.thumbnailUrl,
    this.width = 120,
    this.height = 68,
  });

  final String? thumbnailUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url == null) return const SizedBox.shrink();

    final fallbackColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: fallbackColor,
          child: Icon(
            Icons.videocam_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        placeholder: (context, url) =>
            Container(width: width, height: height, color: fallbackColor),
      ),
    );
  }
}

/// 任务状态标签，下载页与历史页共用。
class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip({super.key, required this.status, required this.loc});

  final DownloadStatus status;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      DownloadStatus.pending => const Color(0xFFB08D2E),
      DownloadStatus.downloading => QvaColors.olive,
      DownloadStatus.processing => const Color(0xFF85706B),
      DownloadStatus.completed => QvaColors.glow,
      DownloadStatus.error => const Color(0xFFD24D3C),
      DownloadStatus.cancelled => const Color(0xFF8E8E92),
    };
    final String label = switch (status) {
      DownloadStatus.pending => loc.pendingTask,
      DownloadStatus.downloading => loc.downloadingTask,
      DownloadStatus.processing => loc.processingTask,
      DownloadStatus.completed => loc.completedTask,
      DownloadStatus.error => loc.failedTask,
      DownloadStatus.cancelled => loc.cancelledTask,
    };

    return _TagPill(label: label, color: color);
  }
}

class TaskTypeChip extends StatelessWidget {
  const TaskTypeChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _TagPill(label: label, color: color);
  }
}

/// 设计稿风格的胶囊标签：低透明度底色 + 圆角 8 + 11px 加粗小字。
class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
