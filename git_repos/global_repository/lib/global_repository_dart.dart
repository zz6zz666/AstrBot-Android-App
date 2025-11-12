library global_repository;

import 'dart:io';

// it can import repo which exported
import '';

export 'src/utils/runtime_environment.dart';
export 'src/utils/file_util.dart';

Future<String> exec(String cmd) async {
  String value = '';
  final ProcessResult result = await Process.run(
    'sh',
    ['-c', cmd],
    environment: envir(),
  );
  value += result.stdout.toString();
  value += result.stderr.toString();
  return value.trim();
}

Map<String, String> envir() {
  final Map<String, String> map = Map.from(Platform.environment);
  if (Platform.isWindows) {
    map['PATH'] = RuntimeEnvir.binPath! + ';' + map['PATH']!;
  } else {
    map['PATH'] = RuntimeEnvir.binPath! + ':' + map['PATH']!;
  }
  return map;
}
