import 'dart:io';
import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';

class XTermWrapper extends StatefulWidget {
  const XTermWrapper({
    Key? key,
    required this.terminal,
    required this.fontSize,
  }) : super(key: key);
  final Terminal terminal;
  final double fontSize;

  @override
  State<XTermWrapper> createState() => _XTermWrapperState();
}

class _XTermWrapperState extends State<XTermWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      child: TerminalView(
        widget.terminal,
        backgroundOpacity: 0,
        readOnly: true,
        keyboardType: TextInputType.text,
        textStyle: TerminalStyle(fontSize: widget.fontSize),
        theme: MacTerminalTheme(),
      ),
    );
  }
}
