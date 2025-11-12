import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

enum ScreenType {
  desktop,
  tablet,
  phone,
}
typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  ScreenType screenType,
);

class Responsive extends StatefulWidget {
  const Responsive({Key? key, this.builder}) : super(key: key);

  final ResponsiveWidgetBuilder? builder;

  static ResponsiveState? of(BuildContext context) {
    return context.findAncestorStateOfType<ResponsiveState>();
  }

  @override
  ResponsiveState createState() => ResponsiveState();
}

class ResponsiveState extends State<Responsive> with WidgetsBindingObserver {
  ScreenType screenType = ScreenType.phone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initial().then((value) {
      setState(() {});
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    setState(() {});
  }

  Future<void> initial() async {
    final completer = Completer();
    if (window.physicalSize.width != 0) {
      completer.complete();
    }
    void Function()? callback = window.onMetricsChanged;
    window.onMetricsChanged = () {
      if (!completer.isCompleted) {
        completer.complete();
      }
      callback!();
    };
    await completer.future;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        if (constraints.maxWidth < 500) {
          screenType = ScreenType.phone;
        } else if (constraints.maxWidth > 800) {
          screenType = ScreenType.desktop;
        } else {
          screenType = ScreenType.tablet;
        }
        return widget.builder!(_, screenType);
      },
    );
  }
}
