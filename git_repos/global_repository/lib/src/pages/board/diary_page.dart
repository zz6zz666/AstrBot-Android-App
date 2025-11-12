import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:global_repository/global_repository.dart';
import 'package:global_repository/src/pages/about_page.dart';
import 'package:global_repository/src/widgets/widgets.dart';
import 'package:signale/signale.dart';

Color surface = Color(0xff050505);
Color surfaceContainer = Color(0xff101010);
Color onSurface = Colors.white;
// 二级标题：Secondary Heading 或 Subheading
// 三级标题：Tertiary Heading

extension StrExt on String {
  bool get isSubHeading => this.startsWith('## ');
  bool get isTertiaryHeading => this.startsWith('### ');
  String get removeHeading => this.replaceAll(RegExp(r'^(## |### )'), '');
}

class DiaryNode {
  DiaryNode(this.title, this.summary);

  final String title;
  String summary;
  final List<DiaryNode> children = [];
}

class DiaryPage extends StatefulWidget {
  const DiaryPage({Key? key}) : super(key: key);

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  String diary = '';
  int page = 0;
  String time = '';
  List<DiaryNode> diaries = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    Response<String> result = await Dio().get('https://nightmare.press/YanTool/resources/工作记录与日记.md');
    diary = result.data!;
    RegExp regExp = RegExp(r'^(## .+|### .+)$', multiLine: true);
    List<String> lines = diary.split('\n');
    DiaryNode? currentNode;
    StringBuffer currentSummary = StringBuffer();

    for (String line in lines) {
      if (regExp.hasMatch(line)) {
        if (currentNode != null && currentSummary.isNotEmpty) {
          currentNode.summary = currentSummary.toString().trim();
          if (currentNode.title.startsWith('## ')) {
            diaries.add(currentNode);
          } else if (currentNode.title.startsWith('### ')) {
            diaries.last.children.add(currentNode);
          }
        }
        currentNode = DiaryNode(line.trim(), '');
        currentSummary.clear();
      } else {
        currentSummary.writeln(line);
      }
    }

    if (currentNode != null && currentSummary.isNotEmpty) {
      currentNode.summary = currentSummary.toString().trim();
      if (currentNode.title.startsWith('## ')) {
        diaries.add(currentNode);
      } else if (currentNode.title.startsWith('### ')) {
        diaries.last.children.add(currentNode);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Padding(
        padding: EdgeInsets.only(top: l(12)),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: l(100)),
          itemCount: diaries.length,
          itemBuilder: (c, i) {
            DiaryNode diary = diaries[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: l(8)),
                  child: Text(
                    diary.title.removeHeading,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: l(20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: l(10)),
                if (diary.summary.isNotEmpty)
                  Material(
                    borderRadius: BorderRadius.circular(l(12)),
                    clipBehavior: Clip.hardEdge,
                    color: Color(0xff141414),
                    child: Padding(
                      padding: EdgeInsets.all(l(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diary.summary,
                            style: TextStyle(
                              color: onSurface,
                              fontSize: l(18),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          for (DiaryNode child in diary.children)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: l(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.title.removeHeading,
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: l(18),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: l(10)),
                                  if (child.summary.isNotEmpty)
                                    Material(
                                      borderRadius: BorderRadius.circular(l(12)),
                                      clipBehavior: Clip.hardEdge,
                                      color: const Color(0xff050505),
                                      child: Padding(
                                        padding: EdgeInsets.all(l(10)),
                                        child: Text(
                                          child.summary,
                                          style: TextStyle(
                                            color: onSurface,
                                            fontSize: l(16),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: l(20)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: l(20)),
              ],
            );
          },
        ),
      ),
    );
  }
}
