import 'package:flutter/material.dart';

class NiCardButton extends StatefulWidget {
  const NiCardButton({
    Key? key,
    this.child,
    this.onTap,
    this.blurRadius = 4.0,
    this.shadowColor = Colors.black,
    this.borderRadius = 8.0,
    this.color,
    this.spreadRadius = 0,
    this.margin = const EdgeInsets.all(8.0),
  }) : super(key: key);
  final Widget? child;
  final Function? onTap;
  final double blurRadius;
  final double borderRadius;
  final double spreadRadius;
  final Color shadowColor;
  final Color? color;
  final EdgeInsetsGeometry margin;
  @override
  _NiCardButtonState createState() => _NiCardButtonState();
}

class _NiCardButtonState extends State<NiCardButton>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  bool isOnTap = false;
  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // onLongPress: () {
      //   // print('sada');
      // },
      onTap: () {
        if (widget.onTap == null) {
          return;
        }
        isOnTap = false;
        setState(() {});
        Feedback.forLongPress(context);
        Feedback.forTap(context);
        animationController.reverse();
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      onTapDown: (_) {
        if (widget.onTap == null) {
          return;
        }
        animationController.forward();
        Feedback.forLongPress(context);
        Feedback.forTap(context);
        isOnTap = true;
        setState(() {});
      },
      onTapCancel: () {
        if (widget.onTap == null) {
          return;
        }
        animationController.reverse();
        Feedback.forLongPress(context);
        Feedback.forTap(context);
        isOnTap = false;
        setState(() {});
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(
            1.0 - animationController.value * 0.02,
          ),
        child: Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            color: widget.color ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.shadowColor.withOpacity(
                  0.04 - animationController.value * 0.04,
                ),
                offset: const Offset(0.0, 0.0), //阴影xy轴偏移量
                blurRadius: widget.blurRadius, //阴影模糊程度
                spreadRadius: widget.spreadRadius, //阴影扩散程度
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
