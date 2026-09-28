// 媒体扫描工具
// 用于通知系统媒体库扫描新下载的文件

import 'package:flutter/services.dart';
import 'app_logger.dart';

/// 媒体扫描工具类
class MediaScanner {
  static const MethodChannel _channel = MethodChannel(
    'com.qvasoft.qvasave_pro.media_scanner',
  );

  /// 扫描单个文件
  static Future<void> scanFile(String filePath) async {
    try {
      await _channel.invokeMethod('scanFile', {'filePath': filePath});
      AppLogger.debug('Media scan succeeded: $filePath');
    } catch (e) {
      AppLogger.error('Media scan failed', e);
    }
  }
}
