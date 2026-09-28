// 通用 WebView 登录页面
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/services/cookie_service.dart';
import '../../core/utils/app_logger.dart';
import '../../shared/i18n/app_localizations.dart';

class WebViewLoginPage extends StatefulWidget {
  final String title;
  final String loginUrl;
  final String domain;
  final String? successUrl;
  final List<String>? requiredCookies;
  final String? userAgent;

  const WebViewLoginPage({
    super.key,
    required this.title,
    required this.loginUrl,
    required this.domain,
    this.successUrl,
    this.requiredCookies,
    this.userAgent,
  });

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  WebViewController? _controller;
  final CookieService _cookieService = CookieService();
  bool _isLoading = true;
  String _statusMessage = '';
  bool _loginDetected = false;
  bool _hasError = false;

  String _t(String template, Map<String, Object> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    // 确保每次打开页面时都是全新状态
    _loginDetected = false;
    _hasError = false;
    _isLoading = true;
    _statusMessage = '';
    _clearWebViewCookiesAndInit();
  }

  /// 先清理 WebView Cookie，再初始化 WebView
  Future<void> _clearWebViewCookiesAndInit() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      AppLogger.debug('WebView cookies cleared, preparing to load login page');
    } catch (e) {
      AppLogger.error('Failed to clear WebView cookies', e);
    }
    if (!mounted) return;
    _initWebView();
  }

  void _initWebView() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        widget.userAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
              _statusMessage = loc.loadingPage;
            });
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = false;
              _statusMessage = _t(loc.pleaseLoginThenDetect, {
                'site': widget.title,
              });
            });
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.error('WebView load error');
            AppLogger.error('WebView error description', error.description);
            AppLogger.error('WebView error code', error.errorCode);
            AppLogger.error('WebView error type', error.errorType);
            AppLogger.error('WebView error URL', error.url);

            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                String errorMsg = loc.loadFailed;

                // 根据错误码提供更详细的错误信息
                switch (error.errorCode) {
                  case -1:
                    errorMsg = loc.unknownError;
                    break;
                  case -2:
                    errorMsg = loc.serverNoResponse;
                    break;
                  case -6:
                    errorMsg = loc.connectionRefused;
                    break;
                  case -7:
                    errorMsg = loc.connectionTimeout;
                    break;
                  case -8:
                    errorMsg = loc.connectionClosed;
                    break;
                  case -10:
                    errorMsg = loc.dnsError;
                    break;
                  case -11:
                    errorMsg = loc.cannotConnectToServer;
                    break;
                  default:
                    errorMsg = _t(loc.loadFailedWithReason, {
                      'error': error.description,
                    });
                }

                _statusMessage =
                    '$errorMsg (${_t(loc.errorCodeLabel, {'code': error.errorCode})})';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (!mounted) return NavigationDecision.navigate;
            // 如果跳转到指定的成功 URL，说明登录成功
            if (widget.successUrl != null &&
                (request.url == widget.successUrl ||
                    request.url.startsWith(widget.successUrl!))) {
              _onLoginSuccess();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));

    setState(() {
      _controller = controller;
    });
  }

  /// 保存 Cookie
  Future<void> _saveCookies(String cookieString) async {
    try {
      // 清理 Cookie 字符串
      String cleanCookies = cookieString
          .replaceAll('"', '')
          .replaceAll('\\n', '')
          .trim();

      await _cookieService.saveCookie(widget.domain, cleanCookies);

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() {
          _hasError = false;
          _statusMessage = loc.loginSuccessCookiesSaved;
        });

        // 延迟后关闭页面
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to save cookies', e);
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() {
          _hasError = true;
          _statusMessage = '${loc.saveCookieFailed}: $e';
        });
      }
    }
  }

  /// 登录成功处理
  Future<void> _onLoginSuccess() async {
    final controller = _controller;
    if (!mounted || controller == null) return;
    try {
      // 获取所有 Cookie
      final cookies = await controller.runJavaScriptReturningResult(
        'document.cookie',
      );

      await _saveCookies(cookies.toString());
    } catch (e) {
      AppLogger.error('Failed to get cookies', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(loc.loginToSite, {'site': widget.title})),
        actions: [
          TextButton(
            onPressed: _controller == null
                ? null
                : () async {
                    final controller = _controller;
                    if (controller == null) return;
                    try {
                      // 获取当前 Cookie
                      final cookies = await controller
                          .runJavaScriptReturningResult('document.cookie');
                      final cookieString = cookies.toString();

                      AppLogger.debug('Manual cookie save: cookies retrieved');

                      if (cookieString.isNotEmpty) {
                        // 直接保存，不管有没有检测到登录状态
                        _loginDetected = true;
                        await _saveCookies(cookieString);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.noCookiesDetected)),
                          );
                        }
                      }
                    } catch (e) {
                      AppLogger.error('Failed to get cookies', e);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${loc.getCookieFailed}: $e')),
                        );
                      }
                    }
                  },
            child: Text(loc.saveCookie),
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _loginDetected
                ? Colors.green.withValues(alpha: 0.1)
                : _hasError
                ? Colors.red.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _loginDetected
                        ? Icons.check_circle
                        : _hasError
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 16,
                    color: _loginDetected
                        ? Colors.green
                        : _hasError
                        ? Colors.red
                        : null,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage.isEmpty
                        ? loc.loadingLoginPage
                        : _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                // 错误时显示重试按钮
                if (_hasError)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _statusMessage = loc.reloading;
                      });
                      _controller?.reload();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.retry),
                  ),
              ],
            ),
          ),

          // WebView
          Expanded(
            child: _controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    );
  }
}
