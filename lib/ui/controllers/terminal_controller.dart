import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../generated/l10n.dart';
import '../../core/constants/scripts.dart';
import '../../core/utils/file_utils.dart';
import '../routes/app_routes.dart';
import 'terminal_tab_manager.dart';

class HomeController extends GetxController {
  // 终端标签页管理器
  late final TerminalTabManager terminalTabManager;
  // bool vsCodeStaring = false;
  SettingNode privacySetting = 'privacy'.setting;
  SettingNode napCatWebUiEnabled = 'napcat_webui_enabled'.setting;
  SettingNode showTerminalWhiteText = 'show_terminal_white_text'.setting;
  Pty? pseudoTerminal;
  Pty? napcatTerminal;

  final RxString napCatWebUiToken = ''.obs; // 存储 NapCat WebUI Token
  final RxBool _isQrcodeShowing = false.obs;
  final RxBool napCatWebUiEnabledRx = false.obs; // GetX 响应式变量用于导航栏更新
  final RxBool showTerminalWhiteTextRx = false.obs; // GetX 响应式变量用于设置页更新
  final RxList<Map<String, String>> customWebViews =
      <Map<String, String>>[].obs; // 自定义 WebView 列表
  Dialog? _qrcodeDialog;
  StreamSubscription? _qrcodeSubscription;
  StreamSubscription? _webviewSubscription; // 添加webview监听订阅

  late Terminal terminal = Terminal(
    maxLines: 10000,
    onResize: (width, height, pixelWidth, pixelHeight) {
      pseudoTerminal?.resize(height, width);
    },
    onOutput: (data) {
      pseudoTerminal?.writeString(data);
    },
  );
  bool webviewHasOpen = false;
  bool _isLocalhostDetected = false; // localhost:6185 检测标志
  bool _isQrcodeProcessed = false; // 二维码处理完成标志
  bool _isAppInForeground = true; // 应用是否在前台
  bool _isAstrBotConfiguring = false; // AstrBot 配置中标志，用于控制终端输出过滤
  String _pendingOutput = ''; // 待处理的输出缓冲

  File progressFile = File('${RuntimeEnvir.tmpPath}/progress');
  File progressDesFile = File('${RuntimeEnvir.tmpPath}/progress_des');
  double progress = 0.0;
  double step = 14.0;
  String currentProgress = '';

  // 进度 +1
  // Progress +1
  void bumpProgress() {
    try {
      int current = 0;
      if (progressFile.existsSync()) {
        final content = progressFile.readAsStringSync().trim();
        if (content.isNotEmpty) {
          current = int.tryParse(content) ?? 0;
        }
      } else {
        progressFile.createSync(recursive: true);
      }
      progressFile.writeAsStringSync('${current + 1}');
    } catch (e) {
      progressFile.writeAsStringSync('1');
    }
    update();
  }

  // 使用 login_ubuntu 函数，传入要执行的命令
  // Use login_ubuntu function, passing the command to execute
  String get command {
    return 'source ${RuntimeEnvir.homePath}/common.sh\nlogin_ubuntu "bash /root/launcher.sh"\n';
  }

  // 检测文本是否包含彩色 ANSI 代码(非白色/默认色)
  // Check if text contains colored ANSI codes (non-white/default)
  bool _hasColoredAnsiCode(String text) {
    // ANSI 彩色代码正则: \x1b[...m 或 \033[...m
    // 匹配所有颜色代码，排除白色(37)和重置代码(0)
    final ansiColorRegex = RegExp(
      r'\x1b\[([0-9;]+)m|\033\[([0-9;]+)m',
      multiLine: true,
    );

    final matches = ansiColorRegex.allMatches(text);
    for (var match in matches) {
      final code = match.group(1) ?? match.group(2) ?? '';
      // 检查是否包含颜色代码
      // 30-37: 前景色, 40-47: 背景色, 90-97: 高亮前景色, 100-107: 高亮背景色
      // 排除: 0(重置), 37(白色), 97(高亮白色)
      final codes = code.split(';');
      for (var c in codes) {
        final colorCode = int.tryParse(c.trim());
        if (colorCode != null) {
          // 有效的颜色代码(非白色且非重置)
          if ((colorCode >= 30 && colorCode <= 36) || // 前景色(黑到青)
              (colorCode >= 40 && colorCode <= 47) || // 背景色
              (colorCode >= 90 && colorCode <= 96) || // 高亮前景色(非白)
              (colorCode >= 100 && colorCode <= 107)) {
            // 高亮背景色
            return true;
          }
        }
      }
    }
    return false;
  }

