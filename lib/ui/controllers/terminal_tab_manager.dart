import 'dart:convert';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';

import '../../core/utils/file_utils.dart';

/// 终端标签页类型
enum TerminalTabType {
  fixed, // 固定的AstrBot终端（只读、颜色过滤、不可关闭）
  system, // 系统终端（可交互、可关闭）
}

/// 终端标签页数据模型
class TerminalTab {
  final String id;
  final String title;
  final TerminalTabType type;
  final Terminal terminal;
  final Pty? pty;
  bool isActive;

  TerminalTab({
    required this.id,
    required this.title,
    required this.type,
    required this.terminal,
    this.pty,
    this.isActive = false,
  });
}

/// 多终端标签页管理器
class TerminalTabManager extends GetxController {
  // 所有终端标签页列表
  final RxList<TerminalTab> tabs = <TerminalTab>[].obs;

  // 当前激活的标签页索引
  final RxInt activeTabIndex = 0.obs;

  /// 初始化固定的AstrBot终端标签页
  void initializeFixedTab(Terminal terminal) {
    // 清空现有标签页
    tabs.clear();

    // 添加固定的AstrBot终端标签页
    final fixedTab = TerminalTab(
      id: 'fixed_astrbot',
      title: 'AstrBot',
      type: TerminalTabType.fixed,
      terminal: terminal,
      pty: null, // 固定终端使用外部管理的 pseudoTerminal
      isActive: true,
    );

    tabs.add(fixedTab);
    activeTabIndex.value = 0;
  }

  /// 添加新的系统终端标签页
  Future<void> addSystemTerminalTab() async {
    try {
      final newIndex =
          tabs.where((t) => t.type == TerminalTabType.system).length + 1;
      final tabId = 'system_${DateTime.now().millisecondsSinceEpoch}';

      // 创建新的终端实例
      final newTerminal = Terminal(
        maxLines: 10000,
      );

      // 创建新的PTY实例
      final newPty = createPTY(
        rows: newTerminal.viewHeight,
        columns: newTerminal.viewWidth,
      );

      // 标志：是否已经创建了标签页
      var tabCreated = false;

      // 连接终端的 onResize 和 onOutput 事件（需要在监听输出前就连接好）
      newTerminal.onResize = (width, height, pixelWidth, pixelHeight) {
        newPty.resize(height, width);
      };

      newTerminal.onOutput = (data) {
        newPty.writeString(data);
      };

      // 监听PTY输出，等待登录完成后再创建标签页
      newPty.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((event) {
        // 检测是否包含 root@localhost 提示符
        if (!tabCreated && event.contains('root@localhost')) {
          tabCreated = true;

          // 创建新标签页
          final newTab = TerminalTab(
            id: tabId,
            title: '终端 $newIndex',
            type: TerminalTabType.system,
            terminal: newTerminal,
            pty: newPty,
            isActive: false,
          );

          // 将所有现有标签页设为非激活状态
          for (var tab in tabs) {
            tab.isActive = false;
          }

          // 添加新标签页并激活
          tabs.add(newTab);
          newTab.isActive = true;
          activeTabIndex.value = tabs.length - 1;

          Log.i('添加新系统终端标签页: ${newTab.title} (ID: ${newTab.id})',
              tag: 'TerminalTabManager');
          // 不要 return，继续处理后续输出
        }

        // 标签页创建后，正常输出所有内容
        if (tabCreated) {
          newTerminal.write(event);
        }
        // 标签页创建前，不输出任何内容（跳过登录过程的输出）
      });

      // 登录到ubuntu容器
      final command =
          'source ${RuntimeEnvir.homePath}/common.sh\nlogin_ubuntu "bash" \n';
      newPty.writeString(command);
    } catch (e) {
      Log.e('添加系统终端标签页失败: $e', tag: 'TerminalTabManager');
      Get.snackbar('错误', '创建终端失败: $e');
    }
  }

  /// 切换到指定标签页
  void switchToTab(int index) {
    if (index >= 0 && index < tabs.length) {
      // 将所有标签页设为非激活状态
      for (var tab in tabs) {
        tab.isActive = false;
      }

      // 激活指定标签页
      tabs[index].isActive = true;
      activeTabIndex.value = index;

      Log.i('切换到标签页: ${tabs[index].title} (索引: $index)',
          tag: 'TerminalTabManager');
    }
  }

  /// 关闭指定标签页
  void closeTab(int index) {
    if (index < 0 || index >= tabs.length) {
      return;
    }

    final tab = tabs[index];

    // 固定标签页不能关闭
    if (tab.type == TerminalTabType.fixed) {
      Get.snackbar('提示', 'AstrBot终端不能关闭');
      return;
    }

    try {
      // 关闭PTY
      if (tab.pty != null) {
        tab.pty!.kill();
        Log.i('关闭终端PTY: ${tab.title}', tag: 'TerminalTabManager');
      }

      // 移除标签页
      tabs.removeAt(index);

      // 如果关闭的是当前激活的标签页，切换到前一个标签页
      if (index == activeTabIndex.value) {
        final newIndex = (index > 0) ? index - 1 : 0;
        if (tabs.isNotEmpty) {
          switchToTab(newIndex);
        }
      } else if (index < activeTabIndex.value) {
        // 如果关闭的标签页在当前激活标签页之前，需要更新索引
        activeTabIndex.value = activeTabIndex.value - 1;
      }

      Log.i('关闭标签页: ${tab.title}', tag: 'TerminalTabManager');
    } catch (e) {
      Log.e('关闭标签页失败: $e', tag: 'TerminalTabManager');
    }
  }

  /// 获取当前激活的标签页
  TerminalTab? get activeTab {
    if (activeTabIndex.value >= 0 && activeTabIndex.value < tabs.length) {
      return tabs[activeTabIndex.value];
    }
    return null;
  }

  @override
  void onClose() {
    // 关闭所有系统终端的PTY
    for (var tab in tabs) {
      if (tab.type == TerminalTabType.system && tab.pty != null) {
        try {
          tab.pty!.kill();
          Log.i('清理终端PTY: ${tab.title}', tag: 'TerminalTabManager');
        } catch (e) {
          Log.e('清理终端PTY失败: $e', tag: 'TerminalTabManager');
        }
      }
    }
    tabs.clear();
    super.onClose();
  }
}
