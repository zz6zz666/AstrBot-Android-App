import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';

class SafeAreaFix extends StatefulWidget {
  const SafeAreaFix({
    super.key,
    required this.child,
    this.top = true,
  });
  final Widget child;
  final bool top;

  @override
  State<SafeAreaFix> createState() => _SafeAreaFixState();
}

class _SafeAreaFixState extends State<SafeAreaFix> {
  @override
  Widget build(BuildContext context) {
    EdgeInsets padding = MediaQuery.paddingOf(context);
    // Log.i('padding -> $padding');
    // 36.9 是正常高度下的高度
    // 590.8 是悬浮窗下的高度
    if (padding.top > 50) {
      return Padding(
        padding: EdgeInsets.only(
          top: 32.w,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: widget.child,
        ),
      );
    }
    return SafeArea(
      top: widget.top,
      child: widget.child,
    );
  }
}
