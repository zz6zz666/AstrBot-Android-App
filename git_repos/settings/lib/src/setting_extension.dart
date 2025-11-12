import 'package:flutter/foundation.dart';

import 'impl/default_setting.dart';

DefaultSetting defaultSetting = DefaultSetting();

extension Setting on String {
  SettingNode get setting => SettingNode(this);
}
