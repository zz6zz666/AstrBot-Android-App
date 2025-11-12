import 'dart:io';

import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';

/// Create by Nightmare at 2022/03/01
/// 很多个应用都需要启动的时候复制指定的资源
/// 所以就封装了这个类
///
class AssetsManager {
  AssetsManager._();
  static Future<void> copyFiles({
    List<String>? android,
    List<String>? macOS,
    List<String>? windows,
    required List<String> global,
    required String localPath,
    String package = '',
    bool forceCopy = false,
  }) async {
    String logPrefix = 'Change File Permission';
    if (Platform.isAndroid) {
      final Directory dir = Directory(localPath);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      if (android != null) {
        for (final String fileName in android!) {
          final filePath = localPath + fileName.replaceAll(RegExp('.*/'), '');
          try {
            await AssetsUtils.copyAssetToPath('${package}assets/$fileName', filePath, forceCopy: forceCopy);
          } catch (e) {
            Log.e('copy $fileName error $e');
          }
          final ProcessResult result = await Process.run('chmod', ['+x', filePath]);
          Log.d('$logPrefix $fileName stdout:${result.stdout} stderr:${result.stderr}');
        }
      }
    }
    if (Platform.isMacOS) {
      final Directory dir = Directory(localPath);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      for (final String fileName in macOS!) {
        final filePath = localPath + fileName.replaceAll(RegExp('.*/'), '');
        try {
          await AssetsUtils.copyAssetToPath('${package}assets/$fileName', filePath, forceCopy: forceCopy);
        } catch (e) {
          Log.e('copy $fileName error $e');
        }
        final ProcessResult result = await Process.run('chmod', ['+x', filePath]);
        Log.d('$logPrefix $fileName stdout:${result.stdout} stderr:${result.stderr}');
      }
    }
    final Directory dir = Directory(localPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    for (final String fileName in global) {
      final filePath = localPath + fileName.replaceAll(RegExp('.*/'), '');
      try {
        await AssetsUtils.copyAssetToPath('${package}assets/$fileName', filePath, forceCopy: forceCopy);
      } catch (e) {
        Log.e('copy $fileName error $e');
      }
      if (!Platform.isWindows && !Platform.isIOS) {
        final ProcessResult result = await Process.run('chmod', ['+x', filePath]);
        Log.d('$logPrefix $fileName stdout:${result.stdout} stderr:${result.stderr}');
      }
    }
  }
}
