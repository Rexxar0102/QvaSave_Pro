// 通知服务
// 用于显示下载进度的通知显示

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知服务类
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// 初始化通知服务
  Future<void> initialize() {
    if (_isInitialized) return Future<void>.value();
    final currentInitialization = _initializationFuture;
    if (currentInitialization != null) return currentInitialization;

    final initialization = _initialize();
    _initializationFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  /// 显示下载进度通知
  Future<void> showDownloadProgress({
    required String taskId,
    required String title,
    required int progress,
    String? speed,
    String? eta,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'download_channel',
          'Download progress',
          channelDescription: 'Displays video download progress',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    String content = '${progress.toStringAsFixed(0)}%';
    if (speed != null) {
      content += ' • $speed';
    }
    if (eta != null) {
      content += ' • Remaining $eta';
    }

    final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;

    await _notifications.show(notificationId, title, content, details);
  }

  /// 显示下载完成通知
  Future<void> showDownloadComplete({
    required String taskId,
    required String title,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'download_complete_channel',
          'Download complete',
          channelDescription: 'Displays video download completion',
          importance: Importance.high,
          priority: Priority.high,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;

    await _notifications.show(
      notificationId,
      'Download complete',
      title,
      details,
    );
  }

  /// 显示下载失败通知
  Future<void> showDownloadError({
    required String taskId,
    required String title,
    required String error,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'download_error_channel',
          'Download failed',
          channelDescription: 'Displays video download failure',
          importance: Importance.high,
          priority: Priority.high,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;

    await _notifications.show(
      notificationId,
      'Download failed',
      '$title: $error',
      details,
    );
  }

  /// 取消指定任务的通知
  Future<void> cancelNotification(String taskId) async {
    final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;
    await _notifications.cancel(notificationId);
  }
}
