import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared/constants/app_constants.dart';
import 'shared/i18n/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/qva_nav_bar.dart';
import 'core/providers/service_providers.dart';
import 'core/services/services.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/permission_helper.dart';
import 'features/download/download.dart';
import 'features/history/history.dart';
import 'features/settings/settings.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.initialize();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'Flutter uncaught exception',
          details.exception,
          details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error('Platform uncaught exception', error, stackTrace);
        return true;
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      AppLogger.info('QvaSave Pro startup complete');
      runApp(const ProviderScope(child: QvaSaveApp()));
      // 通知通道不影响首屏展示，放到 runApp 之后初始化以缩短冷启动等待。
      unawaited(_initializeNotificationService());
    },
    (error, stackTrace) {
      AppLogger.error('Zone uncaught exception', error, stackTrace);
    },
  );
}

Future<void> _initializeNotificationService() async {
  try {
    await NotificationService().initialize();
  } catch (e, stackTrace) {
    AppLogger.error('Notification service init failed, skipped', e, stackTrace);
  }
}

/// QvaSave App 入口。
class QvaSaveApp extends ConsumerWidget {
  const QvaSaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final languageCode = ref.watch(languageProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: QvaTheme.buildLight(),
      darkTheme: QvaTheme.buildDark(),
      themeMode: themeMode,
      locale: Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  final List<Widget?> _pages = [const DownloadsPage(), null, null];

  Widget _createPage(int index) => switch (index) {
    0 => const DownloadsPage(),
    1 => const HistoryPage(),
    2 => const SettingsPage(),
    _ => const SizedBox.shrink(),
  };

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // 加载下载路径
    final savedPath = prefs.getString('download_path');
    if (savedPath != null && savedPath.isNotEmpty) {
      if (mounted) {
        ref.read(downloadPathProvider.notifier).state = savedPath;
      }
    } else {
      final defaultPath = await PermissionHelper.getDefaultDownloadPath();
      if (mounted) {
        ref.read(downloadPathProvider.notifier).state = defaultPath;
      }
    }
    // 加载语言设置
    final savedLanguage = prefs.getString('language');
    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      if (mounted) {
        ref.read(languageProvider.notifier).state = resolveAppLanguageCode(
          savedLanguage,
        );
      }
    }
    // 加载主题设置
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null && savedTheme.isNotEmpty) {
      final themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
      if (mounted) {
        ref.read(themeModeProvider.notifier).state = themeMode;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: QvaColors.olive,
        systemNavigationBarColor: QvaColors.navOverlay,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          centerTitle: false,
          titleSpacing: 24,
          title: Text(
            AppConstants.appName,
            style: const TextStyle(
              fontFamily: QvaColors.fontJersey25,
              fontSize: 36,
              height: 1,
              letterSpacing: -0.5,
              color: QvaColors.wordmark,
              shadows: [
                Shadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        // 已访问页面保留状态与滚动位置；未访问页面仍延迟构建，避免拖慢首屏。
        body: IndexedStack(
          index: _selectedIndex,
          children: [for (final page in _pages) page ?? const SizedBox.shrink()],
        ),
        bottomNavigationBar: QvaNavBar(
          currentIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _pages[index] ??= _createPage(index);
              _selectedIndex = index;
            });
          },
          items: [
            QvaNavDestination(icon: Icons.home_outlined, label: loc.home),
            QvaNavDestination(icon: Icons.history, label: loc.history),
            QvaNavDestination(icon: Icons.tune, label: loc.settings),
          ],
          onAddPressed: () => _showAddUrlDialog(context),
        ),
      ),
    );
  }

  void _showAddUrlDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddUrlDialog());
  }
}
