import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_pty/flutter_pty.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ptyOutout = StringBuffer();

  final textEdit = TextEditingController();

  final focusNode = FocusNode();

  late final Pty pty;

  @override
  void initState() {
    super.initState();

    pty = Pty.start(shell);

    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen((text) {
      ptyOutout.write(text);
      setState(() {});
    });

    pty.exitCode.then((code) {
      ptyOutout.writeln('the process exited with exit code $code');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints.expand(),
                child: SingleChildScrollView(
                  child: Text(ptyOutout.toString()),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(8),
              child: TextField(
                autofocus: true,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  prefix: Text(r'$ '),
                  border: InputBorder.none,
                ),
                controller: textEdit,
                onSubmitted: onEnter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onEnter(String text) {
    final carriageReturn = Platform.isWindows ? '\r\n' : '\n';
    pty.write(const Utf8Encoder().convert(text + carriageReturn));
    textEdit.clear();
    focusNode.requestFocus();
  }
}

String get shell {
  if (Platform.isMacOS || Platform.isLinux) {
    return 'bash';
    // return Platform.environment['SHELL'] ?? 'bash';
  }

  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  return 'sh';
}
