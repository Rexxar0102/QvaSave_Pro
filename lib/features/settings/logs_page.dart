import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/app_logger.dart';
import '../../shared/i18n/app_localizations.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late DateTime _from;
  late DateTime _to;
  String _logs = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = now;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await AppLogger.readLogs(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _logs = logs;
      });
    } catch (error, stackTrace) {
      AppLogger.error('Failed to read logs', error, stackTrace);
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${loc.logsLoadFailed}: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _from : _to;
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selectedTime == null) return;

    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
      isStart ? 0 : 59,
      isStart ? 0 : 999,
    );

    setState(() {
      if (isStart) {
        _from = selected;
        if (_from.isAfter(_to)) {
          _to = _from.add(const Duration(minutes: 5));
        }
      } else {
        _to = selected;
        if (_to.isBefore(_from)) {
          _from = _to.subtract(const Duration(minutes: 5));
        }
      }
    });
    await _loadLogs();
  }

  Future<void> _copyLogs() async {
    final loc = AppLocalizations.of(context)!;
    final text = _logs.isEmpty ? loc.noLogsInRange : _logs;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.logsCopied)));
  }

  Future<void> _exportLogs() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final file = await AppLogger.exportLogs(from: _from, to: _to);
      await Share.shareXFiles([XFile(file.path)], text: loc.shareLogsSubject);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.logsFileGenerated}: ${file.path}')),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to export logs', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.logsExportFailed}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.logs),
        actions: [
          IconButton(
            tooltip: loc.refresh,
            onPressed: _isLoading ? null : _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colorScheme.surface,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: Text(loc.startTime),
                  subtitle: Text(_formatDateTime(_from)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isStart: true),
                ),
                ListTile(
                  leading: const Icon(Icons.stop_outlined),
                  title: Text(loc.endTime),
                  subtitle: Text(_formatDateTime(_to)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isStart: false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLogPreview(context),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _copyLogs,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(loc.copy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _exportLogs,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(loc.exportFile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogPreview(BuildContext context) {
    if (_logs.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noLogsInRange));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: SelectableText(
          _logs,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.35,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
