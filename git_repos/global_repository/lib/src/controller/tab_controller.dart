import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PageEntity {
  final String title;
  final Widget page;
  PageEntity({
    required this.title,
    required this.page,
  });
}

class TabController extends GetxController {
  int pageindex = 0;
  List<PageEntity> pages = [];

  /// 用于切换页面
  void openPage(PageEntity page) {
    pages.add(page);
    pageindex = pages.length - 1;
    update();
  }

  /// 用于关闭页面
  void closePage(int index) {
    if (index == 0) {
      return;
    }
    pages.removeAt(index);
    pageindex = pages.length - 1;
    update();
  }

  /// 初始化页面
  void setInitPage(PageEntity page) {
    if (pages.isNotEmpty) {
      return;
    }
    pages = [page];
    update();
  }

  void changePage(int index) {
    pageindex = index;
    update();
  }
}
