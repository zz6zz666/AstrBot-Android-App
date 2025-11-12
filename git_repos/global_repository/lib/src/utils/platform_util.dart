import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:global_repository/global_repository.dart';

Future<String> exec(String cmd) async {
  String value = '';
  final ProcessResult result = await Process.run(
    'sh',
    ['-c', cmd],
    environment: PlatformUtil.envir(),
  );
  value += result.stdout.toString();
  value += result.stderr.toString();
  return value.trim();
}

bool isAddress(String content) {
  final RegExp regExp = RegExp(r'^((25[0-5]|2[0-4]\d|1\d{2}|\d{1,2})\.){3}(25[0-5]|2[0-4]\d|1\d{2}|\d{1,2})$');
  return regExp.hasMatch(content);
}

// TODO 重构成不需要 IO 的方式
// 以适配 Web
//
class PlatformUtil {
  static Future<List<String>> localAddress() async {
    List<String> address = [];
    final List<NetworkInterface> interfaces = await NetworkInterface.list(type: InternetAddressType.any);
    for (final NetworkInterface netInterface in interfaces) {
      // Log.i('netInterface name -> ${netInterface.name}');
      // 遍历网卡
      for (final InternetAddress netAddress in netInterface.addresses) {
        // 遍历网卡的IP地址
        // if (isAddress(netAddress.address)) {
        address.add(netAddress.address);
        // }
      }
    }
    return address;
  }

  static bool isMobilePhone() {
    return Platform.isAndroid || Platform.isIOS;
  }

  static String getLsPath() {
    return '/system/bin/ls';
  }

  // 判断当前的设备是否是桌面设备
  static bool isDesktop() {
    return !isMobilePhone();
  }

  static String getDownloadPath() {
    if (Platform.isAndroid) {
      return '/sdcard/download';
    }
    final Map<String, String> map = Map.from(Platform.environment);
    // print(map);
    return map['HOME']! + '/downloads';
  }

  static Map<String, String> envir() {
    if (kIsWeb) {
      return {};
    }
    final Map<String, String> map = Map.from(Platform.environment);
    if (Platform.isWindows) {
      map['PATH'] = RuntimeEnvir.binPath! + ';' + map['PATH']!;
    } else {
      map['PATH'] = RuntimeEnvir.binPath! + ':' + map['PATH']!;
    }
    return map;
  }

  static Map<String, String> environmentByPackage(String packageName) {
    final Map<String, String> map = Map.from(Platform.environment);
    map['PATH'] = RuntimeEnvir.binPath! + ';' + map['PATH']!;
    return map;
  }

  static Future<bool> cmdIsExist(String cmd) async {
    String stderr;
    String stdout;
    final ProcessResult result = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      [cmd],
      environment: PlatformUtil.envir(),
    );
    stdout = result.stdout.toString();
    stderr = result.stderr.toString();
    // print('stderr->${result.stderr.toString()}');
    // print('stdout->${result.stdout.toString()}');
    if (Platform.isWindows)
      return stderr.isEmpty;
    else
      return stdout.isNotEmpty;
  }

  static Future<String?> getDocumentDirectory() async {
    // 获取外部储存路径的函数
    // 原path_provider中有提供，后来被删除了
    String? path;
    if (Platform.isAndroid) {
      path = '/sdcard';
    } else if (isDesktop()) {
      path = FileSystemEntity.parentOf(Platform.resolvedExecutable);
    }
    return path;
  }
}
