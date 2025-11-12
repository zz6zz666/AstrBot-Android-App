import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:settings/src/interface/setting.dart';

class DefaultSetting implements Setting {
  @override
  dynamic get(String key, defaultValue) {
    return box!.get(key, defaultValue: defaultValue);
  }

  @override
  void set(String key, dynamic value) {
    box!.put(key, value);
  }
}

Box? box;

Future<void> initSettingStore(String path) async {
  box ??= await Hive.openBox('setting', path: path);
}

Map<SettingNode, ValueNotifier> _valueMap = {};

class SettingNode {
  SettingNode(this.key);
  final String key;
  ValueNotifier get ob {
    if (_valueMap.containsKey(this)) {
      return _valueMap[this]!;
    } else {
      return _valueMap[this] = ValueNotifier(get());
    }
  }

  dynamic get value {
    return get();
  }

  set value(dynamic value) {
    set(value);
    ob.value = value;
  }

  dynamic get() {
    return box!.get(key, defaultValue: null);
  }

  void set(dynamic value) {
    box!.put(key, value);
  }
}
