import 'package:flutter/services.dart';

class OverlayStyle {
  static SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.dark,
  );
  static SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  );
}
