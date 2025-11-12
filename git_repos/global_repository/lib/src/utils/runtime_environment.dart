// 多个包在单独运行的时候会是独立的包名
// 而当被集成的时候，应该拿它所集成到的项目的包名
// 所以在代码中不应该使用自身的配置文件中的路径来进行读写

import 'dart:io';

// import 'package:flutter/foundation.dart';
import 'package:global_repository/src/utils/document/document.dart';
import 'package:path/path.dart';

String _binKey = 'BIN';
String _tmpKey = 'TMP';
String _homeKey = 'HOME';
String _internalKey = 'INTERNAL';
String _configKey = 'CONFIG';
String _filesKey = 'FILES';
String _usrKey = 'USR';
// 在安卓端是沙盒路径
String _dataKey = 'DATA';
String _pathKey = 'PATH';

class RuntimeEnvir {
  static bool _isInit = false;
  static Map<String, dynamic> _environment = {};
  static Map<String, dynamic> get environment => _environment;
  static String? _packageName;
  static String? get packageName => _packageName;

  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static void initEnvirFromMap(Map<String, dynamic> map) {
    _environment = map;
    _isInit = true;
  }

  static void initEnvirWithPackageName(
    String packageName, {
    String? appSupportDirectory,
  }) {
    if (isWeb || _isInit) {
      return;
    }
    _packageName = packageName;
    if (!isWeb && isDesktop) {
      _initEnvirForDesktop(
        packageName,
        appSupportDirectory: appSupportDirectory,
      );
      return;
    }
    if (Platform.isIOS) {
      _environment[_dataKey] = appSupportDirectory;
    } else {
      _environment[_dataKey] = '/data/data/$packageName';
    }
    _environment[_filesKey] = '${_environment[_dataKey]}/files';
    Directory(_environment[_filesKey]).createSync();
    _environment[_configKey] = '${_environment[_dataKey]}/files';
    _environment[_usrKey] = '${_environment[_filesKey]}/usr';
    _environment[_binKey] = '${_environment[_usrKey]}/bin';
    _environment[_homeKey] = '${_environment[_filesKey]}/home';
    _environment[_tmpKey] = '${_environment[_usrKey]}/tmp';
    if (!Platform.isIOS) {
      _environment[_pathKey] = '${_environment[_binKey]}:' + Platform.environment['PATH']!;
    }
    _isInit = true;
  }

  // 这个不再开放，统一只调用initEnvirWithPackageName函数
  // 即使是PC也需要用packageName来作为标识独立运行
  // 还是作为集成包运行
  static void _initEnvirForDesktop(
    String package, {
    String? appSupportDirectory,
  }) {
    if (_isInit) {
      return;
    }
    String execPath = dirname(Platform.resolvedExecutable);
    String s = Platform.pathSeparator;
    String execDataPath = execPath + s + 'data';
    String execBinPath = execPath + s + 'data${s}usr${s}bin';
    String dataPath = appSupportDirectory ?? execDataPath;
    Directory dataDir = Directory(dataPath);
    if (Platform.isLinux) {
      String configPath = Platform.environment['HOME']! + '/.config/$package';
      Directory configDir = Directory(configPath);
      if (!configDir.existsSync()) {
        configDir.createSync();
      }
      _environment[_configKey] = configPath;
    } else {
      if (!dataDir.existsSync()) {
        dataDir.createSync();
      }
      _environment[_configKey] = dataPath;
    }
    _environment[_dataKey] = dataPath;
    _environment[_filesKey] = dataPath;
    _environment[_usrKey] = '$dataPath${s}usr';
    _environment[_binKey] = '${_environment[_usrKey]}${s}bin';
    _environment[_homeKey] = '$dataPath${s}home';
    _environment[_tmpKey] = '${_environment[_usrKey]}${s}tmp';
    if (Platform.isWindows) {
      _environment[_pathKey] = '$execBinPath;' + '${_environment[_binKey]};' + Platform.environment['PATH']!;
    } else {
      _environment[_pathKey] = '$execBinPath/:' + '${_environment[_binKey]}:' + Platform.environment['PATH']!;
    }
    _isInit = true;
  }

  static Map<String, String> envir() {
    final Map<String, String> map = Map.from(Platform.environment);
    map['PATH'] = path;
    return map;
  }

  static void put(String key, dynamic value) {
    _environment[key] = value;
  }

  static dynamic get(String key) {
    if (_environment.containsKey(key)) {
      return _environment[key];
    }
    return '';
  }

  static String get binPath {
    if (_environment.containsKey(_binKey)) {
      return _environment[_binKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  /// 这是是 PATH 这个变量的值
  static String get path {
    if (_environment.containsKey(_pathKey)) {
      return _environment[_pathKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static String get dataPath {
    if (_environment.containsKey(_dataKey)) {
      return _environment[_dataKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static String get configPath {
    if (_environment.containsKey(_configKey)) {
      return _environment[_configKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static set binPath(String? value) {
    _environment[_binKey] = value;
  }

  static String get usrPath {
    if (_environment.containsKey(_usrKey)) {
      return _environment[_usrKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static set usrPath(String? value) {
    _environment[_usrKey] = value;
  }

  static String get tmpPath {
    if (_environment.containsKey(_tmpKey)) {
      return _environment[_tmpKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static set tmpPath(String? value) {
    _environment[_tmpKey] = value;
  }

  static String get homePath {
    if (_environment.containsKey(_homeKey)) {
      return _environment[_homeKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static set homePath(String? value) {
    _environment[_homeKey] = value;
  }

  static String get filesPath {
    if (_environment.containsKey(_filesKey)) {
      return _environment[_filesKey];
    }
    if (!isWeb) throw Exception();
    return '';
  }

  static set filesPath(String? value) {
    _environment[_filesKey] = value;
  }
}
