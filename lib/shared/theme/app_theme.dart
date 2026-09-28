import 'package:flutter/material.dart';

/// QvaSave Pro 品牌色调色板（源自设计稿）。
abstract final class QvaColors {
  /// 主色：橄榄绿。
  static const Color olive = Color(0xFF8B9A6E);

  /// FAB / 强调橄榄绿。
  static const Color oliveFab = Color(0xFF919E74);

  /// 工作区背景：奶油色。
  static const Color cream = Color(0xFFF7F2EB);

  /// 主文字 / 深墨色。
  static const Color ink = Color(0xFF17181A);

  /// 次要文字 / 灰褐色。
  static const Color muted = Color(0xFFC8C2BB);

  /// Wordmark 高亮（奶油白）。
  static const Color wordmark = Color(0xFFEEEEEE);

  /// FAB 发光效果（iOS 绿）。
  static const Color glow = Color(0xFF34C759);

  /// 导航栏橄榄绿（95% 不透明度）。
  static const Color navOverlay = Color(0xF28B9A6E);

  /// App 名称字体。
  static const String fontInter = 'Inter';

  /// Wordmark 字体。
  static const String fontJersey25 = 'Jersey25';
}

/// 共享的基础主题片段。
abstract final class QvaTheme {
  static ThemeData buildLight() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: QvaColors.olive,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: QvaColors.cream,
      fontFamily: QvaColors.fontInter,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: QvaColors.olive,
        foregroundColor: QvaColors.wordmark,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData buildDark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: QvaColors.olive,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF141513),
      fontFamily: QvaColors.fontInter,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: QvaColors.olive,
        foregroundColor: QvaColors.wordmark,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F211D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1F211D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1F211D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: QvaColors.fontInter),
      displayMedium: TextStyle(fontFamily: QvaColors.fontInter),
      displaySmall: TextStyle(fontFamily: QvaColors.fontInter),
      headlineMedium: TextStyle(fontFamily: QvaColors.fontInter),
      headlineSmall: TextStyle(fontFamily: QvaColors.fontInter),
      titleLarge: TextStyle(fontFamily: QvaColors.fontInter),
      titleMedium: TextStyle(fontFamily: QvaColors.fontInter),
      titleSmall: TextStyle(fontFamily: QvaColors.fontInter),
      bodyLarge: TextStyle(fontFamily: QvaColors.fontInter),
      bodyMedium: TextStyle(fontFamily: QvaColors.fontInter),
      bodySmall: TextStyle(fontFamily: QvaColors.fontInter),
      labelLarge: TextStyle(fontFamily: QvaColors.fontInter),
      labelMedium: TextStyle(fontFamily: QvaColors.fontInter),
      labelSmall: TextStyle(fontFamily: QvaColors.fontInter),
    );
  }
}