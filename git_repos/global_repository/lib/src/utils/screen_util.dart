import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signale/signale.dart';

import 'platform_util.dart';

class ScreenAdapter {
  factory ScreenAdapter() => _getInstance();

  ScreenAdapter._internal();
  static ScreenAdapter get instance => _getInstance();
  static ScreenAdapter? _instance;
  static ScreenAdapter _getInstance() {
    _instance ??= ScreenAdapter._internal();
    return _instance!;
  }

  double? uiWidth;
  double scale = 1.0;
  static void init(double width) {
    if (instance.uiWidth != null) {
      return;
    }
    // ignore: deprecated_member_use
    Size dpSize = window.physicalSize / window.devicePixelRatio;
    if (dpSize == Size.zero) {
      return;
    }
    // Log.e('ScreenAdapter init -> $width');
    if (kIsWeb || PlatformUtil.isDesktop()) {
      // 桌面端直接不适配
      // 这两个 If 不能合并
      // 桌面端在改变窗口大小的时候，也不应该做适配
      width = dpSize.width;
    } else if (dpSize.width > 1000) {
      // 第二显示器为 4K 的时候，
      // Android DPI: 213
      // devicePixelRatio: 1.331

      // 小米 pad 6s Pro信息:
      // PhysicalSize: Size(3048.0, 1992.0)
      // devicePixelRatio: 2.5
      // Android DPI: 400.0
      // DP Size.longestSide -> 1219.2(3048.0/2.5)
      // ignore: deprecated_member_use
      double devicePixelRatio = window.devicePixelRatio;
      double androidDPI = devicePixelRatio * 160;
      Log.i("DP Size.longestSide -> ${dpSize.longestSide}", tag: 'ScreenAdapter');
      Log.i("DP Size.width -> ${dpSize.width}", tag: 'ScreenAdapter');
      Log.i("devicePixelRatio -> ${devicePixelRatio}", tag: 'ScreenAdapter');
      Log.i("Android DPI -> ${androidDPI}", tag: 'ScreenAdapter');
      width = dpSize.width;
    }
    // Log.i('ScreenAdapter init -> ${window.physicalSize.width} $width');
    instance.uiWidth = width;
    instance.scale = dpSize.width / width;
  }

  static void initWithWidth(double width, double screenWidth) {
    Size dpSize = window.physicalSize / window.devicePixelRatio;
    if (dpSize == Size.zero) {
      return;
    }
    instance.uiWidth = width;
    instance.scale = screenWidth / width;
  }

  static double setWidth(num width) {
    return width.w;
  }
}

extension ScreenExt on num {
  double get w => ScreenAdapter().scale * this;
}

extension ScreenInitExt on BuildContext {
  void init(double width) {
    ScreenAdapter.init(width);
  }
}
