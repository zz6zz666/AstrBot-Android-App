import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:global_repository/src/widgets/screen_query.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:signale/signale.dart';
import 'board_util.dart';
import 'diary_page.dart';
import 'select_tab.dart';

Color surface = Color(0xff050505);
Color surfaceContainer = Color(0xff212121);
Color onSurface = Colors.white;

class ProjBoard extends StatefulWidget {
  const ProjBoard();

  @override
  State<ProjBoard> createState() => _ProjBoardState();
}

class _ProjBoardState extends State<ProjBoard> {
  Map<String, dynamic> projData = {};
  int page = 0;
  int boardPage = 0;
  String time = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    Response<Map<String, dynamic>> result = await Dio().get('https://nightmare.press/YanTool/resources/output.json');
    projData = result.data!;
    time = projData['time'];
    projData.remove('time');
    setState(() {});
  }

  List<Widget> genBoardCards() {
    List<Widget> cards = [];
    for (String key in projData.keys) {
      cards.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: l(12)),
          BoardDetail(data: projData[key]),
          SizedBox(height: l(24)),
        ],
      ));
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    Log.i(l(20));
    bool isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Scaffold(
          backgroundColor: surface,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? l(20) : l(120)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: l(64)),
                  Text(
                    '哈喽大家，为了让大家感知到我现在在做的事，和已经收录的问题，现在我把我自己的项目看板公开',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: l(20),
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                  SizedBox(height: l(20)),
                  Text(
                    '后续会开发一个，需求加急功能，大家对比较关注的问题，可以点赞，我会优先处理',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: l(20),
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                  SizedBox(height: l(20)),
                  Text(
                    '我目前是自由开发，给自己的要求是上一休六',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: l(20),
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                  SizedBox(height: l(20)),
                  Row(
                    children: [
                      Text(
                        '当前页面更新时间：',
                        style: TextStyle(color: onSurface, fontSize: l(20)),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: l(20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: l(20)),
                  SelectTab(
                    onTabChange: (index) {
                      page = index;
                      setState(() {});
                    },
                    value: page,
                    tabs: ['看板', '工作记录&日记'],
                  ),
                  if (projData.isNotEmpty)
                    [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: l(20)),
                          SelectTab(
                            onTabChange: (index) {
                              boardPage = index;
                              setState(() {});
                            },
                            value: boardPage,
                            tabs: projData.keys.map((e) => e.replaceAll('.md', '')).toList(),
                          ),
                          genBoardCards()[boardPage],
                        ],
                      ),
                      DiaryPage(),
                    ][page]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BoardDetail extends StatefulWidget {
  const BoardDetail({Key? key, required this.data}) : super(key: key);
  final String data;

  @override
  State<BoardDetail> createState() => _BoardDetailState();
}

class _BoardDetailState extends State<BoardDetail> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (_) {
        List<BoardCard> boards = getBoardFromMD(widget.data);
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: ScrollController(),
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (BoardCard board in boards)
                    Padding(
                      padding: EdgeInsets.only(right: l(12)),
                      child: SizedBox(
                        width: l(400),
                        child: Column(
                          children: [
                            Text(
                              board.title,
                              style: TextStyle(
                                color: onSurface,
                                fontSize: l(20),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: l(12)),
                            Container(
                              decoration: BoxDecoration(
                                color: surfaceContainer,
                                borderRadius: BorderRadius.circular(l(20)),
                              ),
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: l(8), vertical: l(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < board.items.length; i++)
                                    Builder(builder: (context) {
                                      BoardItem item = board.items[i];
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: surface,
                                          borderRadius: BorderRadius.circular(l(12)),
                                        ),
                                        width: double.infinity,
                                        margin: i == board.items.length - 1 ? null : EdgeInsets.only(bottom: l(12)),
                                        padding: EdgeInsets.all(l(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 0),
                                          child: HighlightedText(
                                            text: item.content,
                                            isDone: item.isDone,
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    Key? key,
    required this.text,
    required this.isDone,
  }) : super(key: key);
  final String text;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    Function l = context.l;
    List<TextSpan> spans = [];
    text.split(' ').forEach((word) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(
            color: isDone ? Theme.of(context).primaryColor.withOpacity(0.7) : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: l(18),
            fontFamily: 'CustomFont',
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(
            color: isDone ? onSurface.withOpacity(0.7) : onSurface,
            fontSize: l(18),
            fontFamily: 'CustomFont',
            fontWeight: FontWeight.w500,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ));
      }
    });
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
