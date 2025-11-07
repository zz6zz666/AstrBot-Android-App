import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:settings/settings.dart';
import 'package:xterm/xterm.dart';
import 'config.dart';
import 'generated/l10n.dart';
import 'script.dart';
import 'utils.dart';

class HomeController extends GetxController {
  SettingNode privacySetting = 'privacy'.setting;
  Pty? pseudoTerminal;
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

  File? progressFile;
  File progressDesFile = File('${RuntimeEnvir.tmpPath}/progress_des');
  double progress = 0.0;
  double step = 17; // 调整进度步骤数量
  String currentProgress = '';

  @override
  void onInit() {
    super.onInit();
    // 为 Google Play 上架做准备
    Future.delayed(Duration.zero, () async {
      if (privacySetting.get() == null) {
        // 隐私政策页面，这里简化处理
        terminal.writeProgress('请接受隐私政策以继续...');
        // 实际应用中应该跳转到隐私政策页面
        await Future.delayed(const Duration(seconds: 2));
        privacySetting.set(true);
      }
      syncProgress();
      initEnvir();
    });
  }

  // 同步当前进度
  void syncProgress() {
    progressFile?.createSync(recursive: true);
    progressFile?.writeAsStringSync('0');
    progressFile?.watch(events: FileSystemEvent.all).listen((event) async {
      if (event.type == FileSystemEvent.modify) {
        String content = await progressFile!.readAsString();
        if (content.isEmpty) {
          return;
        }
        try {
          progress = int.parse(content) / step;
          update();
        } catch (e) {
          print('解析进度失败: $e');
        }
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

  // 进度 +1
  void bumpProgress() {
    try {
      int current = 0;
      if (progressFile!.existsSync()) {
        final content = progressFile!.readAsStringSync().trim();
        if (content.isNotEmpty) {
          current = int.tryParse(content) ?? 0;
        }
      } else {
        progressFile!.createSync(recursive: true);
      }
      progressFile!.writeAsStringSync('${current + 1}');
    } catch (e) {
      progressFile?.writeAsStringSync('1');
    }
    update();
  }

  void setProgress(String description) {
    currentProgress = description;
    terminal.writeProgress(currentProgress);
  }

  // 初始化环境，将动态库中的文件链接到数据目录
  Future<void> initEnvir() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    progressFile = File('$appDocPath/progress');
    
    // 初始化系统库文件链接
    List<String> androidFiles = ['libbash.so', 'libbusybox.so', 'liblibtalloc.so.2.so', 'libloader.so', 'libproot.so', 'libsudo.so'];
    String libPath = await getLibPath();
    print('libPath -> $libPath');

    for (int i = 0; i < androidFiles.length; i++) {
      final sourcePath = '$libPath/${androidFiles[i]}';
      String fileName = androidFiles[i].replaceAll(RegExp('^lib|\\.so\$'), '');
      String filePath = '${RuntimeEnvir.binPath}/$fileName';
      File file = File(filePath);
      FileSystemEntityType type = await FileSystemEntity.type(filePath);
      print('$fileName type -> $type');
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.link) {
        await file.delete();
      }
      Link link = Link(filePath);
      if (link.existsSync()) {
        link.deleteSync();
      }
      try {
        print('create link -> $fileName ${link.path}');
        link.createSync(sourcePath);
      } catch (e) {
        print('安装链接失败: $e');
      }
    }
    
    // 调用修改后的load方法
    await loadCustomService();
  }

  Future<void> loadCustomService() async {
    // 创建运行时目录
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    Directory runtimeDir = Directory('$appDocPath/runtime');
    if (!runtimeDir.existsSync()) {
      runtimeDir.createSync(recursive: true);
    }

    // 创建相关文件夹
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    Directory(RuntimeEnvir.binPath).createSync(recursive: true);
    
    setProgress('正在创建终端对象...');
    pseudoTerminal = createPTY(rows: terminal.viewHeight, columns: terminal.viewWidth);
    bumpProgress();

    // 复制必要的资源文件
    setProgress('正在复制proot-distro...');
    try {
      // 复制proot-distro.zip
      ByteData prootDistroData = await rootBundle.load('assets/proot-distro.zip');
      List<int> prootDistroBytes = prootDistroData.buffer.asUint8List();
      File prootDistroFile = File('$appDocPath/runtime/proot-distro.zip');
      await prootDistroFile.writeAsBytes(prootDistroBytes);
    } catch (e) {
      terminal.write('复制proot-distro失败: $e\r\n');
    }
    bumpProgress();
    
    setProgress('正在复制Ubuntu系统镜像...');
    try {
      // 复制ubuntu系统镜像
      ByteData ubuntuData = await rootBundle.load('assets/${Config.ubuntuFileName}');
      List<int> ubuntuBytes = ubuntuData.buffer.asUint8List();
      File ubuntuFile = File('$appDocPath/runtime/${Config.ubuntuFileName}');
      await ubuntuFile.writeAsBytes(ubuntuBytes);
    } catch (e) {
      terminal.write('复制Ubuntu系统镜像失败: $e\r\n');
    }
    bumpProgress();
    
    setProgress('正在复制AstrBot文件...');
    try {
      // 复制AstrBot-4.5.4.zip
      ByteData astrBotData = await rootBundle.load('assets/${Config.astrBotFileName}');
      List<int> astrBotBytes = astrBotData.buffer.asUint8List();
      File astrBotFile = File('$appDocPath/runtime/${Config.astrBotFileName}');
      await astrBotFile.writeAsBytes(astrBotBytes);
    } catch (e) {
      terminal.write('复制AstrBot文件失败: $e\r\n');
    }
    bumpProgress();

    setProgress('正在创建busybox软链接...');
    createBusyboxLink();
    bumpProgress();

    // 生成启动脚本
    setProgress('正在生成启动脚本...');
    String astrBotStartWhenSuccessBind = '''
#!/data/data/${Config.packageName}/files/busybox sh
$start_custom_service''';

    // 写入启动脚本
    File scriptFile = File('$appDocPath/runtime/start.sh');
    scriptFile.writeAsStringSync(astrBotStartWhenSuccessBind);
    scriptFile.chmod(0755);
    bumpProgress();

    // 启动服务
    await startCustomService();
  }

  Future<void> startCustomService() async {
    // 启动自定义服务
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    String scriptPath = '$appDocPath/runtime/start.sh';

    try {
      // 监听终端输出
      Utf8Decoder decoder = const Utf8Decoder(allowMalformed: true);
      pseudoTerminal!.output.cast<List<int>>().transform(decoder).listen((event) {
        terminal.write(event);
        // 检查服务启动成功的标志
        if (event.contains('http://0.0.0.0:${Config.port}') || event.contains('AstrBot已成功') || event.contains('napcat已启动')) {
          if (!webviewHasOpen) {
            webviewHasOpen = true;
            // 实际应用中可以在这里打开WebView
            terminal.writeProgress('服务已成功启动！\r\n');
          }
        }
      });

      // 执行启动脚本
      pseudoTerminal!.writeString('sh $scriptPath\n');
    } catch (e) {
      terminal.write('启动服务失败: $e\r\n');
    }
  }

  // 创建 busybox 的软连接，来确保 proot-distro 会用到的命令正常运行
  void createBusyboxLink() {
    try {
      List<String> links = [
        ...['awk', 'ash', 'basename', 'bzip2', 'curl', 'cp', 'chmod', 'cut', 'cat', 'du', 'dd', 'find', 'grep', 'gzip'],
        ...['hexdump', 'head', 'id', 'lscpu', 'mkdir', 'realpath', 'rm', 'sed', 'stat', 'sh', 'tr', 'tar', 'uname', 'xargs', 'xz', 'xxd']
      ];

      for (String linkName in links) {
        Link link = Link('${RuntimeEnvir.binPath}/$linkName');
        if (!link.existsSync()) {
          try {
            link.createSync('${RuntimeEnvir.binPath}/busybox');
          } catch (e) {
            print('创建 $linkName 链接失败: $e');
          }
        }
      }
      // 尝试链接file命令
      try {
        Link link = Link('${RuntimeEnvir.binPath}/file');
        if (!link.existsSync()) {
          link.createSync('/system/bin/file');
        }
      } catch (e) {
        print('创建file链接失败: $e');
      }
    } catch (e) {
      print('创建busybox链接失败: $e');
    }
  }

  // 获取lib路径的辅助方法
  Future<String> getLibPath() async {
    String packageName = Config.packageName;
    return '/data/data/$packageName/files/lib';
  }
  
  // 创建PTY实例
  Pty createPTY({int rows = 24, int columns = 80}) {
    try {
      final pty = Pty.start(
        '${RuntimeEnvir.binPath}/sh',
        arguments: [],
        environment: {
          'PATH': '${RuntimeEnvir.binPath}:$PATH',
          'HOME': RuntimeEnvir.homePath,
          'TERM': 'xterm-color',
          'LC_ALL': 'C',
        },
        workingDirectory: RuntimeEnvir.homePath,
        columns: columns,
        rows: rows,
      );
      return pty;
    } catch (e) {
      print('创建PTY失败: $e');
      // 抛出异常以便上层处理
      rethrow;
    }
  }
}

// Terminal扩展方法，用于进度显示
extension TerminalProgress on Terminal {
  void writeProgress(String message) {
    final lines = message.split('\n');
    for (var line in lines) {
      write('\r\033[K$line');
    }
  }
}