// ignore_for_file: must_be_immutable

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:signale/signale.dart';

class ScreenQuery extends InheritedWidget {
  ScreenQuery({
    required this.uiWidth,
    required Widget child,
    required this.screenWidth,
    double longWidthScale = 1.0,
  }) : super(child: child) {
    // TODO 屏幕适配这块一直很模糊
    //
    if (screenWidth > 1000) {
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
      Log.i("screenWidth -> ${screenWidth}", tag: 'ScreenAdapter');
      Log.i("devicePixelRatio -> ${devicePixelRatio}", tag: 'ScreenAdapter');
      Log.i("Android DPI -> ${androidDPI}", tag: 'ScreenAdapter');
      // 这里其实就是不适配宽高了
      // 但是在 4K 显示器上，所有的 Size 看起来都会非常小
      // 可以参考 Windows 的缩放比例
      // 例如 1.25 1.5 1.75 2.0
      scale = longWidthScale;
      return;
    }
    scale = screenWidth / uiWidth;
  }

  final double uiWidth;
  final double screenWidth;
  double scale = 1.0;

  @override
  bool updateShouldNotify(covariant ScreenQuery oldWidget) {
    return oldWidget.scale != scale;
  }

  double setWidth(num width) {
    // Log.i('scale -> $scale', tag: 'ScreenAdapter');
    return width * scale;
  }

  static ScreenQuery of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScreenQuery>()!;
  }
}

// 全局缓存 Map，使用 State 的 hashCode 作为 key
final Map<int, ScreenQuery> _screenQueryCache = <int, ScreenQuery>{};

extension ScreenStateExt on State {
  double l(num width) {
    final int stateHash = hashCode;
    ScreenQuery? cachedScreenQuery = _screenQueryCache[stateHash];

    if (cachedScreenQuery == null) {
      cachedScreenQuery = ScreenQuery.of(context);
      _screenQueryCache[stateHash] = cachedScreenQuery;
    }

    return cachedScreenQuery.setWidth(width);
  }
}

extension ScreenContextExt on BuildContext {
  // TODO need cache
  double l(num width) {
    return ScreenQuery.of(this).setWidth(width);
  }
}
