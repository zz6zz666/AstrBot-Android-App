import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:global_repository/global_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../controllers/terminal_controller.dart';
import '../../../core/constants/scripts.dart' as scripts;
import '../../../core/services/password_manager.dart';
import '../../../core/config/app_config.dart';

class SettingsPage extends StatefulWidget {
  final WebViewController astrBotController;
  final WebViewController napCatController;
  final Function(int) onNavigate;

  const SettingsPage({
    super.key,
    required this.astrBotController,
    required this.napCatController,
    required this.onNavigate,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';
  bool _isBatteryOptimizationIgnored = false;
  final HomeController homeController = Get.find<HomeController>();

  // 存储从GitHub API获取的原始下载URL
  String? _originalDownloadUrl;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _checkBatteryOptimizationStatus();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  // 检查电池优化豁免状态
  Future<void> _checkBatteryOptimizationStatus() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      setState(() {
        _isBatteryOptimizationIgnored = status.isGranted;
      });
    } catch (e) {
      Log.e('检查电池优化豁免状态失败: $e', tag: 'AstrBot');
    }
  }

  // 请求电池优化豁免
  Future<void> _requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;

      if (status.isGranted) {
        Get.snackbar(
          '已授权',
          '已获得电池优化豁免权限',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // 请求权限
      final result = await Permission.ignoreBatteryOptimizations.request();

      // 等待对话框关闭后重新检查状态
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkBatteryOptimizationStatus();

      if (result.isGranted) {
        Get.snackbar(
          '授权成功',
          '已获得电池优化豁免权限',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '授权失败',
          '未获得电池优化豁免权限',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Log.e('请求电池优化豁免失败: $e', tag: 'AstrBot');
      Get.snackbar(
        '请求失败',
        '请求电池优化豁免时发生错误: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // 检查更新
  Future<void> _checkForUpdates() async {
    try {
      // 每次检查更新时重置原始URL
      _originalDownloadUrl = null;

      // 显示加载提示
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 使用镜像源获取最新版本信息
      final mirrors = [
        ...Config.githubApiMirrors.map((mirror) =>
            '$mirror/${Config.githubApi}${Config.githubReleasesPath}'),
        '${Config.githubApi}${Config.githubReleasesPath}',
      ];

      Map<String, dynamic>? releaseData;

      for (final mirror in mirrors) {
        try {
          final response = await http.get(
            Uri.parse(mirror),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            releaseData = jsonDecode(response.body) as Map<String, dynamic>;
            break;
          }
        } catch (e) {
          Log.w('镜像源 $mirror 请求失败: $e', tag: 'AstrBot');
          continue;
        }
      }

      Get.back(); // 关闭加载提示

      if (releaseData == null) {
        Get.snackbar(
          '检查失败',
          '无法连接到更新服务器',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // 解析最新版本号
      final latestVersion =
          (releaseData['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      final releaseNotes = releaseData['body'] as String? ?? '暂无更新说明';

      // 比较版本号
      if (_compareVersions(latestVersion, currentVersion) > 0) {
        // 有新版本，显示更新对话框
        _showUpdateDialog(latestVersion, releaseNotes, releaseData);
      } else {
        Get.snackbar(
          '已是最新版本',
          '当前版本 $currentVersion 已是最新版本',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.back(); // 关闭加载提示
      Log.e('检查更新失败: $e', tag: 'AstrBot');
      Get.snackbar(
        '检查失败',
        '检查更新时发生错误: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // 版本号比较
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  // 显示更新对话框
  void _showUpdateDialog(
      String version, String releaseNotes, Map<String, dynamic> releaseData) {
    Get.dialog(
      Dialog(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    '发现新版本 $version',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: MarkdownBody(
                  data: releaseNotes,
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    h2: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    h3: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    p: const TextStyle(fontSize: 14),
                    listBullet: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _showDownloadSourceDialog(releaseData);
                    },
                    child: const Text('去下载'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示下载源选择对话框
  void _showDownloadSourceDialog(Map<String, dynamic> releaseData) {
    // 如果还没有保存原始URL，从releaseData中构造
    if (_originalDownloadUrl == null) {
      final assets = releaseData['assets'] as List?;
      final tagName = releaseData['tag_name'] as String?;

      if (tagName == null || assets == null) {
        Get.snackbar(
          '下载失败',
          '未找到版本信息',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // 查找APK文件名
      String? apkFileName;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkFileName = name;
          break;
        }
      }

      if (apkFileName == null) {
        Get.snackbar(
          '下载失败',
          '未找到可下载的APK文件',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // 直接构造GitHub原始下载链接，避免使用可能被镜像站污染的URL
      _originalDownloadUrl =
          '${Config.githubDownloadBase}/$tagName/$apkFileName';
    }

    // 使用原始URL构建各个镜像源的下载链接
    final sources = [
      ...Config.downloadMirrors.map((mirror) => {
            'name': mirror['name']!,
            'icon':
                mirror['icon'] == 'speed' ? Icons.speed : Icons.cloud_download,
            'url': '${mirror['url']}/$_originalDownloadUrl',
          }),
      {
        'name': 'GitHub原始链接',
        'icon': Icons.cloud_download,
        'url': _originalDownloadUrl!,
        'description': '直接从GitHub官方服务器下载，速度可能较慢',
      },
    ];

    Get.dialog(
      AlertDialog(
        title: const Text('选择下载源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请选择适合您网络环境的下载源',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...sources.map((source) {
              return ListTile(
                leading: Icon(source['icon'] as IconData),
                title: Text(source['name'] as String),
                subtitle: source['description'] != null
                    ? Text(
                        source['description'] as String,
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
                onTap: () async {
                  final url = source['url'] as String;
                  final uri = Uri.parse(url);

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    Get.back();
                  } else {
                    Get.snackbar(
                      '打开失败',
                      '无法打开浏览器',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 显示添加自定义 WebView 对话框
  void _showAddWebViewDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('添加自定义 WebView'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '例如：我的仪表盘',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: '例如：6099/webui?token=***',
                helperText: '自动添加前缀 http://127.0.0.1: \n若需使用https，请手动输入完整URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              var url = urlController.text.trim();

              if (title.isEmpty || url.isEmpty) {
                Get.snackbar(
                  '输入错误',
                  '标题和 URL 不能为空',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                return;
              }

              // 如果URL不包含协议前缀,自动添加 http://127.0.0.1:
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'http://127.0.0.1:$url';
              }

              homeController.addCustomWebView(title, url);
              Get.back();

              Get.snackbar(
                '添加成功',
                '自定义 WebView "$title" 已添加',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 显示编辑自定义 WebView 对话框
  void _showEditWebViewDialog(int index, Map<String, String> webview) {
    final titleController = TextEditingController(text: webview['title']);

    // 将完整URL转换为简化格式用于编辑
    String displayUrl = webview['url'] ?? '';
    if (displayUrl.startsWith('https://127.0.0.1:')) {
      displayUrl = displayUrl.substring('https://127.0.0.1:'.length);
    } else if (displayUrl.startsWith('http://127.0.0.1:')) {
      displayUrl = displayUrl.substring('http://127.0.0.1:'.length);
    }

    final urlController = TextEditingController(text: displayUrl);

    Get.dialog(
      AlertDialog(
        title: const Text('编辑自定义 WebView'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                helperText: '自动添加前缀 http://127.0.0.1: \n若需使用https,请手动输入完整URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              var url = urlController.text.trim();

              if (title.isEmpty || url.isEmpty) {
                Get.snackbar(
                  '输入错误',
                  '标题和 URL 不能为空',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                return;
              }

              // 如果URL不包含协议前缀,自动添加 http://127.0.0.1:
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'http://127.0.0.1:$url';
              }

              homeController.updateCustomWebView(index, title, url);
              Get.back();

              Get.snackbar(
                '更新成功',
                '自定义 WebView 已更新',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 确认删除自定义 WebView
  void _confirmDeleteWebView(int index, String title) {
    Get.dialog(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除自定义 WebView "$title" 吗？'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              homeController.removeCustomWebView(index);
              Get.back();

              Get.snackbar(
                '删除成功',
                '自定义 WebView "$title" 已删除',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 执行备份操作
  Future<bool> _performBackup({bool showLoadingDialog = false}) async {
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

      // 权限获取成功后，如果需要显示加载对话框
      if (showLoadingDialog) {
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );
      }

      // 获取当前时间戳
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // 备份文件路径（保存到下载文件夹）
      final backupDir = Directory('/storage/emulated/0/Download/AstrBot');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupFileName = 'AstrBot-backup-$timestamp.tar.gz';
      final backupPath = '${backupDir.path}/$backupFileName';

      // 使用 tar 命令压缩 data 目录
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

      // 执行备份命令
      final result = await Process.run('${RuntimeEnvir.binPath}/busybox', [
        'tar',
        '-czf',
        backupPath,
        '-C',
        '${scripts.ubuntuPath}/root/AstrBot',
        'data',
      ]);

      if (result.exitCode == 0) {
        final backupFile = File(backupPath);
        final fileSize = await backupFile.length();
        final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);

        if (showLoadingDialog) {
          Get.back(); // 关闭加载对话框
        }

        Get.snackbar(
          '备份成功',
          '备份文件: $backupFileName\n大小: ${fileSizeMB}MB',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        Log.i('备份成功: $backupPath (${fileSizeMB}MB)', tag: 'AstrBot');
        return true;
      } else {
        if (showLoadingDialog) {
          Get.back(); // 关闭加载对话框
        }

        Get.snackbar(
          '备份失败',
          '错误: ${result.stderr}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Log.e('备份失败: ${result.stderr}', tag: 'AstrBot');
        return false;
      }
    } catch (e) {
      if (showLoadingDialog) {
        Get.back(); // 关闭加载对话框
      }

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

  // 显示快速登录QQ对话框
  void _showQuickLoginDialog() async {
    final webuiJsonPath = '${scripts.ubuntuPath}/root/napcat/config/webui.json';
    final webuiJsonFile = File(webuiJsonPath);

    // 检查文件是否存在
    if (!await webuiJsonFile.exists()) {
      Get.snackbar(
        '错误',
        'webui.json 文件不存在',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // 读取并解析 JSON 文件
    String currentQQ = '';
    Map<String, dynamic> jsonData;
    try {
      final jsonContent = await webuiJsonFile.readAsString();
      jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;

      // 检查是否存在 autoLoginAccount 字段
      if (!jsonData.containsKey('autoLoginAccount')) {
        Get.snackbar(
          '错误',
          '未找到 autoLoginAccount 字段',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      currentQQ = jsonData['autoLoginAccount']?.toString() ?? '';
    } catch (e) {
      Get.snackbar(
        '错误',
        '读取或解析 webui.json 失败: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // 显示编辑对话框
    final qqController = TextEditingController(text: currentQQ);

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('快速登录 QQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qqController,
              decoration: const InputDecoration(
                labelText: 'QQ号',
                hintText: '请输入QQ号',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // 如果用户点击了保存
    if (result == true) {
      final newQQ = qqController.text.trim();

      try {
        // 更新 JSON 数据
        jsonData['autoLoginAccount'] = newQQ;

        // 写回文件
        await webuiJsonFile.writeAsString(
          const JsonEncoder.withIndent('    ').convert(jsonData),
        );

        Get.snackbar(
          '保存成功',
          'QQ号已更新为: $newQQ',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        Log.i('自动登录QQ号已更新: $newQQ', tag: 'AstrBot');
      } catch (e) {
        Get.snackbar(
          '保存失败',
          '写入 webui.json 失败: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        Log.e('保存自动登录QQ号失败: $e', tag: 'AstrBot');
      }
    }

    qqController.dispose();
  }

  // 显示自定义 Git Clone 对话框
  void _showCustomGitCloneDialog() async {
    final scriptPath = '${scripts.ubuntuPath}/root/astrbot-startup.sh';
    final scriptFile = File(scriptPath);

    // 检查脚本文件是否存在
    if (!await scriptFile.exists()) {
      Get.snackbar(
        '提示',
        '启动脚本文件不存在，请先启动一次应用',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // 读取当前的自定义 Git Clone 命令
    String currentCommand = '';
    try {
      final content = await scriptFile.readAsString();
      final match = RegExp(r'^CUSTOM_GIT_CLONE="([^"]*)"$', multiLine: true)
          .firstMatch(content);
      if (match != null) {
        currentCommand = match.group(1) ?? '';
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '读取启动脚本失败: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // 显示编辑对话框
    final commandController = TextEditingController(text: currentCommand);

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('自定义 Git Clone 命令'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '自定义克隆命令，以使用 fork 的 AstrBot 仓库；目标目录固定为 AstrBot，不可自定义。\n留空则使用默认逻辑（从镜像源获取官方最新 tag）。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '示例：\ngit clone https://github.com/AstrBotDevs/AstrBot.git',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commandController,
                decoration: const InputDecoration(
                  labelText: 'Git Clone 命令',
                  hintText: '留空使用默认逻辑',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newCommand = commandController.text.trim();

      try {
        String content = await scriptFile.readAsString();

        // 替换 CUSTOM_GIT_CLONE 变量的值
        content = content.replaceFirst(
          RegExp(r'^CUSTOM_GIT_CLONE="[^"]*"$', multiLine: true),
          'CUSTOM_GIT_CLONE="$newCommand"',
        );

        await scriptFile.writeAsString(content);
        Log.i('已更新自定义 Git Clone 命令: $newCommand', tag: 'AstrBot');

        Get.snackbar(
          '保存成功',
          newCommand.isEmpty ? '已清除自定义命令，将使用默认逻辑' : '自定义 Git Clone 命令已保存',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        Get.snackbar(
          '保存失败',
          '写入启动脚本失败: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        Log.e('保存自定义 Git Clone 命令失败: $e', tag: 'AstrBot');
      }
    }

    commandController.dispose();
  }

  // 打开文件管理器并导航到 AstrBot Ubuntu 文件系统位置
  Future<void> _openFileManager() async {
    try {
      // 使用 DocumentsProvider 的 content URI 打开文件管理器
      // authority: com.astrbot.astrbot_android.documents
      // rootId: ubuntu_root
      final contentUri = Uri.parse(
        'content://com.astrbot.astrbot_android.documents/root/ubuntu_root',
      );

      if (await canLaunchUrl(contentUri)) {
        await launchUrl(
          contentUri,
          mode: LaunchMode.externalApplication,
        );

        Get.snackbar(
          '已打开',
          '已在文件管理器中打开 AstrBot Ubuntu 文件系统',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        // 如果无法打开，提供备选方案
        Get.dialog(
          AlertDialog(
            title: const Text('打开文件系统'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubuntu 文件系统已挂载至系统"文件"应用的侧栏，名称为:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AstrBot Ubuntu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '你可以手动打开系统"文件"应用，在侧栏中找到"AstrBot Ubuntu"来访问。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  '或使用 MT 文件管理器等应用，添加以下路径至侧栏:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  scripts.ubuntuPath,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: scripts.ubuntuPath));
                  Get.back();
                  Get.snackbar(
                    '已复制',
                    '路径已复制到剪贴板',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('复制路径'),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Log.e('打开文件管理器失败: $e', tag: 'AstrBot');
      Get.snackbar(
        '打开失败',
        '无法打开文件管理器: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
          subtitle: Text(
            _appVersion.isEmpty ? '加载中...' : '$_appVersion（点击检查更新）',
          ),
          onTap: () => _checkForUpdates(),
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('回到 AstrBot 主页'),
          subtitle: const Text('重置并刷新 AstrBot 页面'),
          onTap: () {
            // 重置 AstrBot WebView URL 并刷新
            widget.astrBotController.loadRequest(
              Uri.parse('http://127.0.0.1:6185'),
            );

            // 跳转到 AstrBot 标签页（索引 0）
            widget.onNavigate(0);

            Get.snackbar(
              '已跳转',
              'AstrBot 页面已重置并刷新',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          },
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
                    child: const Text(
                      '直接重装',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: 'backup'),
                    child: const Text(
                      '备份后重装',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            );

            if (backupChoice == 'cancel' || backupChoice == null) {
              return;
            }

            // 如果选择备份，先执行备份
            if (backupChoice == 'backup') {
              bool backupSuccess =
                  await _performBackup(showLoadingDialog: true);

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
                        child: const Text(
                          '继续重装',
                          style: TextStyle(color: Colors.red),
                        ),
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
                    child: const Text(
                      '确定重装',
                      style: TextStyle(color: Colors.red),
                    ),
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
                content: const Text('此操作将删除 NapcatQQ 安装文件（保留配置文件）并重新安装，确定继续吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: const Text(
                      '确定',
                      style: TextStyle(color: Colors.orange),
                    ),
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
          leading: const Icon(Icons.build),
          title: const Text('覆盖安装插件依赖'),
          subtitle: const Text('下次启动时重新扫描并安装所有插件依赖'),
          onTap: () async {
            try {
              final scriptPath =
                  '${scripts.ubuntuPath}/root/astrbot-startup.sh';
              final scriptFile = File(scriptPath);

              if (await scriptFile.exists()) {
                String content = await scriptFile.readAsString();

                // 将 REINSTALL_PLUGINS_FLAG=0 修改为 REINSTALL_PLUGINS_FLAG=1
                content = content.replaceFirst(
                  RegExp(r'^REINSTALL_PLUGINS_FLAG=0$', multiLine: true),
                  'REINSTALL_PLUGINS_FLAG=1',
                );

                await scriptFile.writeAsString(content);
                Log.i('已设置插件依赖重装标记', tag: 'AstrBot');

                Get.snackbar(
                  '设置成功',
                  '下次启动时将重新安装所有插件依赖',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              } else {
                Get.snackbar(
                  '提示',
                  '启动脚本文件不存在，请先启动一次应用',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              }
            } catch (e) {
              Log.e('设置重装标记失败: $e', tag: 'AstrBot');
              Get.snackbar(
                '操作失败',
                '设置重装标记失败: $e',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 3),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('备份 AstrBot 数据'),
          subtitle: const Text('备份 AstrBot 配置和数据到手机存储'),
          onTap: () async {
            await _performBackup(showLoadingDialog: true);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('清除 AstrBot 数据'),
          subtitle: const Text('清除 AstrBot 配置和数据，\n重启时自动从备份恢复或重新初始化'),
          onTap: () async {
            // 显示确认对话框
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: const Text('确认清除数据'),
                content: const Text(
                  '此操作将删除所有 AstrBot 数据和配置，\n'
                  '重启后将自动从备份恢复或重新初始化。\n\n'
                  '是否继续？',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: const Text(
                      '确定',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                final dataPath = '${scripts.ubuntuPath}/root/AstrBot/data';
                final dataDir = Directory(dataPath);

                if (await dataDir.exists()) {
                  await dataDir.delete(recursive: true);
                  Log.i('已清除 AstrBot 数据目录: $dataPath', tag: 'AstrBot');

                  Get.snackbar(
                    '清除成功',
                    'AstrBot 数据已清除，应用即将退出',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );

                  // 等待提示显示后退出应用
                  await Future.delayed(const Duration(seconds: 2));
                  exit(0);
                } else {
                  Get.snackbar(
                    '提示',
                    '数据目录不存在，无需清除',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                }
              } catch (e) {
                Log.e('清除 AstrBot 数据失败: $e', tag: 'AstrBot');
                Get.snackbar(
                  '操作失败',
                  '清除数据失败: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 3),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('重置 Python 环境'),
          subtitle: const Text('删除虚拟环境并重启应用，启动时将自动重建'),
          onTap: () async {
            // 显示确认对话框
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: const Text('确认重置'),
                content: const Text(
                  '此操作将删除 Python 虚拟环境（.venv 目录）并退出应用。\n'
                  '下次启动时会自动重建环境并安装所有插件依赖。\n\n'
                  '是否继续？',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: const Text(
                      '确定',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                final venvPath = '${scripts.ubuntuPath}/root/AstrBot/.venv';
                final venvDir = Directory(venvPath);

                if (await venvDir.exists()) {
                  await venvDir.delete(recursive: true);
                  Log.i('已删除 Python 虚拟环境: $venvPath', tag: 'AstrBot');

                  Get.snackbar(
                    '重置成功',
                    'Python 环境已删除，应用即将退出',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );

                  // 等待提示显示后退出应用
                  await Future.delayed(const Duration(seconds: 2));
                  exit(0);
                } else {
                  Get.snackbar(
                    '提示',
                    '虚拟环境目录不存在',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                }
              } catch (e) {
                Log.e('删除 Python 虚拟环境失败: $e', tag: 'AstrBot');
                Get.snackbar(
                  '操作失败',
                  '删除虚拟环境失败: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 3),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.login),
          title: const Text('快速登录 QQ'),
          subtitle: const Text('配置自动登录的QQ账号'),
          onTap: () => _showQuickLoginDialog(),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text(
                '自定义 WebView',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                onPressed: _showAddWebViewDialog,
                tooltip: '添加自定义 WebView',
              ),
            ],
          ),
        ),
        Obx(() {
          final customWebViews = homeController.customWebViews;
          if (customWebViews.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '访问插件的 WebUI 面板\n点击右上角"+"添加',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: List.generate(customWebViews.length, (index) {
              final webview = customWebViews[index];
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(webview['title'] ?? 'WebUI'),
                subtitle: Text(webview['url'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditWebViewDialog(index, webview),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _confirmDeleteWebView(
                        index,
                        webview['title'] ?? 'WebUI',
                      ),
                      tooltip: '删除',
                    ),
                  ],
                ),
              );
            }),
          );
        }),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '高级设置',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.battery_saver),
          title: const Text('电池优化豁免'),
          subtitle: Text(_isBatteryOptimizationIgnored ? '已授权' : '未授权（点击授权）'),
          trailing: _isBatteryOptimizationIgnored
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.warning, color: Colors.orange),
          onTap: () => _requestBatteryOptimization(),
        ),
        ListTile(
          leading: const Icon(Icons.web),
          title: const Text('NapCat WebUI'),
          subtitle: const Text('显示或隐藏 NapCat 网页控制面板（默认隐藏）'),
          trailing: Switch(
            value: homeController.napCatWebUiEnabled.get() ?? false,
            onChanged: (bool value) {
              // 使用新的方法来同步更新响应式变量
              homeController.setNapCatWebUiEnabled(value);

              Get.snackbar(
                value ? 'WebUI 已启用' : 'WebUI 已禁用',
                value ? 'NapCat 标签页已显示，可以立即访问控制面板' : 'NapCat 标签页已隐藏',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
          ),
        ),
        Obx(() {
          final token = homeController.napCatWebUiToken.value;
          return ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('NapCat 登录 token'),
            subtitle: Text(token.isEmpty ? '暂未获取到token' : token),
            onTap: token.isEmpty
                ? null
                : () async {
                    final fullUrl = 'http://localhost:6099/webui?token=$token';
                    await Clipboard.setData(ClipboardData(text: fullUrl));
                    Get.snackbar(
                      '已复制',
                      '完整登录链接已复制到剪贴板',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  },
          );
        }),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('自定义 Git Clone 命令'),
          subtitle: const Text('自定义 AstrBot 的获取方式'),
          onTap: () => _showCustomGitCloneDialog(),
        ),
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('显示终端白色文本日志'),
          subtitle: const Text('是否在终端显示 AstrBot 白色文本日志（默认隐藏）'),
          trailing: Obx(() => Switch(
                value: homeController.showTerminalWhiteTextRx.value,
                onChanged: (bool value) {
                  // 使用新的方法来同步更新响应式变量
                  homeController.setShowTerminalWhiteText(value);

                  Get.snackbar(
                    value ? '已启用白色文本显示' : '已禁用白色文本显示',
                    value ? '终端将显示所有日志输出' : '终端将仅显示彩色日志输出',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
              )),
        ),
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('文件系统'),
          subtitle: const Text(
            '内置 Ubuntu 文件系统已挂载至 \'文件\'\n可添加至 MT 文件管理器侧栏以快捷访问',
          ),
          onTap: () => _openFileManager(),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('清空 WebView 缓存'),
          subtitle: const Text('清理所有 WebView 缓存和密码'),
          onTap: () async {
            try {
              await widget.astrBotController.clearCache();
              await widget.napCatController.clearCache();
              await PasswordManager.clearAllPasswords();
              if (context.mounted) {
                Get.snackbar(
                  '成功',
                  'WebView 缓存和密码已清理',
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
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('隐私政策'),
          subtitle: const Text('查看应用隐私政策'),
          onTap: () async {
            try {
              final privacyContent =
                  await rootBundle.loadString('assets/privacy_policy.md');
              if (context.mounted) {
                Get.dialog(
                  Dialog(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Text(
                                '隐私政策',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Get.back(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: MarkdownBody(
                              data: privacyContent,
                              styleSheet: MarkdownStyleSheet(
                                h1: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                h2: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                h3: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                p: const TextStyle(fontSize: 14),
                                listBullet: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Get.snackbar(
                  '加载失败',
                  '无法加载隐私政策: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.exit_to_app, color: Colors.red),
          title: const Text(
            '退出应用',
            style: TextStyle(color: Colors.red),
          ),
          subtitle: const Text('退出 AstrBot 应用'),
          onTap: () async {
            // 显示确认对话框
            final confirm = await Get.dialog<bool>(
              AlertDialog(
                title: const Text('确认退出'),
                content: const Text('确定要退出应用吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: const Text(
                      '退出',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              Get.snackbar(
                '退出应用',
                '应用即将退出',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );

              // 2秒后自动退出应用
              Future.delayed(const Duration(seconds: 2), () {
                exit(0);
              });
            }
          },
        ),
      ],
    );
  }
}
