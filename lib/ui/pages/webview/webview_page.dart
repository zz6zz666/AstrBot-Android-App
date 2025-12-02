import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../controllers/terminal_controller.dart';
import 'settings_page.dart';
import 'bottom_nav_bar.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  int _currentIndex = 0;
  late final WebViewController _astrBotController;
  late final WebViewController _napCatController;
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

    // 检查 WebUI 是否启用
    final bool webUiEnabled = homeController.napCatWebUiEnabled.get() ?? false;
    

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
    final bool napCatEnabled = homeController.napCatWebUiEnabled.get() ?? false;
    
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

    // 检查 NapCat WebUI 是否启用
    final bool napCatEnabled = homeController.napCatWebUiEnabled.get() ?? false;

    // 动态构建页面列表
    final List<Widget> pages = [
      // 1. AstrBot 配置页面
      WebViewWidget(controller: _astrBotController),

      // 2. NapCat 配置页面（仅在启用时添加）
      if (napCatEnabled) WebViewWidget(controller: _napCatController),
    ];

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
              index: _currentIndex,
              children: [
                ...pages,

                // 3. 软件设置页面
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
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
