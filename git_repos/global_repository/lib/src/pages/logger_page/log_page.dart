import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';
import 'xterm_wrapper.dart';

class LoggerView extends StatefulWidget {
  const LoggerView({
    Key? key,
    this.showActionButton = true,
    this.fontSize = 12,
    this.background = Colors.transparent,
  }) : super(key: key);
  final bool showActionButton;
  final double fontSize;
  final Color background;

  @override
  _LoggerViewState createState() => _LoggerViewState();
}

class _LoggerViewState extends State<LoggerView> {
  bool verbose = true;
  bool debug = true;
  bool info = true;
  bool warning = true;
  bool error = true;
  Terminal terminal = Terminal();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      onChange();
    });
  }

  void onChange() {
    terminal.eraseDisplay();
    terminal.eraseScrollbackOnly();
    terminal.setCursor(0, 0);
    for (var v in Log.buffer) {
      printToConsole(v);
    }
    Log.defaultLogger.stream.listen(printToConsole);
  }

  void printToConsole(LogEntity entity) {
    final String data = entity.data;
    if (entity.level == LogLevel.verbose && verbose) {
      terminal.write(data + "\r\n");
    }
    if (entity.level == LogLevel.debug && debug) {
      terminal.write(data + "\r\n");
    }
    if (entity.level == LogLevel.info && info) {
      terminal.write(data + "\r\n");
    }
    if (entity.level == LogLevel.warning && warning) {
      terminal.write(data + "\r\n");
    }
    if (entity.level == LogLevel.error && error) {
      terminal.write(data + "\r\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ScrollConfiguration(
                  behavior: const ScrollBehavior().copyWith(
                    physics: const BouncingScrollPhysics(),
                  ),
                  child: TerminalView(
                    terminal,
                    backgroundOpacity: 0,
                    readOnly: true,
                    keyboardType: TextInputType.text,
                    textStyle: TerminalStyle(fontSize: widget.fontSize),
                    theme: MacTerminalTheme(),
                  ),
                ),
              ),
              SizedBox(height: l(8)),
              if (widget.showActionButton)
                WrapContainerList(
                  children: [
                    CheckContainer(
                      value: verbose,
                      data: 'verbose',
                      onChanged: (value) {
                        verbose = value;
                        setState(() {});
                        onChange();
                      },
                      fontSize: widget.fontSize,
                    ),
                    CheckContainer(
                      value: debug,
                      data: 'debug',
                      onChanged: (value) {
                        debug = value;
                        setState(() {});
                        onChange();
                      },
                      fontSize: widget.fontSize,
                    ),
                    CheckContainer(
                      value: info,
                      data: 'info',
                      onChanged: (value) {
                        info = value;
                        setState(() {});
                        onChange();
                      },
                      fontSize: widget.fontSize,
                    ),
                    CheckContainer(
                      value: warning,
                      data: 'warning',
                      onChanged: (value) {
                        warning = value;
                        setState(() {});
                        onChange();
                      },
                      fontSize: widget.fontSize,
                    ),
                    CheckContainer(
                      value: error,
                      data: 'error',
                      onChanged: (value) {
                        error = value;
                        setState(() {});
                        onChange();
                      },
                      fontSize: widget.fontSize,
                    ),
                  ],
                ),
            ],
          ),
          Align(
            alignment: Alignment.topRight,
            child: NiCardButton(
              color: Theme.of(context).colorScheme.primary.opacity02,
              onTap: () {
                List<LogEntity> logData = Log.defaultLogger.buffer;
                if (logData.isEmpty) {
                  showToast('没有日志可供复制');
                  return;
                }
                StringBuffer logBuffer = StringBuffer();
                for (var log in logData) {
                  logBuffer.writeln('${log.time} [${log.level.name}] ${log.data}');
                }
                Clipboard.setData(ClipboardData(text: '$logBuffer'));
                showToast('已复制日志到剪贴板');
              },
              child: SizedBox(
                width: l(96),
                height: l(36),
                child: Center(
                  child: Text(
                    '复制',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: l(12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckContainer extends StatelessWidget {
  const CheckContainer({
    Key? key,
    required this.onChanged,
    required this.value,
    required this.data,
    required this.fontSize,
  }) : super(key: key);

  final void Function(bool value) onChanged;
  final bool value;
  final String data;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.w),
        border: Border.all(
          color: Colors.transparent,
          width: 2.w,
        ),
      ),
      child: GestureWithScale(
        onTap: () {
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: value ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
              child: Text(
                data,
                style: TextStyle(
                  color: Colors.white,
                  // color: value ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String twoDigits(int n) {
  if (n >= 10) return "$n";
  return "0$n";
}

class MacTerminalTheme extends TerminalTheme {
  MacTerminalTheme({
    super.cursor = const Color(0xaa8b8b8b),
    super.selection = const Color(0XAAAEAFAD),
    super.foreground = const Color(0xff000000),
    super.background = const Color(0xffffffff),
    super.black = const Color(0xff000000),
    super.brightBlack = const Color(0xff666666),
    super.white = const Color(0xffbfbfbf),
    super.brightWhite = const Color(0xffe5e5e5),
    super.red = const Color(0xff990000),
    super.brightRed = const Color(0xffe50000),
    super.green = const Color(0xff00a600),
    super.brightGreen = const Color(0xff00d900),
    super.yellow = const Color(0xff999900),
    super.brightYellow = const Color(0xffe5e500),
    super.blue = const Color(0xff0000b2),
    super.brightBlue = const Color(0xff0000ff),
    super.magenta = const Color(0xffb200b2),
    super.brightMagenta = const Color(0xffe500e5),
    super.cyan = const Color(0xff00a6b2),
    super.brightCyan = const Color(0xff00e5e5),
    super.searchHitBackground = const Color(0XFF000000),
    super.searchHitBackgroundCurrent = const Color(0XFF31FF26),
    super.searchHitForeground = const Color(0XFF000000),
  });
}
