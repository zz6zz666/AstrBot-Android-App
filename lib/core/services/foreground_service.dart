import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 前台服务管理类
/// Foreground Service Manager
class ForegroundServiceManager {
  /// 初始化前台服务
  /// Initialize foreground service
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'astrbot_keep_alive_channel',
        channelName: 'AstrBot后台服务',
        channelDescription: '保持AstrBot在后台运行',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // 每5秒检查一次
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// 启动前台服务
  /// Start foreground service
  static Future<ServiceRequestResult> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'AstrBot正在运行',
        notificationText: '应用正在后台保持运行状态',
        callback: startCallback,
      );
    }
  }

  /// 停止前台服务
  /// Stop foreground service
  static Future<ServiceRequestResult> stopService() async {
    return FlutterForegroundTask.stopService();
  }

  /// 检查服务是否正在运行
  /// Check if service is running
  static Future<bool> isRunningService() async {
    return FlutterForegroundTask.isRunningService;
  }

  /// 更新通知内容
  /// Update notification content
  static Future<void> updateNotification({
    String? title,
    String? text,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.updateService(
        notificationTitle: title ?? 'AstrBot正在运行',
        notificationText: text ?? '应用正在后台保持运行状态',
      );
    }
  }
}

/// 前台服务回调函数
/// Foreground service callback
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(KeepAliveTaskHandler());
}

/// 前台任务处理器
/// Foreground task handler
class KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服务启动时调用
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 根据 eventAction 设置的间隔定期调用
    // 这里可以执行保活逻辑，目前只需要保持前台服务运行即可
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTaskRemoved) async {
    // 服务销毁时调用
  }

  @override
  void onNotificationButtonPressed(String id) {
    // 通知按钮点击时调用（当前没有按钮）
  }

  @override
  void onNotificationPressed() {
    // 点击通知时调用
    FlutterForegroundTask.launchApp('/');
  }
}
