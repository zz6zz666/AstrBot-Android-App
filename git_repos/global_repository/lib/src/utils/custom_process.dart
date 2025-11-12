import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:global_repository/src/interface/process.dart';
import 'package:signale/signale.dart';
import 'package:synchronized/synchronized.dart';
import 'platform_util.dart';

// 自实现的Process基于dart:io库中的Process.start

typedef ProcessCallBack = void Function(String output);

const exitKey = 'process_exit';

class YanProcess implements Executable {
  YanProcess({
    this.envir = const {},
  });
  Map<String, String> envir;
  Process? _process;
  Process? get process => _process;
  bool? _isRoot;
  String get shPath {
    switch (Platform.operatingSystem) {
      case 'linux':
        return 'sh';
        break;
      case 'macos':
        return 'sh';
        break;
      case 'windows':
        return 'wsl';
        break;
      case 'android':
        return '/system/bin/sh';
        break;
      default:
        return 'sh';
    }
  }

  Future<void> ensureInitialized() async {
    if (process == null) {
      await _init();
    }
  }

  Future<void> _init() async {
    Map<String, String> envirTmp = PlatformUtil.envir();
    for (String key in envir.keys) {
      envirTmp[key] = envir[key]!;
    }
    _process = await Process.start(
      shPath,
      <String>[],
      includeParentEnvironment: true,
      runInShell: false,
      environment: envirTmp,
    );
    processStdout = _process!.stdout.asBroadcastStream();
    processStderr = _process!.stderr.asBroadcastStream();
    // 不加这个，会出现err输出会累计到最后输出
    processStderr.transform(utf8.decoder).listen((event) {
      Log.e('$event', tag: 'NiProcess');
    });
  }

  late Stream<List<int>> processStdout;
  late Stream<List<int>> processStderr;
  // static void exit() {
  //   if (isUseing) {
  //     // _process.stdin.write('echo exitCode\n');
  //   }
  // }
  // Future<String> rawExec(
  //   String script, {
  //   ProcessCallBack callback,
  //   bool getStdout = true,
  //   bool getStderr = false,
  // }) async {

  // }

  var lock = Lock();
  @override
  Future<String> exec(
    String script, {
    ProcessCallBack? callback,
    bool getStdout = true,
    bool getStderr = false,
  }) async {
    return lock.synchronized(() async {
      // Log.e('${script.trim()} 执行');
      Completer<String> resultComp = Completer();
      if (_process == null) {
        /// 如果初始为空需要城初始化Process
        await _init();
      }
      final StringBuffer buffer = StringBuffer();
      // 加上换行符
      if (!script.endsWith('\n')) {
        script += '\n';
      }
      _process!.stdin.write(script);
      // print('脚本====>$script');
      _process!.stdin.write('echo $exitKey\n');
      if (getStderr) {
        // print('等待错误');
        processStderr.transform(utf8.decoder).every(
          (String out) {
            // print('processStdout错误输出为======>$out');
            buffer.write(out);
            callback?.call(out);
            return !resultComp.isCompleted;
          },
        );
      }
      if (getStdout) {
        processStdout.transform(utf8.decoder).every(
          (String out) {
            // print('processStdout输出为======>$out');
            buffer.write(out);
            callback?.call(out);
            if (out.contains('$exitKey') && !resultComp.isCompleted) {
              // Log.e('${script.trim()}释放');
              resultComp.complete(
                buffer.toString().replaceAll('$exitKey', '').trim(),
              );
              return false;
            }
            return true;
          },
        );
      }
      // Log.e('${script.trim()}等待返回');
      String result = await resultComp.future;
      // Log.e('${script.trim()}返回');
      return result;
    });
  }

  Future<bool?> isRoot() async {
    if (_isRoot != null) {
      return _isRoot;
    }
    String idResult = await exec("su -c 'id -u'");
    return _isRoot = idResult == '0';
  }
}
