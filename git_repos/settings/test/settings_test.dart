import 'package:settings/settings.dart';

Future<void> main() async {
  await initSettingStore('./test');
  SettingNode node = 'test'.setting;
  print('node.get -> ${node.get()}');
  node.set('123');
  print('node.get -> ${node.get()}');
}
