import 'dart:io';

import 'package:signale/signale.dart';

Future<int?> getSafePort(int rangeStart, int rangeEnd) async {
  if (rangeStart == rangeEnd) {
    // 说明都失败了
    return null;
  }
  try {
    ServerSocket serverSocket = await ServerSocket.bind(
      '0.0.0.0',
      rangeStart,
      shared: true,
    );
    serverSocket.close();
    return rangeStart;
  } catch (e) {
    return await getSafePort(rangeStart + 1, rangeEnd);
  }
}
