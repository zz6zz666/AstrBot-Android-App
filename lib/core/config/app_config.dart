const bool product = bool.fromEnvironment('dart.vm.product');

class Config {
  static const String packageName = 'com.astrbot.astrbot_android';
  static const String versionName = '1.5.0';

  // 修改端口号为新的值
  static const int port = 6185;

  // Ubuntu系统镜像文件名
  static const String ubuntuFileName = 'ubuntu-noble-aarch64-pd-v4.18.0.tar.xz';
}
