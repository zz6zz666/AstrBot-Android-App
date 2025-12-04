import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';

/// WebView密码管理服务
/// 使用全局存储(box)来保存和管理密码信息
class PasswordManager {
  static const String _storageKey = 'webview_passwords';

  /// 保存或更新密码信息
  /// [url] 页面URL
  /// [username] 用户名
  /// [password] 密码
  static Future<void> savePassword({
    required String url,
    required String username,
    required String password,
  }) async {
    if (box == null) return;

    // 从URL提取域名作为key
    final domain = _extractDomain(url);
    if (domain.isEmpty) return;

    // 获取当前存储的所有密码
    final stored = box!.get(_storageKey, defaultValue: <dynamic, dynamic>{});
    final Map<String, dynamic> passwords = {};

    if (stored is Map) {
      stored.forEach((key, value) {
        if (value is Map) {
          passwords[key.toString()] = {
            'username': value['username']?.toString() ?? '',
            'password': value['password']?.toString() ?? '',
          };
        }
      });
    }

    // 保存或更新当前域名的密码
    passwords[domain] = {
      'username': username,
      'password': password,
    };

    await box!.put(_storageKey, passwords);
    Log.i('已保存密码信息: $domain', tag: 'PasswordManager');
  }

  /// 获取指定URL的密码信息
  /// 返回 {'username': '...', 'password': '...'} 或 null
  static Map<String, String>? getPassword(String url) {
    if (box == null) return null;

    final domain = _extractDomain(url);
    if (domain.isEmpty) return null;

    final stored = box!.get(_storageKey, defaultValue: <dynamic, dynamic>{});
    if (stored is Map) {
      final domainData = stored[domain];
      if (domainData is Map) {
        return {
          'username': domainData['username']?.toString() ?? '',
          'password': domainData['password']?.toString() ?? '',
        };
      }
    }

    return null;
  }

  /// 清除所有密码信息
  static Future<void> clearAllPasswords() async {
    if (box == null) return;
    await box!.delete(_storageKey);
    Log.i('已清除所有密码信息', tag: 'PasswordManager');
  }

  /// 从URL中提取域名
  /// 例如: http://127.0.0.1:6185/login -> 127.0.0.1:6185
  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.host}$port';
    } catch (e) {
      Log.e('提取域名失败: $e', tag: 'PasswordManager');
      return '';
    }
  }
}
