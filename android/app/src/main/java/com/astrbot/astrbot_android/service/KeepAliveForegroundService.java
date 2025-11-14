package com.astrbot.astrbot_android.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.IBinder;

import androidx.core.app.NotificationCompat;
import com.astrbot.astrbot_android.R;

public class KeepAliveForegroundService extends Service {
    private static final String CHANNEL_ID = "AstrBotKeepAliveChannel";
    private static final int NOTIFICATION_ID = 1001;
    private static final String CHANNEL_NAME = "AstrBot后台服务";
    private static final String CHANNEL_DESCRIPTION = "保持AstrBot在后台运行";

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // 检查通知权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null && 
                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                // 权限未授予，但前台服务仍需启动
            }
        }
        
        Notification notification = createNotification();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14 (API 34) 及以上版本需要指定前台服务类型
            startForeground(NOTIFICATION_ID, notification, 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
        
        // 返回START_STICKY表示服务被杀死后会自动重启
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    /**
     * 创建通知渠道（Android 8.0及以上需要）
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_MIN
            );
            channel.setDescription(CHANNEL_DESCRIPTION);
            channel.setShowBadge(false);
            channel.setSound(null, null);
            channel.enableVibration(false);
            
            // Android 8.1 (API 27) 及以上版本设置通知分类
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                channel.setImportance(NotificationManager.IMPORTANCE_MIN);
            }
            
            // Android 10 (API 29) 及以上版本可以设置额外的通知属性
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // 设置为最低重要性，确保通知默认折叠
                channel.setImportance(NotificationManager.IMPORTANCE_MIN);
            }
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    /**
     * 创建通知
     */
    private Notification createNotification() {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("AstrBot正在运行")
                .setContentText("应用正在后台保持运行状态")
                .setSmallIcon(R.drawable.ic_notification)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setLocalOnly(true);

        Notification notification = builder.build();
        notification.flags |= Notification.FLAG_ONGOING_EVENT | Notification.FLAG_NO_CLEAR;

        return notification;
    }

    /**
     * 启动前台服务
     */
    public static void startService(Context context) {
        Intent intent = new Intent(context, KeepAliveForegroundService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    /**
     * 停止前台服务
     */
    public static void stopService(Context context) {
        Intent intent = new Intent(context, KeepAliveForegroundService.class);
        context.stopService(intent);
    }
}