import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:global_repository/global_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/terminal_controller.dart';
import '../../../core/constants/scripts.dart' as scripts;

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
  final HomeController homeController = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
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
                hintText: '例如：http://127.0.0.1:8080',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              final url = urlController.text.trim();

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
    final urlController = TextEditingController(text: webview['url']);

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
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              final url = urlController.text.trim();

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
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
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
      final result = await Process.run(
        '${RuntimeEnvir.binPath}/busybox',
        ['tar', '-czf', backupPath, '-C', '${scripts.ubuntuPath}/root/AstrBot', 'data'],
      );

      if (result.exitCode == 0) {
        final backupFile = File(backupPath);
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
          '错误: ${result.stderr}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Log.e('备份失败: ${result.stderr}', tag: 'AstrBot');
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
            widget.onNavigate(1);

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
              // 使用新的方法来同步更新响应式变量
              homeController.setNapCatWebUiEnabled(value);

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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text(
                '自定义 WebView',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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
                  '暂无自定义 WebView\n点击右上角"+"添加',
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
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _confirmDeleteWebView(index, webview['title'] ?? 'WebUI'),
                      tooltip: '删除',
                    ),
                  ],
                ),
              );
            }),
          );
        }),
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
              await widget.astrBotController.clearCache();
              await widget.napCatController.clearCache();
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
    );
  }
}
