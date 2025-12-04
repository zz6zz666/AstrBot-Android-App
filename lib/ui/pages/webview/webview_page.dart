import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/terminal_controller.dart';
import '../settings/settings_page.dart';
import '../terminal/terminal_theme.dart';
import '../../navbar/bottom_nav_bar.dart';
import '../../../core/services/password_manager.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  int _currentIndex = 0;
  int _previousNavItemCount = 0; // 记录上一次导航栏项目数量

  late final WebViewController _astrBotController;
  late final WebViewController _napCatController;
  final Map<String, WebViewController> _customControllers = {}; // 存储自定义 WebView 控制器，使用 URL 作为 key

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

    // 监听自定义 WebView 列表变化,清理已删除的控制器
    ever(homeController.customWebViews, (List<Map<String, String>> webviews) {
      // 清理不再存在的控制器
      final validUrls = webviews.map((wv) => wv['url'] ?? '').toSet();
      final controllersToRemove = _customControllers.keys.where((key) => !validUrls.contains(key)).toList();
      for (final key in controllersToRemove) {
        _customControllers.remove(key);
      }
    });
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

  // 检查URL是否为本地地址
  bool _isLocalUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      // 检查是否为本地地址
      return host == 'localhost' ||
             host == '127.0.0.1' ||
             host == '0.0.0.0' ||
             host.startsWith('192.168.') ||
             host.startsWith('10.') ||
             (host.startsWith('172.') && _isPrivateIp172(host));
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return false;
    }
  }

  // 检查是否为172.16.0.0 - 172.31.255.255范围的私有IP
  bool _isPrivateIp172(String host) {
    final parts = host.split('.');
    if (parts.length >= 2) {
      final secondOctet = int.tryParse(parts[1]);
      return secondOctet != null && secondOctet >= 16 && secondOctet <= 31;
    }
    return false;
  }

  // 在外部浏览器中打开URL
  Future<void> _launchInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Cannot launch URL: $url');
        if (mounted) {
          Get.snackbar(
            '无法打开链接',
            '无法在浏览器中打开此链接',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        Get.snackbar(
          '打开失败',
          '打开链接时出错: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _initAstrBotController() {
    _astrBotController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // 拦截外域URL
            if (!_isLocalUrl(request.url)) {
              debugPrint('Intercepting external URL: ${request.url}');
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            _injectClipboardScript(_astrBotController);
            _disableZoom(_astrBotController);
            _injectPasswordScript(_astrBotController, url);
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
      // 设置文件选择回调
      androidController.setOnShowFileSelector(_handleFileSelection);
    }

    _astrBotController.addJavaScriptChannel(
      'Android',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'getClipboardData') {
          _getClipboardData(_astrBotController);
        } else if (message.message.startsWith('savePassword:')) {
          _handlePasswordSave(message.message);
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
          onNavigationRequest: (NavigationRequest request) {
            // 拦截外域URL
            if (!_isLocalUrl(request.url)) {
              debugPrint('Intercepting external URL: ${request.url}');
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            _disableZoom(_napCatController);
            _injectPasswordScript(_napCatController, url);
          },
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
      // 设置文件选择回调
      androidController.setOnShowFileSelector(_handleFileSelection);
    }

    _napCatController.addJavaScriptChannel(
      'Android',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message.startsWith('savePassword:')) {
          _handlePasswordSave(message.message);
        }
      },
    );
  }

  // 创建自定义 WebView 控制器
  WebViewController _createCustomController(String url) {
    final controller = WebViewController();

    // 检查初始URL是否为本地地址，如果是则启用外域拦截
    final shouldInterceptExternal = _isLocalUrl(url);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // 仅对配置为本地URL的WebView启用外域拦截
            if (shouldInterceptExternal && !_isLocalUrl(request.url)) {
              debugPrint('Intercepting external URL from custom WebView: ${request.url}');
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String pageUrl) {
            _disableZoom(controller);
            _injectPasswordScript(controller, pageUrl);
          },
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
      // 设置文件选择回调
      androidController.setOnShowFileSelector(_handleFileSelection);
    }

    controller.addJavaScriptChannel(
      'Android',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message.startsWith('savePassword:')) {
          _handlePasswordSave(message.message);
        }
      },
    );

    return controller;
  }

  // 获取或创建自定义 WebView 控制器
  WebViewController _getCustomController(String url) {
    // 如果控制器存在但URL已更改，删除旧控制器并创建新的
    if (_customControllers.containsKey(url)) {
      return _customControllers[url]!;
    }

    // 创建新控制器
    _customControllers[url] = _createCustomController(url);
    return _customControllers[url]!;
  }

  // 处理文件选择
  Future<List<String>> _handleFileSelection(FileSelectorParams params) async {
    try {
      // 根据参数配置文件选择器
      FilePickerResult? result;

      // 判断是否接受多个文件
      final bool allowMultiple = params.mode == FileSelectorMode.openMultiple;

      // 判断文件类型
      if (params.acceptTypes.isNotEmpty) {
        // 如果指定了接受的文件类型
        final acceptTypes = params.acceptTypes;

        // 检查是否只接受图片
        final bool isImageOnly = acceptTypes.every((type) =>
          type.startsWith('image/') ||
          ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(type.toLowerCase())
        );

        // 检查是否只接受视频
        final bool isVideoOnly = acceptTypes.every((type) =>
          type.startsWith('video/') ||
          ['mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv', '.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv'].contains(type.toLowerCase())
        );

        // 检查是否只接受音频
        final bool isAudioOnly = acceptTypes.every((type) =>
          type.startsWith('audio/') ||
          ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac', '.mp3', '.wav', '.ogg', '.flac', '.m4a', '.aac'].contains(type.toLowerCase())
        );

        if (isImageOnly) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: allowMultiple,
          );
        } else if (isVideoOnly) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.video,
            allowMultiple: allowMultiple,
          );
        } else if (isAudioOnly) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: allowMultiple,
          );
        } else {
          // 提取所有允许的扩展名
          final List<String> allowedExtensions = [];
          for (final type in acceptTypes) {
            // 如果是扩展名格式 (如 .txt, .pdf)
            if (type.startsWith('.')) {
              allowedExtensions.add(type.substring(1));
            }
            // 如果是文件扩展名格式 (如 txt, pdf)
            else if (!type.contains('/')) {
              allowedExtensions.add(type);
            }
          }

          if (allowedExtensions.isNotEmpty) {
            result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: allowedExtensions,
              allowMultiple: allowMultiple,
            );
          } else {
            result = await FilePicker.platform.pickFiles(
              type: FileType.any,
              allowMultiple: allowMultiple,
            );
          }
        }
      } else {
        // 没有指定类型，允许选择任何文件
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: allowMultiple,
        );
      }

      // 返回选中的文件路径,转换为 file:// URI 格式
      if (result != null && result.files.isNotEmpty) {
        final List<String> filePaths = result.files
            .where((file) => file.path != null)
            .map((file) {
              final path = file.path!;
              // 如果路径已经是 file:// 开头,直接返回
              if (path.startsWith('file://')) {
                return path;
              }
              // 否则转换为 file:// URI
              // 在 Windows 上路径可能包含反斜杠,需要替换为正斜杠
              final normalizedPath = path.replaceAll('\\', '/');
              return 'file://$normalizedPath';
            })
            .toList();

        debugPrint('Selected files: $filePaths');
        return filePaths;
      }

      return [];
    } catch (e) {
      debugPrint('File selection error: $e');
      return [];
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

  void _disableZoom(WebViewController controller) {
    const String jsCode = '''
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        } else {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.head.appendChild(meta);
        }

        // 禁用双击缩放
        var lastTouchEnd = 0;
        document.addEventListener('touchend', function(event) {
          var now = Date.now();
          if (now - lastTouchEnd <= 300) {
            event.preventDefault();
          }
          lastTouchEnd = now;
        }, false);

        // 禁用手势缩放
        document.addEventListener('gesturestart', function(event) {
          event.preventDefault();
        }, false);
      })();
    ''';
    controller.runJavaScript(jsCode);
  }

  Future<void> _getClipboardData(WebViewController controller) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text ?? '';
    controller.runJavaScript('window.clipboardText = "$text";');
  }

  // 注入密码捕获和自动填充脚本
  void _injectPasswordScript(WebViewController controller, String url) {
    // 先尝试加载已保存的密码
    final savedPassword = PasswordManager.getPassword(url);

    final String jsCode = '''
      (function() {
        // 自动填充已保存的密码
        ${savedPassword != null ? '''
        function autoFillPassword() {
          const usernameFields = document.querySelectorAll('input[type="text"], input[type="email"], input[name*="user"], input[name*="account"], input[id*="user"], input[id*="account"]');
          const passwordFields = document.querySelectorAll('input[type="password"]');

          if (usernameFields.length > 0 && passwordFields.length > 0) {
            usernameFields[0].value = '${savedPassword['username']?.replaceAll("'", "\\'")}';
            passwordFields[0].value = '${savedPassword['password']?.replaceAll("'", "\\'")}';

            // 触发input事件，确保框架能检测到值变化
            usernameFields[0].dispatchEvent(new Event('input', { bubbles: true }));
            passwordFields[0].dispatchEvent(new Event('input', { bubbles: true }));
          }
        }

        // 页面加载完成后自动填充
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', autoFillPassword);
        } else {
          autoFillPassword();
        }

        // 延迟填充,确保动态表单也能被填充
        setTimeout(autoFillPassword, 500);
        setTimeout(autoFillPassword, 1000);
        ''' : ''}

        // 监听表单提交,捕获密码
        function capturePassword(event) {
          const form = event.target;
          const usernameField = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="account"], input[id*="user"], input[id*="account"]');
          const passwordField = form.querySelector('input[type="password"]');

          if (usernameField && passwordField) {
            const username = usernameField.value;
            const password = passwordField.value;

            if (username && password) {
              // 发送到Flutter端保存
              try {
                Android.postMessage('savePassword:' + JSON.stringify({
                  url: window.location.href,
                  username: username,
                  password: password
                }));
              } catch(e) {
                console.log('Failed to save password:', e);
              }
            }
          }
        }

        // 监听所有表单的submit事件
        document.addEventListener('submit', capturePassword, true);

        // 监听可能的登录按钮点击(某些页面不用form标签)
        document.addEventListener('click', function(event) {
          const target = event.target;
          // 检查是否是登录按钮
          if (target.tagName === 'BUTTON' || target.type === 'submit' ||
              target.textContent.includes('登录') || target.textContent.includes('Login') ||
              target.textContent.includes('Sign in') || target.textContent.includes('提交')) {

            setTimeout(function() {
              const passwordFields = document.querySelectorAll('input[type="password"]');
              if (passwordFields.length > 0) {
                const passwordField = passwordFields[0];
                const form = passwordField.closest('form') || passwordField.parentElement;
                const usernameField = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="account"], input[id*="user"], input[id*="account"]');

                if (usernameField && passwordField.value) {
                  try {
                    Android.postMessage('savePassword:' + JSON.stringify({
                      url: window.location.href,
                      username: usernameField.value,
                      password: passwordField.value
                    }));
                  } catch(e) {
                    console.log('Failed to save password:', e);
                  }
                }
              }
            }, 100);
          }
        }, true);
      })();
    ''';

    controller.runJavaScript(jsCode);
  }

  // 处理密码保存请求
  void _handlePasswordSave(String message) {
    try {
      // 消息格式: "savePassword:{json}"
      final jsonStr = message.substring('savePassword:'.length);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final url = data['url'] as String?;
      final username = data['username'] as String?;
      final password = data['password'] as String?;

      if (url != null && username != null && password != null) {
        PasswordManager.savePassword(
          url: url,
          username: username,
          password: password,
        );
        debugPrint('Password saved for: $url');
      }
    } catch (e) {
      debugPrint('Error saving password: $e');
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
            controller: _getCustomController(url),
          );
        }),
      ];

      // 计算设置页的索引（终端页在倒数第二，设置页在最后）
      final int settingsIndex = pages.length + 1;
      final int currentNavItemCount = pages.length + 2; // 总导航项数量

      // 最简单的逻辑：导航栏数量变化时，直接锁定焦点到最大值（设置页）
      int validCurrentIndex = _currentIndex;
      if (_previousNavItemCount != 0 && _previousNavItemCount != currentNavItemCount) {
        // 导航栏数量发生变化，锁定到设置页
        validCurrentIndex = settingsIndex;
        _previousNavItemCount = currentNavItemCount;
        // 异步更新状态
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentIndex = settingsIndex;
            });
          }
        });
      } else if (_previousNavItemCount == 0) {
        // 首次加载，记录导航栏数量
        _previousNavItemCount = currentNavItemCount;
      }

      return AnnotatedRegion<SystemUiOverlayStyle>(
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

                // 4. 终端页面
                TerminalView(
                  homeController.terminal,
                  readOnly: false,
                  backgroundOpacity: 1,
                  theme: ManjaroTerminalTheme(),
                ),

                // 5. 软件设置页面
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
      );
    });
  }
}
