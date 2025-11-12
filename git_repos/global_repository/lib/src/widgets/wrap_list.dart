import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:global_repository/src/utils/screen_util.dart';
import 'package:responsive_framework/responsive_framework.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xfff5f5f7),
        body: Builder(
          builder: (
            _,
          ) {
            return WrapContainerList(
              children: [
                CheckContainer(
                  groupValue: index,
                  value: 0,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '扫码',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 1,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '局域网发现',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 2,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    'NFC碰一碰',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 3,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '扫码',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 4,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '局域网发现',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 5,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    'NFC碰一碰',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 6,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '扫码',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 7,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    '局域网发现',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckContainer(
                  groupValue: index,
                  value: 8,
                  onChanged: (value) {
                    index = value;
                    setState(() {});
                  },
                  child: Text(
                    'NFC碰一碰',
                    style: TextStyle(
                      fontSize: 14.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class WrapContainerList extends StatefulWidget {
  const WrapContainerList({
    Key? key,
    this.children = const [],
    this.width = 100,
    this.phoneChangeBreakPoint = 100,
  }) : super(key: key);
  final List<Widget> children;
  final double width;
  final double phoneChangeBreakPoint;
  @override
  State<WrapContainerList> createState() => _WrapContainerListState();
}

class _WrapContainerListState extends State<WrapContainerList> {
  double padding = 0.0;
  double getWidth(double maxWidth) {
    final double dpWidth = maxWidth;
    int i = 7;
    if (ResponsiveBreakpoints.of(context).isMobile) {
      for (; dpWidth / i < widget.phoneChangeBreakPoint; i--) {}
    } else {
      for (; dpWidth / i < widget.width; i--) {}
    }
    return (dpWidth - 2 * padding) / i;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, BoxConstraints boxConstraints) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Builder(builder: (context) {
          final double boxWidth = getWidth(boxConstraints.maxWidth);
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 0,
            runSpacing: 0.w,
            children: [
              ...widget.children
                  .map(
                    (widget) => AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: boxWidth,
                      child: widget,
                    ),
                  )
                  .toList(),
            ],
          );
        }),
      );
    });
  }
}

class CheckContainer extends StatelessWidget {
  const CheckContainer({
    Key? key,
    this.onChanged,
    this.value,
    this.groupValue,
    this.child,
  }) : super(key: key);

  final void Function(int value)? onChanged;
  final int? value;
  final int? groupValue;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool isCheck = value == groupValue;
    return Container(
      decoration: isCheck
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16.w),
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2.w,
              ),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(16.w),
              border: Border.all(
                color: Colors.transparent,
                width: 2.w,
              ),
            ),
      padding: EdgeInsets.all(4.w),
      child: GestureDetector(
        onTap: () {
          onChanged?.call(value!);
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xffeaeaea),
            borderRadius: BorderRadius.circular(12.w),
            // border: Border.all(
            //   color: Colors.grey.withOpacity(0.2),
            //   width: 2.w,
            // ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 16.w,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
