import 'dart:io';

import 'package:signale/signale.dart';

typedef CallBack = void Function(String address);

class HttpServerUtil {
  static void bindServer(int port, CallBack callBack) {
    HttpServer.bind('::', port, shared: true).then((server) {
      //显示服务器地址和端口
      Log.i('Serving at ${server.address}:${server.port}');
      //通过编写HttpResponse对象让服务器响应请求
      server.listen((HttpRequest request) {
        //HttpResponse对象用于返回客户端
        Log.i('${request.connectionInfo!.remoteAddress} ${request.method}');
        request.response
          ..headers.contentType = ContentType('text', 'plain', charset: 'utf-8')
          ..write('success')
          //结束与客户端连接
          ..close();
        // 这儿感觉短时间内call了两次，考虑做个防抖
        callBack.call(request.connectionInfo!.remoteAddress.address);
      });
    });
  }
}
