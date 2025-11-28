import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:global_repository/global_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive_io.dart';
import '../../controllers/terminal_controller.dart';
import '../../../core/constants/scripts.dart' as scripts;

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
  String _appVersion = '';
  
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
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
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

  // 执行备份操作
  Future<bool> _performBackup() async {
    try {
      // 检查并请求存储权限
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // 如果 MANAGE_EXTERNAL_STORAGE 未授予，尝试传统的存储权限
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              Get.snackbar(
                '权限不足',
                '需要存储权限才能备份数据',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              return false;
            }
          }
        }
      }
      
      // 获取当前时间戳
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      
      // 备份文件路径（保存到下载文件夹）
      final backupDir = Directory('/storage/emulated/0/Download/AstrBot');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final backupFileName = 'AstrBot-backup-$timestamp.tar.gz';
      final backupPath = '${backupDir.path}/$backupFileName';
      
      // 数据目录路径
      final dataPath = '${scripts.ubuntuPath}/root/AstrBot/data';
      final dataDir = Directory(dataPath);
      
      if (!await dataDir.exists()) {
        Get.snackbar(
          '备份失败',
          'AstrBot 数据目录不存在',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
      
      // 使用 archive 包创建 tar.gz 压缩文件
      final encoder = TarFileEncoder();
      encoder.tarDirectory(dataDir, filename: backupPath);
      
      // 检查备份文件
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        final fileSize = await backupFile.length();
        final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
        
        Get.snackbar(
          '备份成功',
          '备份文件: $backupFileName\n大小: ${fileSizeMB}MB',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        Log.i('备份成功: $backupPath (${fileSizeMB}MB)', tag: 'AstrBot');
        return true;
      } else {
        Get.snackbar(
          '备份失败',
          '备份文件创建失败',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Log.e('备份失败: 文件不存在', tag: 'AstrBot');
        return false;
      }
    } catch (e) {
      Get.snackbar(
        '备份失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Log.e('备份异常: $e', tag: 'AstrBot');
      return false;
    }
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
    
    // 动态构建导航栏项目
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy),
        label: 'AstrBot',
      ),
      if (napCatEnabled)
        const BottomNavigationBarItem(
          icon: Icon(Icons.pets),
          label: 'NapCat',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: '设置',
      ),
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
                ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '设置',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('软件版本'),
                      subtitle: Text(_appVersion.isEmpty ? '加载中...' : 'AstrBot Android v$_appVersion'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('更新或重装 AstrBot'),
                      subtitle: const Text('清除 AstrBot 组件并重新安装最新版本'),
                      onTap: () async {
                        // 首先询问是否需要备份
                        final backupChoice = await Get.dialog<String>(
                          AlertDialog(
                            title: const Text('重新安装 AstrBot'),
                            content: const Text('重新安装将删除所有 AstrBot 数据，\n是否需要先备份当前数据？'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: 'cancel'),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: 'no_backup'),
                                child: const Text('直接重装', style: TextStyle(color: Colors.orange)),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: 'backup'),
                                child: const Text('备份后重装', style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                        );
                        
                        if (backupChoice == 'cancel' || backupChoice == null) {
                          return;
                        }
                        
                        // 如果选择备份，先执行备份
                        if (backupChoice == 'backup') {
                          Get.dialog(
                            const Center(child: CircularProgressIndicator()),
                            barrierDismissible: false,
                          );
                          
                          bool backupSuccess = false;
                          try {
                            backupSuccess = await _performBackup();
                          } finally {
                            Get.back(); // 关闭加载提示
                          }
                          
                          if (!backupSuccess) {
                            // 备份失败，询问是否继续
                            final continueAnyway = await Get.dialog<bool>(
                              AlertDialog(
                                title: const Text('备份失败'),
                                content: const Text('数据备份失败，是否仍要继续重新安装？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(result: false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Get.back(result: true),
                                    child: const Text('继续重装', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            
                            if (continueAnyway != true) {
                              return;
                            }
                          }
                        }
                        
                        // 最终确认重新安装
                        final finalConfirm = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('确认重新安装'),
                            content: const Text('确定要删除所有 AstrBot 数据并重新安装吗？\n此操作不可恢复！'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('确定重装', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        
                        if (finalConfirm == true) {
                          try {
                            // 删除 AstrBot 目录（~/AstrBot）
                            final astrBotPath = '${scripts.ubuntuPath}/root/AstrBot';
                            final astrBotDir = Directory(astrBotPath);
                            if (await astrBotDir.exists()) {
                              await astrBotDir.delete(recursive: true);
                              Log.i('已删除 AstrBot 目录: $astrBotPath', tag: 'AstrBot');
                            }
                            
                            if (context.mounted) {
                              Get.snackbar(
                                '重装成功',
                                '应用将自动退出，请重新启动',
                                snackPosition: SnackPosition.BOTTOM,
                                duration: const Duration(seconds: 2),
                              );
                              
                              // 2秒后自动退出应用
                              Future.delayed(const Duration(seconds: 2), () {
                                exit(0);
                              });
                            }
                          } catch (e) {
                            Log.e('重新安装 AstrBot 失败: $e', tag: 'AstrBot');
                            if (context.mounted) {
                              Get.snackbar(
                                '重新安装失败',
                                e.toString(),
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                            }
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('更新或重装 NapcatQQ'),
                      subtitle: const Text('清除 NapcatQQ 组件并重新安装最新版本'),
                      onTap: () async {
                        // 显示确认对话框
                        final confirm = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('确认重新安装'),
                            content: const Text('此操作将删除 NapcatQQ 安装文件（保留登录数据）并重新安装，确定继续吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('确定', style: TextStyle(color: Colors.orange)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          try {
                            // 删除 launcher.sh 文件，这是安装判断的依据
                            final launcherPath = '${scripts.ubuntuPath}/root/launcher.sh';
                            final launcherFile = File(launcherPath);
                            if (await launcherFile.exists()) {
                              await launcherFile.delete();
                              Log.i('已删除 launcher.sh: $launcherPath', tag: 'AstrBot');
                            }
                            
                            if (context.mounted) {
                              Get.snackbar(
                                '重装成功',
                                '应用将自动退出，请重新启动',
                                snackPosition: SnackPosition.BOTTOM,
                                duration: const Duration(seconds: 2),
                              );
                              
                              // 2秒后自动退出应用
                              Future.delayed(const Duration(seconds: 2), () {
                                exit(0);
                              });
                            }
                          } catch (e) {
                            Log.e('重新安装 NapcatQQ 失败: $e', tag: 'AstrBot');
                            if (context.mounted) {
                              Get.snackbar(
                                '重新安装失败',
                                e.toString(),
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                            }
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: const Text('前往 NapCat 仪表盘'),
                      subtitle: const Text('在 NapCat 仪表盘中管理 QQ 登录状态'),
                      onTap: () {
                        // 检查 NapCat WebUI 是否启用
                        final bool napCatEnabled = homeController.napCatWebUiEnabled.get() ?? false;
                        
                        if (!napCatEnabled) {
                          Get.snackbar(
                            '无法访问',
                            'NapCat WebUI 未启用，请先在下方开关中启用',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                          );
                          return;
                        }
                        
                        // 切换到 NapCat 标签页（索引 1）
                        setState(() {
                          _currentIndex = 1;
                        });
                        
                        Get.snackbar(
                          '已跳转',
                          '请在 NapCat 仪表盘中管理 QQ 登录',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.web),
                      title: const Text('NapCat WebUI'),
                      subtitle: const Text('启用或禁用 NapCat 网页控制面板（默认关闭）'),
                      trailing: Switch(
                        value: homeController.napCatWebUiEnabled.get() ?? false,
                        onChanged: (bool value) {
                          homeController.napCatWebUiEnabled.set(value);
                          
                          // 如果当前在 NapCat 页面且禁用了，切换到 AstrBot 页面
                          if (!value && _currentIndex == 1) {
                            _currentIndex = 0;
                          }
                          
                          // 重新初始化 NapCat controller
                          _initNapCatController();
                          
                          // 立即刷新 UI
                          setState(() {});
                          
                          Get.snackbar(
                            value ? 'WebUI 已启用' : 'WebUI 已禁用',
                            value 
                              ? 'NapCat 标签页已显示，可以立即访问控制面板'
                              : 'NapCat 标签页已隐藏',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('备份 AstrBot 数据'),
                      subtitle: const Text('备份 AstrBot 配置和数据到手机存储'),
                      onTap: () async {
                        Get.dialog(
                          const Center(child: CircularProgressIndicator()),
                          barrierDismissible: false,
                        );
                        
                        try {
                          await _performBackup();
                        } finally {
                          Get.back(); // 关闭加载提示
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('清空 WebView 缓存'),
                      subtitle: const Text('清理所有 WebView 浏览器缓存'),
                      onTap: () async {
                        try {
                          await _astrBotController.clearCache();
                          await _napCatController.clearCache();
                          if (context.mounted) {
                            Get.snackbar(
                              '成功',
                              'WebView 缓存已清理',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Get.snackbar(
                              '清理失败',
                              e.toString(),
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex >= navItems.length ? navItems.length - 1 : _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            items: navItems,
          ),
        ),
      ),
    );
  }
}
