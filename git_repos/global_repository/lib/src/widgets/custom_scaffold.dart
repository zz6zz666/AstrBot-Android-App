import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum DrawerType {
  row,
  hideInLeft,
}

// 主要动态适配桌面端与移动端的侧栏
class NiScaffold extends StatefulWidget {
  const NiScaffold({
    Key? key,
    this.drawer,
    this.body,
    this.backgroundColor,
  }) : super(key: key);
  final Widget? drawer;
  final Widget? body;
  final Color? backgroundColor;
  @override
  _NiScaffoldState createState() => _NiScaffoldState();
}

class _NiScaffoldState extends State<NiScaffold> {
  DrawerType drawerType = DrawerType.hideInLeft;
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          drawerType = DrawerType.row;
        } else {
          drawerType = DrawerType.hideInLeft;
        }
        return Scaffold(
          backgroundColor: widget.backgroundColor,
          drawer: drawerType == DrawerType.hideInLeft ? widget.drawer : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (drawerType == DrawerType.row && widget.drawer != null) widget.drawer!,
              Expanded(
                child: widget.body!,
              ),
            ],
          ),
        );
      },
    );
  }
}
