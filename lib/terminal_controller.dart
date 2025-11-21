import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';
import 'package:xterm/xterm.dart';
import 'config.dart';
import 'generated/l10n.dart';
import 'script.dart';
import 'utils.dart';
import 'package:flutter/material.dart'; // 引入Dialog等UI组件

class HomeController extends GetxController {
  // bool vsCodeStaring = false;
  SettingNode privacySetting = 'privacy'.setting;
  Pty? pseudoTerminal;
  Pty? napcatTerminal;

  final RxBool _isQrcodeShowing = false.obs;
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
  bool _isAdapterConnected = false; // 适配器连接标志
  bool _isAppInForeground = true; // 应用是否在前台

  File progressFile = File('${RuntimeEnvir.tmpPath}/progress');
  File progressDesFile = File('${RuntimeEnvir.tmpPath}/progress_des');
  double progress = 0.0;
  double step = 13.0;
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
  String get command => 'source ${RuntimeEnvir.homePath}/common.sh\nlogin_ubuntu "\$*\nbash launcher.sh"\n';

  // 监听输出，当输出中包含启动成功的标志时，启动 Code Server
  // Listen for output and start the Code Server when the success flag is detected
  void initWebviewListener() {
    if (pseudoTerminal == null) return;

    _webviewSubscription = pseudoTerminal!.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((event) async {
      // 先判断订阅是否已取消，避免重复处理
      if (_webviewSubscription == null) return;

      // 输出到 Flutter 控制台
      // Output to Flutter console
      if (event.trim().isNotEmpty) {
        // 按行分割输出，避免控制台输出混乱
        final lines = event.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            print('[AstrBot Script] $line');
            Log.i(line, tag: 'AstrBot');
          }
        }
      }

      if (event.contains('Napcat ${S.current.installed}')) {
        napcatTerminal?.writeString('$command\n');
        bumpProgress();
      }

      // 检查是否包含适配器连接成功的标志
      if (event.contains('适配器已连接')) {
        _isAdapterConnected = true;
        bumpProgress();
        
        // 如果应用当前在前台，则立即打开webview
        if (_isAppInForeground) {
          Future.microtask(() {
            openWebView();
            webviewHasOpen = true; // 只有真正打开webview时才设置为true
          });
        }

        Future.delayed(const Duration(milliseconds: 2000), () {
          update();
        });

        // 取消订阅，后续不再监听
        await _webviewSubscription?.cancel();
        _webviewSubscription = null; // 置空标记已取消
      }
      terminal.write(event);
    });
  }

  void initQrcodeListener() {
    if (napcatTerminal == null) return;

    _qrcodeSubscription = napcatTerminal!.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((event) async {
      // 先判断订阅是否已取消，避免重复处理
      if (_qrcodeSubscription == null) return;

      // 输出到 Flutter 控制台
      // Output to Flutter console
      if (event.trim().isNotEmpty) {
        // 按行分割输出，避免控制台输出混乱
        final lines = event.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            print('[AstrBot Napcat] $line');
            Log.i(line, tag: 'AstrBot-Napcat');
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

        // 取消订阅，后续不再监听任何指令
        await _qrcodeSubscription?.cancel();
        _qrcodeSubscription = null; // 置空标记已取消
      }
    });
  }

  // 初始化环境，将动态库中的文件链接到数据目录
  // Init environment and link files from the dynamic library to the data directory
  Future<void> initEnvir() async {
    List<String> androidFiles = ['libbash.so', 'libbusybox.so', 'liblibtalloc.so.2.so', 'libloader.so', 'libproot.so', 'libsudo.so'];
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
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.link) {
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
        update();
      }
    });
  }

  // 创建 busybox 的软连接，来确保 proot 会用到的命令正常运行
  // create busybox symlinks, to ensure proot can use the commands normally
  void createBusyboxLink() {
    try {
      List<String> links = [
        ...['awk', 'ash', 'basename', 'bzip2', 'curl', 'cp', 'chmod', 'cut', 'cat', 'du', 'dd', 'find', 'grep', 'gzip'],
        ...['hexdump', 'head', 'id', 'lscpu', 'mkdir', 'realpath', 'rm', 'sed', 'stat', 'sh', 'tr', 'tar', 'uname', 'xargs', 'xz', 'xxd']
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
    pseudoTerminal = createPTY(rows: terminal.viewHeight, columns: terminal.viewWidth);
    napcatTerminal = createPTY();

    // 复制必要的文件
    setProgress('复制 Ubuntu 系统镜像...');
    await AssetsUtils.copyAssetToPath('assets/${Config.ubuntuFileName}', '${RuntimeEnvir.homePath}/${Config.ubuntuFileName}');
    await AssetsUtils.copyAssetToPath('assets/astrbot-startup.sh', '${RuntimeEnvir.homePath}/astrbot-startup.sh');
    await AssetsUtils.copyAssetToPath('assets/cmd_config.json', '${RuntimeEnvir.homePath}/cmd_config.json');
    bumpProgress();

    // 写入并执行脚本
    File('${RuntimeEnvir.homePath}/common.sh').writeAsStringSync('$commonScript');

    initWebviewListener();
    bumpProgress();

    initQrcodeListener();
    napcatTerminal?.writeString('$command\n');

    startAstrBot(pseudoTerminal!);
  }

  Future<void> startAstrBot(Pty pseudoTerminal) async {
    setProgress('开始安装 AstrBot...');
    pseudoTerminal.writeString('source ${RuntimeEnvir.homePath}/common.sh\nstart_astrbot\n');
  }

  @override
  void onInit() {
    super.onInit();
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
    });
    
    // 监听应用生命周期状态变化
    WidgetsBinding.instance.addObserver(
      LifecycleObserver(
        onResume: () {
          _isAppInForeground = true;
          // 当应用回到前台且适配器已连接但webview未打开时，打开webview
          if (_isAdapterConnected && !webviewHasOpen) {
            Future.microtask(() {
              openWebView();
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

  @override
  void onClose() {
    // 清理订阅，避免内存泄漏
    _qrcodeSubscription?.cancel();
    _webviewSubscription?.cancel();
    _qrcodeSubscription = null;
    _webviewSubscription = null;
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
