import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:global_repository/global_repository.dart';

/// 前台服务管理类
/// Foreground Service Manager
class ForegroundServiceManager {
  /// 标记用户是否点击了停止按钮（只有这种情况才不重建）
  static bool _userClickedStopButton = false;
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
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
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
    _userClickedStopButton = false; // 重置停止标记
    Log.i('启动前台服务...', tag: 'ForegroundService');

    if (await FlutterForegroundTask.isRunningService) {
      Log.i('服务已在运行，重启服务', tag: 'ForegroundService');
      return FlutterForegroundTask.restartService();
    } else {
      Log.i('启动新服务', tag: 'ForegroundService');
      return FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'AstrBot正在运行',
        notificationText: '应用正在后台保持运行状态',
        notificationIcon: null,
        notificationButtons: [
          const NotificationButton(
            id: 'btn_stop',
            text: '停止运行',
          ),
        ],
        callback: startCallback,
      );
    }
  }

  /// 停止前台服务（仅在用户点击停止按钮时调用）
  /// Stop foreground service (only called when user clicks stop button)
  static Future<ServiceRequestResult> stopService() async {
    _userClickedStopButton = true; // 标记为用户点击了停止按钮
    Log.i('用户点击停止按钮，停止前台服务', tag: 'ForegroundService');
    return FlutterForegroundTask.stopService();
  }

  /// 获取用户是否点击了停止按钮
  /// Get if user clicked stop button
  static bool get userClickedStopButton => _userClickedStopButton;

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
        notificationButtons: [
          const NotificationButton(
            id: 'btn_stop',
            text: '停止运行',
          ),
        ],
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
  /// 服务重建计数器
  int _rebuildCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服务启动时调用
    Log.i('前台服务已启动', tag: 'KeepAliveTaskHandler');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 根据 eventAction 设置的间隔定期调用
    // 这里执行保活逻辑和自动重建检测

    // 定期检查服务状态，如果发现服务已停止且用户没有点击停止按钮，则重建
    FlutterForegroundTask.isRunningService.then((isRunning) {
      if (!isRunning && !ForegroundServiceManager.userClickedStopButton) {
        Log.w('检测到服务意外停止，准备重建...', tag: 'KeepAliveTaskHandler');
        _rebuildService();
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTaskRemoved) async {
    // 服务销毁时调用
    // isTaskRemoved: 用户从最近任务中移除应用（值为true）
    // 用户从通知栏划掉通知项时，isTaskRemoved 为 false，此时需要重建
    Log.w('前台服务被销毁，isTaskRemoved: $isTaskRemoved', tag: 'KeepAliveTaskHandler');

    // 只有用户点击了停止按钮才不重建
    // 其他所有情况都需要重建，包括：
    // 1. 用户从通知栏划掉通知项
    // 2. 系统清理内存杀死服务
    // 3. 其他意外情况导致服务停止
    if (!ForegroundServiceManager.userClickedStopButton) {
      Log.i('将在500ms后重建服务（用户划掉通知或系统终止）', tag: 'KeepAliveTaskHandler');
      // 延迟重启以确保服务完全关闭
      await Future.delayed(const Duration(milliseconds: 500));
      await _rebuildService();
    } else {
      Log.i('用户点击了停止按钮，不重建服务', tag: 'KeepAliveTaskHandler');
    }
  }

  /// 重建服务
  Future<void> _rebuildService() async {
    try {
      _rebuildCount++;
      Log.i('正在重建服务（第 $_rebuildCount 次）...', tag: 'KeepAliveTaskHandler');

      final result = await ForegroundServiceManager.startService();

      if (result is ServiceRequestSuccess) {
        Log.i('服务重建成功', tag: 'KeepAliveTaskHandler');
        _rebuildCount = 0; // 重置计数器
      } else if (result is ServiceRequestFailure) {
        Log.e('服务重建失败: ${result.error}', tag: 'KeepAliveTaskHandler');

        // 如果重建失败，等待更长时间后再次尝试
        if (_rebuildCount < 5) {
          await Future.delayed(Duration(seconds: _rebuildCount * 2));
          await _rebuildService();
        } else {
          Log.e('服务重建失败次数过多，停止尝试', tag: 'KeepAliveTaskHandler');
          _rebuildCount = 0;
        }
      }
    } catch (e) {
      Log.e('重建服务时发生异常: $e', tag: 'KeepAliveTaskHandler');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    // 通知按钮点击时调用
    if (id == 'btn_stop') {
      Log.i('用户点击停止按钮', tag: 'KeepAliveTaskHandler');
      // 用户点击停止运行按钮，先标记为手动停止，然后退出应用
      ForegroundServiceManager.stopService().then((_) {
        exit(0);
      });
    }
  }

  @override
  void onNotificationPressed() {
    // 点击通知时调用
    Log.i('用户点击通知', tag: 'KeepAliveTaskHandler');
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {
    // 用户从通知栏划掉通知时调用
    Log.w('用户划掉通知，准备重建服务...', tag: 'KeepAliveTaskHandler');

    // 只有用户点击了停止按钮才不重建
    // 划掉通知应该重建服务
    if (!ForegroundServiceManager.userClickedStopButton) {
      Log.i('检测到通知被划掉，将重建服务', tag: 'KeepAliveTaskHandler');
      // 延迟一小段时间后重建服务
      Future.delayed(const Duration(milliseconds: 500), () {
        _rebuildService();
      });
    } else {
      Log.i('用户点击了停止按钮，不重建服务', tag: 'KeepAliveTaskHandler');
    }
  }
}
