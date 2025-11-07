import 'dart:io';
import 'package:flutter/services.dart';

// 运行时环境类
class RuntimeEnvir {
  static final String tmpPath = '/data/data/com.astrobot.code_lfa/files/tmp';
  static final String homePath = '/data/data/com.astrobot.code_lfa/files/home';
  static final String binPath = '/data/data/com.astrobot.code_lfa/files/bin';
  static final String libPath = '/data/data/com.astrobot.code_lfa/files/lib';
  
  // 初始化运行时环境
  static void init() {
    // 创建必要的目录
    Directory(tmpPath).createSync(recursive: true);
    Directory(homePath).createSync(recursive: true);
    Directory(binPath).createSync(recursive: true);
    Directory(libPath).createSync(recursive: true);
  }
}

// 资产工具类
class AssetsUtils {
  // 从assets复制文件到指定路径
  static Future<void> copyAssetToPath(String assetPath, String targetPath) async {
    try {
      ByteData data = await rootBundle.load(assetPath);
      List<int> bytes = data.buffer.asUint8List();
      File file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // 设置执行权限
      await Process.run('chmod', ['0755', targetPath]);
    } catch (e) {
      print('复制资产失败: $e');
      rethrow;
    }
  }
  
  // 检查assets文件是否存在
  static Future<bool> assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// 文件扩展方法
extension FileExtension on File {
  // 修改文件权限
  Future<void> chmod(int mode) async {
    try {
      await Process.run('chmod', [mode.toRadixString(8), path]);
    } catch (e) {
      print('修改文件权限失败: $e');
    }
  }
  
  // 获取文件大小
  Future<int> get size async {
    try {
      if (existsSync()) {
        return lengthSync();
      }
      return 0;
    } catch (e) {
      print('获取文件大小失败: $e');
      return 0;
    }
  }
}

// 字符串扩展方法
extension StringExtension on String {
  // 安全的子字符串
  String safeSubstring(int start, [int? end]) {
    if (isEmpty) return '';
    if (start >= length) return '';
    if (end != null && end <= start) return '';
    if (end != null && end > length) {
      return substring(start);
    }
    return substring(start, end);
  }
  
  // 移除字符串中的ANSI转义序列
  String removeAnsi() {
    return replaceAll(RegExp(r'\u001b\[[\d;]*[a-zA-Z]'), '');
  }
}

// 通用工具函数
class Utils {
  // 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  // 执行命令并获取输出
  static Future<String> executeCommand(String command, List<String> args) async {
    try {
      final result = await Process.run(command, args);
      return '${result.stdout}\n${result.stderr}';
    } catch (e) {
      return '执行命令失败: $e';
    }
  }
  
  // 检查目录是否可写
  static Future<bool> isDirectoryWritable(String path) async {
    try {
      Directory dir = Directory(path);
      if (!dir.existsSync()) return false;
      
      // 创建临时文件测试
      File testFile = File('$path/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}