import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../controllers/terminal_controller.dart';
import '../settings/settings_page.dart';
import '../../navbar/bottom_nav_bar.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  int _currentIndex = 0;
  late final WebViewController _astrBotController;
  late final WebViewController _napCatController;
  final Map<int, WebViewController> _customControllers = {}; // 存储自定义 WebView 控制器
  DateTime? _lastBackPressed;

  final HomeController homeController = Get.find<HomeController>();

  // 标记 AstrBot WebView 是否初始化
  // Flag for AstrBot WebView initialization
  bool _astrBotInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSystemUI();
    _initAstrBotController();
    _initNapCatController();
  }

  @override
  void dispose() {
    _restoreSystemUI();
    super.dispose();
  }

  void _initSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  void _restoreSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  void _initAstrBotController() {
    _astrBotController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectClipboardScript(_astrBotController);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('AstrBot WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('http://127.0.0.1:6185'));

    if (_astrBotController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _astrBotController.platform as AndroidWebViewController;
      androidController
          .setMediaPlaybackRequiresUserGesture(false);
      // 设置混合内容模式以提高兼容性（Android 9+ 需要）
      androidController.setMixedContentMode(MixedContentMode.compatibilityMode);
      // 允许访问本地文件和内容
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);
    }

    _astrBotController.addJavaScriptChannel(
      'Android',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'getClipboardData') {
          _getClipboardData(_astrBotController);
        }
      },
    );
    
    setState(() {
      _astrBotInitialized = true;
    });
  }

  void _initNapCatController() {
    _napCatController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('NapCat WebView error: ${error.description}');
          },
        ),
      );

    // 监听 Token 变化
    ever(homeController.napCatWebUiToken, (String token) {
      if (token.isNotEmpty) {
        final url = 'http://127.0.0.1:6099/webui?token=$token';
        _napCatController.loadRequest(Uri.parse(url));
      }
    });

    // 初始加载
    if (homeController.napCatWebUiToken.isNotEmpty) {
      final url = 'http://127.0.0.1:6099/webui?token=${homeController.napCatWebUiToken.value}';
      _napCatController.loadRequest(Uri.parse(url));
    } else {
      _napCatController.loadRequest(Uri.parse('http://127.0.0.1:6099/webui'));
    }

    if (_napCatController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _napCatController.platform as AndroidWebViewController;
      androidController
          .setMediaPlaybackRequiresUserGesture(false);
      // 设置混合内容模式以提高兼容性（Android 9+ 需要）
      androidController.setMixedContentMode(MixedContentMode.compatibilityMode);
      // 允许访问本地文件和内容
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);
    }
  }

  // 创建自定义 WebView 控制器
  WebViewController _createCustomController(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('Custom WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setMixedContentMode(MixedContentMode.compatibilityMode);
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);
    }

    return controller;
  }

  // 获取或创建自定义 WebView 控制器
  WebViewController _getCustomController(int index, String url) {
    if (!_customControllers.containsKey(index)) {
      _customControllers[index] = _createCustomController(url);
    }
    return _customControllers[index]!;
  }

  void _injectClipboardScript(WebViewController controller) {
    const String jsCode = '''
      const originalReadText = navigator.clipboard.readText;
      navigator.clipboard.readText = function () {
        console.log('Intercepted clipboard read');
        return new Promise((resolve) => {
          Android.postMessage('getClipboardData');
          setTimeout(() => {
            originalReadText.call(navigator.clipboard).then(text => {
              resolve(text);
            }).catch(() => resolve(''));
          }, 100);
        });
      };
    ''';
    controller.runJavaScript(jsCode);
  }

  Future<void> _getClipboardData(WebViewController controller) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text ?? '';
    controller.runJavaScript('window.clipboardText = "$text";');
  }

  Future<void> _handleBackPress() async {
    // 检查 NapCat WebUI 是否启用
    final bool napCatEnabled = homeController.napCatWebUiEnabledRx.value;
    final customWebViews = homeController.customWebViews;

    // 如果当前是 AstrBot 页面且 WebView 可回退，则回退
    if (_currentIndex == 0 && await _astrBotController.canGoBack()) {
      await _astrBotController.goBack();
      return;
    }

    // 如果当前是 NapCat 页面且 WebView 可回退，则回退
    if (napCatEnabled && _currentIndex == 1 && await _napCatController.canGoBack()) {
      await _napCatController.goBack();
      return;
    }

    // 检查是否是自定义 WebView 页面
    int customStartIndex = napCatEnabled ? 2 : 1;
    int customEndIndex = customStartIndex + customWebViews.length - 1;
    if (_currentIndex >= customStartIndex && _currentIndex <= customEndIndex) {
      int customIndex = _currentIndex - customStartIndex;
      if (_customControllers.containsKey(customIndex)) {
        final controller = _customControllers[customIndex]!;
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      }
    }

    // 否则执行双击退出逻辑
    final now = DateTime.now();
    final backButtonInterval = _lastBackPressed == null
        ? const Duration(seconds: 3)
        : now.difference(_lastBackPressed!);

    if (backButtonInterval > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Get.showSnackbar(
        const GetSnackBar(
          message: '再按一次退出',
          duration: Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(10),
          borderRadius: 10,
          backgroundColor: Colors.black87,
          messageText: Text('再按一次退出', style: TextStyle(color: Colors.white)),
        ),
      );
    } else {
      _lastBackPressed = null;
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_astrBotInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Obx(() {
      // 检查 NapCat WebUI 是否启用
      final bool napCatEnabled = homeController.napCatWebUiEnabledRx.value;
      final customWebViews = homeController.customWebViews;

      // 动态构建页面列表
      final List<Widget> pages = [
        // 1. AstrBot 配置页面
        WebViewWidget(controller: _astrBotController),

        // 2. NapCat 配置页面（仅在启用时添加）
        if (napCatEnabled) WebViewWidget(controller: _napCatController),

        // 3. 自定义 WebView 页面
        ...List.generate(customWebViews.length, (index) {
          final webview = customWebViews[index];
          final url = webview['url'] ?? '';
          return WebViewWidget(
            controller: _getCustomController(index, url),
          );
        }),
      ];

      // 计算设置页的索引(始终是最后一个)
      final int settingsIndex = pages.length;

      // 确保 currentIndex 不超出范围
      // 如果当前索引超出范围,说明用户在设置页,需要调整到正确的设置页索引
      final int validCurrentIndex = _currentIndex > settingsIndex
          ? settingsIndex
          : _currentIndex;

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleBackPress();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: true,
              child: IndexedStack(
                index: validCurrentIndex,
                children: [
                  ...pages,

                  // 4. 软件设置页面
                  SettingsPage(
                    astrBotController: _astrBotController,
                    napCatController: _napCatController,
                    onNavigate: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: WebViewBottomNavBar(
              currentIndex: validCurrentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ),
      );
    });
  }
}
