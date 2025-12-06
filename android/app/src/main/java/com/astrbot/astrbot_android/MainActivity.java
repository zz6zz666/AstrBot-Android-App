package com.astrbot.astrbot_android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.view.ViewGroup;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;

import io.flutter.embedding.android.FlutterFragment;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FragmentActivity {
    FlutterFragment flutterFragment;
    private static final String TAG_FLUTTER_FRAGMENT = "flutter_fragment";
    Context mContext;
    FragmentManager fragmentManager = getSupportFragmentManager();

    // 文件选择器相关
    private static final int FILE_CHOOSER_REQUEST_CODE = 1;
    private ValueCallback<Uri[]> filePathCallback;

    // 双击返回退出相关
    private boolean doubleBackToExitPressedOnce = false;
    private static final int DOUBLE_BACK_INTERVAL = 2000; // 2秒内连续按返回键

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mContext = this;
        setContentView(com.astrbot.astrbot_android.R.layout.my_activity_layout);

        flutterFragment = (FlutterFragment) fragmentManager.findFragmentByTag(TAG_FLUTTER_FRAGMENT);
        FlutterEngine flutterEngine = new FlutterEngine(this, null, false);
        flutterEngine.getDartExecutor().executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault());
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "astrbot_channel").setMethodCallHandler((call, result) -> {
            if ("lib_path".equals(call.method)) {
                result.success(mContext.getApplicationContext().getApplicationInfo().nativeLibraryDir);
            } else {
                result.notImplemented();
            }
        });
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine);
        if (flutterFragment == null) {
            flutterFragment = FlutterFragment.withCachedEngine("my_engine_id").build();
        }
        fragmentManager
                .beginTransaction()
                .add(com.astrbot.astrbot_android.R.id.fl_container, flutterFragment, TAG_FLUTTER_FRAGMENT)
                .commit();
    }


    @Override
    public void onPostResume() {
        super.onPostResume();
        flutterFragment.onPostResume();
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        flutterFragment.onNewIntent(intent);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        // 处理文件选择器返回的结果
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            if (filePathCallback == null) {
                return;
            }

            Uri[] results = null;
            if (resultCode == Activity.RESULT_OK && data != null) {
                String dataString = data.getDataString();
                if (dataString != null) {
                    results = new Uri[]{Uri.parse(dataString)};
                } else if (data.getClipData() != null) {
                    // 处理多文件选择
                    int count = data.getClipData().getItemCount();
                    results = new Uri[count];
                    for (int i = 0; i < count; i++) {
                        results[i] = data.getClipData().getItemAt(i).getUri();
                    }
                }
            }

            filePathCallback.onReceiveValue(results);
            filePathCallback = null;
        }

        // 传递给 FlutterFragment
        flutterFragment.onActivityResult(requestCode, resultCode, data);
    }

    // 用于从 Flutter 端调用的方法，触发文件选择器
    public void openFileChooser(ValueCallback<Uri[]> callback) {
        filePathCallback = callback;

        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);

        Intent chooserIntent = Intent.createChooser(intent, "选择文件");
        startActivityForResult(chooserIntent, FILE_CHOOSER_REQUEST_CODE);
    }

    @Override
    public void onBackPressed() {
        // 实现双击返回退出到桌面，但不传递给Flutter层
        if (doubleBackToExitPressedOnce) {
            // 第二次按返回键，移动到后台（返回桌面）
            moveTaskToBack(true);
            return;
        }

        // 第一次按返回键，显示提示
        this.doubleBackToExitPressedOnce = true;
        Toast.makeText(this, "再按一次返回桌面", Toast.LENGTH_SHORT).show();

        // 2秒后重置标志
        new Handler().postDelayed(() -> doubleBackToExitPressedOnce = false, DOUBLE_BACK_INTERVAL);

        // 不调用 super.onBackPressed() 和 flutterFragment.onBackPressed()
        // 确保返回事件不会传递给 Flutter 层
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            @NonNull String[] permissions,
            @NonNull int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        flutterFragment.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults
        );
    }

    @Override
    public void onUserLeaveHint() {
        flutterFragment.onUserLeaveHint();
    }

    @Override
    public void onTrimMemory(int level) {
        super.onTrimMemory(level);
        flutterFragment.onTrimMemory(level);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

}