  // 检测文本是否为纯彩色输出(不含白色文本)
  // Check if text is purely colored output (no white/default text)
  bool _isPurelyColoredOutput(String text) {
    // 移除所有 ANSI 代码后，检查是否还有可见文本
    final ansiRegex = RegExp(r'\x1b\[[0-9;]*m|\033\[[0-9;]*m');
    final cleanText = text.replaceAll(ansiRegex, '').trim();

    // 如果移除 ANSI 代码后没有可见文本，说明是纯 ANSI 控制序列
    if (cleanText.isEmpty) {
      return _hasColoredAnsiCode(text);
    }

    // 如果有可见文本但没有任何彩色代码，说明是纯白色文本
    if (!_hasColoredAnsiCode(text)) {
      return false;
    }

    // 关键判断：检查文本中是否所有可见内容都被彩色 ANSI 代码包裹
    // 策略：分段检查每个 ANSI 颜色代码后面的文本，直到遇到重置代码或下一个颜色代码
    final ansiColorRegex = RegExp(
      r'\x1b\[([0-9;]+)m|\033\[([0-9;]+)m',
      multiLine: true,
    );

    int lastIndex = 0;
    bool inColoredSection = false;
    bool hasUncoloredText = false;

    final matches = ansiColorRegex.allMatches(text).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];

      // 检查当前 ANSI 代码之前的文本
      if (match.start > lastIndex) {
        final textBefore = text.substring(lastIndex, match.start).trim();
        // 如果之前有文本且不在彩色段中，说明有未着色的白色文本
        if (textBefore.isNotEmpty && !inColoredSection) {
          hasUncoloredText = true;
          break;
        }
      }

      final code = match.group(1) ?? match.group(2) ?? '';
      final codes = code.split(';');

      // 检查这个 ANSI 代码是否是颜色代码(非白色)
      bool isColorCode = false;
      bool isResetCode = false;

      for (var c in codes) {
        final colorCode = int.tryParse(c.trim());
        if (colorCode != null) {
          if (colorCode == 0) {
            isResetCode = true;
          } else if ((colorCode >= 30 && colorCode <= 36) ||
              (colorCode >= 40 && colorCode <= 47) ||
              (colorCode >= 90 && colorCode <= 96) ||
              (colorCode >= 100 && colorCode <= 107)) {
            isColorCode = true;
          }
        }
      }

      if (isColorCode) {
        inColoredSection = true;
      } else if (isResetCode) {
        inColoredSection = false;
      }

