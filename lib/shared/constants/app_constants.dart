class AppConstants {
  static const String appName = 'QvaSave Pro';
  /// 品牌公司名，用于界面显示。
  static const String companyName = 'QvaSoft';
  // 正式版本号由 CI 从 git tag 注入到 Android versionName / PackageInfo.version。
  // 此字段仅作本地调试/未注入时的占位，UI 应优先用 PackageInfo。
  static const String appVersion = '2026.07.11.1';
  static const String githubUrl =
      'https://github.com/Rexxar0102/QvaSave_Pro';

  static const int defaultMaxConcurrentDownloads = 3;

  static const String dbName = 'qvasave.db';
}
