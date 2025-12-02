import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/terminal_controller.dart';

class WebViewBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const WebViewBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();

    // 使用 Obx 来响应式监听变化
    return Obx(() {
      // 检查 NapCat WebUI 是否启用
      final bool napCatEnabled = homeController.napCatWebUiEnabledRx.value;

      // 获取自定义 WebView 列表
      final customWebViews = homeController.customWebViews;

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
        // 添加自定义 WebView 项（地球图标）
        ...customWebViews.map((webview) => BottomNavigationBarItem(
              icon: const Icon(Icons.language),
              label: webview['title'] ?? 'WebUI',
            )),
        const BottomNavigationBarItem(
          icon: Icon(Icons.terminal),
          label: '终端',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '设置',
        ),
      ];

      return BottomNavigationBar(
        currentIndex: currentIndex >= navItems.length
            ? navItems.length - 1
            : currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.shifting,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: navItems,
      );
    });
  }
}