      lastIndex = match.end;
    }

    // 检查最后一个 ANSI 代码之后的文本
    if (lastIndex < text.length) {
      final textAfter = text.substring(lastIndex).trim();
      if (textAfter.isNotEmpty && !inColoredSection) {
        hasUncoloredText = true;
      }
    }

    // 如果存在未着色的文本，说明不是纯彩色输出
    return !hasUncoloredText;
  }

  // 检测文本是否包含 ANSI 重置代码
  // Check if text contains ANSI reset code
  bool _hasResetCode(String text) {
    // 匹配重置代码: \x1b[0m 或 \033[0m
    final resetRegex = RegExp(r'\x1b\[0m|\033\[0m');
    return resetRegex.hasMatch(text);
  }

  // 处理彩色输出过滤逻辑
  // Handle colored output filtering logic
  void _processColoredOutput(String event) {
    _pendingOutput += event;

    // 检查设置：如果允许显示白色文本，则显示所有内容
    if (showTerminalWhiteText.get() == true) {
      terminal.write(event);
      return;
    }

    // 检查是否包含彩色代码和重置代码
    final isPurelyColored = _isPurelyColoredOutput(_pendingOutput);
    final hasReset = _hasResetCode(_pendingOutput);

    // 检查是否有完整的行(以换行符结尾)或者包含重置代码
    if (_pendingOutput.endsWith('\n') ||
        _pendingOutput.endsWith('\r\n') ||
        hasReset) {
      // 只有当输出是纯彩色的（不包含白色文本）时才输出
      if (isPurelyColored) {
        terminal.write(_pendingOutput);
      }
      // 清空缓冲
      _pendingOutput = '';
    }
  }

  // 检查两个条件是否都满足，如果满足则触发跳转
  void _checkAndNavigateToWebview() {
    // 只有当两个条件都满足且应用在前台时才跳转
    if (_isLocalhostDetected &&
        _isQrcodeProcessed &&
        _isAppInForeground &&
        !webviewHasOpen) {
      Future.microtask(() {
        // 使用路由跳转
        Get.toNamed(AppRoutes.webview);
        webviewHasOpen = true; // 只有真正打开webview时才设置为true
      });
    }
  }

  // 监听输出，当输出中包含启动成功的标志时，启动 VewView 和导航栏页面
  void initWebviewListener() {
    if (pseudoTerminal == null) return;

    _webviewSubscription = pseudoTerminal!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((event) async {
      // 输出到 Flutter 控制台
      // Output to Flutter console
      if (event.trim().isNotEmpty) {
        // 按行分割输出，避免控制台输出混乱
        final lines = event.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            Log.i(line, tag: 'AstrBot');
          }
        }
      }

      // 检查是否包含 localhost:6185
      if (event.contains('http://localhost:6185')) {
        _isLocalhostDetected = true;
        bumpProgress();

        // 检查是否两个条件都满足
        _checkAndNavigateToWebview();

        Future.delayed(const Duration(milliseconds: 2000), () {
          update();
        });

        // 不取消订阅，继续监听以便终端日志持续更新
      }

      // 只在 AstrBot 配置阶段才过滤非彩色输出
      // Only filter non-colored output after AstrBot configuration starts
      if (_isAstrBotConfiguring) {
        // 使用新的彩色输出处理逻辑,支持多行彩色输出
        _processColoredOutput(event);
      } else {
        // 配置前显示所有输出
        terminal.write(event);
      }
    });
  }

  void initQrcodeListener() {
    if (napcatTerminal == null) return;

    _qrcodeSubscription = napcatTerminal!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((event) async {
      // 先判断订阅是否已取消，避免重复处理
      if (_qrcodeSubscription == null) return;

      // 输出到 Flutter 控制台
      // Output to Flutter console
      if (event.trim().isNotEmpty) {
        // 按行分割输出，避免控制台输出混乱
        final lines = event.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            Log.i(line, tag: 'AstrBot-Napcat');
          }
        }
      }

      // 捕获 NapCat WebUI Token
      if (event.contains('WebUi Token:')) {
        final match = RegExp(r'WebUi Token:\s+(\w+)').firstMatch(event);
        if (match != null) {
          final token = match.group(1);
          if (token != null) {
            napCatWebUiToken.value = token;
            Log.i('捕获到 NapCat Token: $token', tag: 'AstrBot');
          }
        }
      }

      // 检测指令1显示二维码
      if (event.contains('二维码已保存到') && !_isQrcodeShowing.value) {
        _isQrcodeShowing.value = true;
        final qrcodePath = '$ubuntuPath/root/napcat/cache/qrcode.png';
        final qrcodeFile = File(qrcodePath);

        if (await qrcodeFile.exists()) {
          _qrcodeDialog = Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '请用手机QQ扫码登录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Image.file(
                    qrcodeFile,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          );

          // 使用GetX的导航管理避免上下文问题
          await Get.dialog(
            _qrcodeDialog!,
            barrierDismissible: false,
          );

          _isQrcodeShowing.value = false;
          _qrcodeDialog = null;
        } else {
          Get.showSnackbar(GetSnackBar(
            message: '二维码图片不存在：$qrcodePath',
            duration: const Duration(seconds: 3),
          ));
          _isQrcodeShowing.value = false;
        }
      }

      // 检测指令2关闭二维码并取消监听
      if (event.contains('配置加载') && _isQrcodeShowing.value) {
        // 关闭对话框
        if (_qrcodeDialog != null) {
          Get.back();
          _isQrcodeShowing.value = false;
          _qrcodeDialog = null;
        }

        // 标记二维码处理完成
        _isQrcodeProcessed = true;

        // 检查是否两个条件都满足
        _checkAndNavigateToWebview();

        // 取消订阅，后续不再监听任何指令
        await _qrcodeSubscription?.cancel();
        _qrcodeSubscription = null; // 置空标记已取消
      }

      // 检测指令3处理登录错误
      if (event.contains('Login Error') && _isQrcodeShowing.value) {
        // 关闭二维码对话框
        if (_qrcodeDialog != null) {
          Get.back();
          _isQrcodeShowing.value = false;
          _qrcodeDialog = null;
        }

        // 提取错误信息
        String errorMsg = '登录失败';
        if (event.contains('"message":"')) {
          final match = RegExp(r'"message":"([^"]+)"').firstMatch(event);
          if (match != null) {
            errorMsg = match.group(1) ?? errorMsg;
          }
        }

        // 显示错误提示
        Get.snackbar(
          'NapCat 登录失败',
          errorMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // 不取消订阅，允许用户重新扫码
      }
    });
  }

  // 初始化环境，将动态库中的文件链接到数据目录
  // Init environment and link files from the dynamic library to the data directory
  Future<void> initEnvir() async {
    List<String> androidFiles = [
      'libbash.so',
      'libbusybox.so',
      'liblibtalloc.so.2.so',
      'libloader.so',
      'libproot.so',
      'libsudo.so'
    ];
    String libPath = await getLibPath();
    Log.i('libPath -> $libPath');

    for (int i = 0; i < androidFiles.length; i++) {
      // when android target sdk > 28
      // cannot execute file in /data/data/com.xxx/files/usr/bin
      // so we need create a link to /data/data/com.xxx/files/usr/bin
      final sourcePath = '$libPath/${androidFiles[i]}';
      String fileName = androidFiles[i].replaceAll(RegExp('^lib|\\.so\$'), '');
      String filePath = '${RuntimeEnvir.binPath}/$fileName';
      // custom path, termux-api will invoke
      File file = File(filePath);
      FileSystemEntityType type = await FileSystemEntity.type(filePath);
      Log.i('$fileName type -> $type');
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.link) {
        // old version adb is plain file
        Log.i('find plain file -> $fileName, delete it');
        await file.delete();
      }
      Link link = Link(filePath);
      if (link.existsSync()) {
        link.deleteSync();
      }
      try {
        Log.i('create link -> $fileName ${link.path}');
        link.createSync(sourcePath);
      } catch (e) {
        Log.e('installAdbToEnvir error -> $e');
      }
    }
  }

  // 同步当前进度
  // Sync the current progress
  void syncProgress() {
    progressFile.createSync(recursive: true);
    progressFile.writeAsStringSync('0');
    progressFile.watch(events: FileSystemEvent.all).listen((event) async {
      if (event.type == FileSystemEvent.modify) {
        String content = await progressFile.readAsString();
        Log.e('content -> $content');
        if (content.isEmpty) {
          return;
        }
        progress = int.parse(content) / step;
        Log.e('progress -> $progress');
        update();
      }
    });
    progressDesFile.createSync(recursive: true);
    progressDesFile.writeAsStringSync('');
    progressDesFile.watch(events: FileSystemEvent.all).listen((event) async {
      if (event.type == FileSystemEvent.modify) {
        String content = await progressDesFile.readAsString();
        currentProgress = content;

        // 当进度到达 "Napcat 已安装" 时，启动 NapCat 终端
        if (content.contains('Napcat ${S.current.installed}')) {
          napcatTerminal?.writeString('$command\n');
          bumpProgress();
          Log.i('检测到 Napcat 已安装，启动 NapCat 终端', tag: 'AstrBot');
        }

        // 当进度到达 "AstrBot 配置中" 时，开始过滤非彩色输出并清除终端
        if (content.trim() == 'AstrBot 配置中') {
          _isAstrBotConfiguring = true;
          // 清除终端先前显示的所有文本
          terminal.buffer.clear();
          terminal.buffer.setCursor(0, 0);
          Log.i('检测到 AstrBot 配置中，清除终端内容并开始过滤非彩色终端输出', tag: 'AstrBot');
        }

        update();
      }
    });
  }

  // 创建 busybox 的软连接，来确保 proot 会用到的命令正常运行
  // create busybox symlinks, to ensure proot can use the commands normally
  void createBusyboxLink() {
    try {
      List<String> links = [
        ...[
          'awk',
          'ash',
          'basename',
          'bzip2',
          'curl',
          'cp',
          'chmod',
          'cut',
          'cat',
          'du',
          'dd',
          'find',
          'grep',
          'gzip'
        ],
        ...[
          'hexdump',
          'head',
          'id',
          'lscpu',
          'mkdir',
          'realpath',
          'rm',
          'sed',
          'stat',
          'sh',
          'tr',
          'tar',
          'uname',
          'xargs',
          'xz',
          'xxd'
        ]
      ];

      for (String linkName in links) {
        Link link = Link('${RuntimeEnvir.binPath}/$linkName');
        if (!link.existsSync()) {
          link.createSync('${RuntimeEnvir.binPath}/busybox');
        }
      }
      Link link = Link('${RuntimeEnvir.binPath}/file');
      link.createSync('/system/bin/file');
    } catch (e) {
      Log.e('Create link failed -> $e');
    }
  }

  void setProgress(String description) {
    currentProgress = description;
    terminal.writeProgress(currentProgress);
  }

  Future<void> loadAstrBot() async {
    syncProgress();

    // 创建相关文件夹
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    Directory(RuntimeEnvir.binPath).createSync(recursive: true);

    await initEnvir();
    createBusyboxLink();

    // 创建终端
    pseudoTerminal =
        createPTY(rows: terminal.viewHeight, columns: terminal.viewWidth);
    napcatTerminal = createPTY();

    // 复制必要的文件
    setProgress('复制 Ubuntu 系统镜像...');
    await AssetsUtils.copyAssetToPath('assets/${Config.ubuntuFileName}',
        '${RuntimeEnvir.homePath}/${Config.ubuntuFileName}');
    await AssetsUtils.copyAssetToPath('assets/astrbot-startup.sh',
        '${RuntimeEnvir.homePath}/astrbot-startup.sh');
    await AssetsUtils.copyAssetToPath(
        'assets/cmd_config.json', '${RuntimeEnvir.homePath}/cmd_config.json');
    bumpProgress();

    // 写入并执行脚本
    File('${RuntimeEnvir.homePath}/common.sh').writeAsStringSync(commonScript);

    initWebviewListener();
    bumpProgress();

    initQrcodeListener();

    startAstrBot(pseudoTerminal!);
  }

  Future<void> startAstrBot(Pty pseudoTerminal) async {
    setProgress('开始安装 AstrBot...');
    pseudoTerminal.writeString(
        'source ${RuntimeEnvir.homePath}/common.sh\nstart_astrbot\n');
  }

  @override
  void onInit() {
    super.onInit();

    // 初始化终端标签页管理器
    terminalTabManager = TerminalTabManager();

    // 初始化 NapCat WebUI 启用状态
    napCatWebUiEnabledRx.value = napCatWebUiEnabled.get() ?? false;

    // 初始化显示终端白色文本状态
    showTerminalWhiteTextRx.value = showTerminalWhiteText.get() ?? false;

    // 从持久化存储加载自定义 WebView 列表
    _loadCustomWebViews();

    // 为 Google Play 上架做准备
    // For Google Play
    Future.delayed(Duration.zero, () async {
      if (privacySetting.get() == null) {
        await Get.to(PrivacyAgreePage(
          onAgreeTap: () {
            privacySetting.set(true);
            Get.back();
          },
        ));
      }

      // 加载并启动 AstrBot
      loadAstrBot();

      // 在终端创建完成后初始化固定标签页
      // 等待terminal创建完成
      Future.delayed(const Duration(milliseconds: 500), () {
        terminalTabManager.initializeFixedTab(terminal);
      });
    });

    // 监听应用生命周期状态变化
    WidgetsBinding.instance.addObserver(
      LifecycleObserver(
        onResume: () {
          _isAppInForeground = true;
          // 当应用回到前台且两个条件都满足但webview未打开时，打开webview
          if (_isLocalhostDetected && _isQrcodeProcessed && !webviewHasOpen) {
            Future.microtask(() {
              Get.toNamed(AppRoutes.webview);
              webviewHasOpen = true;
            });
          }
        },
        onPause: () {
          _isAppInForeground = false;
        },
      ),
    );
  }

  // 加载自定义 WebView 列表
  void _loadCustomWebViews() {
    final stored = box!.get('custom_webviews', defaultValue: <dynamic>[]);
    if (stored is List) {
      customWebViews.value = stored.map((e) {
        if (e is Map) {
          return {
            'title': e['title']?.toString() ?? '',
            'url': e['url']?.toString() ?? '',
          };
        }
        return <String, String>{};
      }).toList();
    }
  }

  // 保存自定义 WebView 列表
  void _saveCustomWebViews() {
    box!.put('custom_webviews', customWebViews.toList());
  }

  // 添加自定义 WebView
  void addCustomWebView(String title, String url) {
    customWebViews.add({'title': title, 'url': url});
    _saveCustomWebViews();
  }

  // 删除自定义 WebView
  void removeCustomWebView(int index) {
    if (index >= 0 && index < customWebViews.length) {
      customWebViews.removeAt(index);
      _saveCustomWebViews();
    }
  }

  // 更新自定义 WebView
  void updateCustomWebView(int index, String title, String url) {
    if (index >= 0 && index < customWebViews.length) {
      customWebViews[index] = {'title': title, 'url': url};
      _saveCustomWebViews();
    }
  }

  // 更新 NapCat WebUI 启用状态（用于同步响应式变量）
  void setNapCatWebUiEnabled(bool value) {
    napCatWebUiEnabled.set(value);
    napCatWebUiEnabledRx.value = value;
  }

  // 更新显示终端白色文本状态（用于同步响应式变量）
  void setShowTerminalWhiteText(bool value) {
    showTerminalWhiteText.set(value);
    showTerminalWhiteTextRx.value = value;
  }

  @override
  void onClose() {
    // 清理订阅，避免内存泄漏
    _qrcodeSubscription?.cancel();
    _webviewSubscription?.cancel();
    _qrcodeSubscription = null;
    _webviewSubscription = null;

    // 杀死所有终端进程，释放端口
    try {
      if (pseudoTerminal != null) {
        Log.i('正在关闭主终端进程...', tag: 'AstrBot');
        pseudoTerminal?.kill();
        pseudoTerminal = null;
      }
      if (napcatTerminal != null) {
        Log.i('正在关闭 NapCat 终端进程...', tag: 'AstrBot-Napcat');
        napcatTerminal?.kill();
        napcatTerminal = null;
      }
    } catch (e) {
      Log.e('关闭终端进程时出错: $e', tag: 'AstrBot');
    }

    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(
      LifecycleObserver(
        onResume: () {},
        onPause: () {},
      ),
    );
    super.onClose();
  }
}

// 应用生命周期观察者类
class LifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;

  LifecycleObserver({required this.onResume, required this.onPause});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.paused:
        onPause();
        break;
      default:
        break;
    }
  }
}
