import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:global_repository/src/extension/color_ext.dart';

class ChangeNode {
  ChangeNode(this.title, this.summary);

  final String title;
  final String summary;
}

extension StrExt on String {
  bool get containesSharp => this.contains('#');

  String get removeSharp => this.replaceAll('#', '').trim();
}

///  更新日志
class ChangeLogPage extends StatefulWidget {
  const ChangeLogPage({
    Key? key,
    this.showAppbar = true,
    this.icon,
  }) : super(key: key);
  final bool showAppbar;
  final Widget? icon;

  @override
  State createState() => _ChangeLogPageState();
}

class _ChangeLogPageState extends State<ChangeLogPage> {
  ScrollController scrollController = ScrollController();
  List<ChangeNode> changes = [];
  double angle = 0;
  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      if (scrollController.offset > 100) {
        double radio = scrollController.offset / Get.size.height;
        angle = radio * pi * 2;
        setState(() {});
      }
    });
    loadChangeLog();
  }

  Future<void> loadChangeLog() async {
    String data = await rootBundle.loadString('CHANGELOG.md');
    // Log.i(data);
    RegExp regExp = RegExp('##');
    for (String line in data.split(regExp)) {
      String title = line.split('\n').first.trim();
      String summary = line.replaceAll(title, '').trim();
      changes.add(ChangeNode(title, summary));
    }
    changes.removeAt(0);
    setState(() {});
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildBody(),
        buildRotateIcon(context),
      ],
    );
  }

  Align buildRotateIcon(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(l(36)),
        child: FlippableWidget(
          angle: angle,
          front: Container(
            width: l(48),
            height: l(96),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.opacity02,
              borderRadius: BorderRadius.circular(l(12)),
            ),
            child: Center(
              child: widget.icon == null
                  ? Icon(
                      Icons.update,
                      size: l(40),
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : (widget.icon as dynamic).child,
            ),
          ),
        ),
      ),
    );
  }

  Scaffold buildBody() {
    return Scaffold(
      appBar: widget.showAppbar
          ? AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              title: Text('更新日志'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          controller: scrollController,
          itemCount: changes.length,
          itemBuilder: (c, i) {
            ChangeNode change = changes[i];
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      change.title.removeSharp,
                      style: TextStyle(
                        fontSize: change.title.containesSharp ? l(12) : l(14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: l(4)),
                  if (change.summary.isNotEmpty)
                    GlobalCardItem(
                      padding: EdgeInsets.all(10.w),
                      child: SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: changes[i].summary));
                            showToast('已复制到剪切板');
                          },
                          child: Text(
                            changes[i].summary,
                            style: TextStyle(
                              fontSize: l(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class FlippableWidget extends StatelessWidget {
  final Widget front;
  final double angle;

  const FlippableWidget({
    Key? key,
    required this.front,
    required this.angle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(angle),
      alignment: Alignment.center,
      child: front,
    );
  }
}
