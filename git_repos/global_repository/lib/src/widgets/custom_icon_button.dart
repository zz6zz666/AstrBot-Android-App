import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';

class NiIconButton extends StatelessWidget {
  const NiIconButton({Key? key, this.child, this.onTap}) : super(key: key);
  final Widget? child;
  final GestureTapCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48.w,
        height: 48.w,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.w),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: child,
          ),
        ),
      ),
    );
  }
}
