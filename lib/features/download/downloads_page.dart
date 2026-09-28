// 下载页面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../core/models/models.dart';
import '../../core/utils/event_bus.dart';
import '../../shared/i18n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/task_widgets.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  StreamSubscription? _taskUpdateSubscription;
  Timer? _progressRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _taskUpdateSubscription?.cancel();
    _progressRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final downloadService = ref.read(downloadServiceProvider);
    await downloadService.initialize();
    _refreshTasks();
  }

  void _setupEventListeners() {
    _taskUpdateSubscription = eventBus.on<TaskUpdatedEvent>().listen((event) {
      // 下载进度事件触发非常频繁；对其做节流，避免每帧重建整个列表。
      // 状态转换（开始/完成/错误/取消）则立即刷新。
      if (event.task.status == DownloadStatus.downloading) {
        _scheduleProgressRefresh();
      } else {
        _progressRefreshTimer?.cancel();
        _refreshTasks();
      }
    });
  }

  void _scheduleProgressRefresh() {
    if (_progressRefreshTimer?.isActive ?? false) return;
    _progressRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshTasks();
    });
  }

  void _refreshTasks() {
    final downloadService = ref.read(downloadServiceProvider);
    final tasks = downloadService.getAllTasks();
    ref.read(downloadTasksProvider.notifier).state = tasks;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadTasksProvider);
    final loc = AppLocalizations.of(context)!;

    if (tasks.isEmpty) {
      return _buildEmptyState(context, loc);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => DownloadTaskCard(
        key: ValueKey(tasks[index].id),
        task: tasks[index],
        onCancel: () => _cancelTask(tasks[index].id),
        loc: loc,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: QvaColors.olive.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.download_outlined,
                size: 40,
                color: QvaColors.olive,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.noDownloads,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? const Color(0xFFEDEDEC) : QvaColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.clickToAddDownload,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: isDark ? const Color(0xFF8F8F89) : QvaColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelTask(String taskId) async {
    final downloadService = ref.read(downloadServiceProvider);
    await downloadService.cancelTask(taskId);
    _refreshTasks();
  }
}

class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  final AppLocalizations loc;

  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onCancel,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TaskThumbnail(thumbnailUrl: task.thumbnail),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title ?? loc.unknownTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TaskStatusChip(status: task.status, loc: loc),
                          const SizedBox(width: 8),
                          if (task.type == DownloadType.audio)
                            TaskTypeChip(label: loc.audio, color: QvaColors.oliveFab),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (task.progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: task.progress!.percent / 100),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${task.progress!.percent.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (task.progress!.currentSpeed != null)
                    Text(
                      task.progress!.currentSpeed!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (task.progress!.eta != null)
                    Text(
                      'ETA: ${task.progress!.eta}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            if (task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.pending)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(loc.cancel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
