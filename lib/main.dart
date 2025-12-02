import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';

import 'generated/l10n.dart';
import 'core/services/foreground_service.dart';
import 'ui/routes/app_routes.dart';

// Notice: behavior will submit Device

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 检查并请求通知权限
  var status = await Permission.notification.status;
  if (status.isDenied || status.isPermanentlyDenied) {
    await Permission.notification.request();
  }
  
  // 初始化并启动前台服务
  ForegroundServiceManager.init();
  await ForegroundServiceManager.startService();
  
  // 隐藏系统 UI
  // Hide system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
    SystemUiOverlay.top,
    // SystemUiOverlay.bottom,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Android 状态栏图标为白色
    statusBarBrightness: Brightness.dark, // iOS 状态栏图标为白色
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  RuntimeEnvir.initEnvirWithPackageName('com.astrbot.astrbot_android');
  await initSettingStore(RuntimeEnvir.configPath);
  runApp(const AstrBot());

}

class AstrBot extends StatefulWidget {
  const AstrBot({super.key});

  @override
  State<AstrBot> createState() => _AstrBotState();
}

class _AstrBotState extends State<AstrBot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用完全退出时，确保清理所有资源
    if (state == AppLifecycleState.detached) {
      Log.i('应用正在退出，清理所有资源...', tag: 'AstrBot');
      try {
        // 尝试获取并清理 HomeController
        if (Get.isRegistered<dynamic>()) {
          Get.delete<dynamic>(force: true);
        }
      } catch (e) {
        Log.e('清理资源时出错: $e', tag: 'AstrBot');
      }
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AstrBot Android',
      theme: ThemeData(
        colorSchemeSeed: Colors.primaries[3],
      ),
      // locale: const Locale('zh', 'CN'),
      // locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      // 使用路由管理
      initialRoute: AppRoutes.terminal,
      getPages: AppRoutes.routes,
    );
  }
}
