List<BoardCard> getBoardFromMD(String data) {
  String result = removeHeaderFooter(data);
  // 按##标题分割
  RegExp splitPattern = RegExp(r'(?=^## )', multiLine: true);
  List<String> sections = result.split(splitPattern);

  // 去掉空的部分
  sections = sections.where((section) => section.trim().isNotEmpty).toList();

  // 输出分割后的部分

  // 创建 BoardCard 实例列表
  List<BoardCard> cards = [];

  for (String section in sections) {
    // 分割标题和内容
    int firstLineBreak = section.indexOf('\n');
    String title = section.substring(0, firstLineBreak).trim();
    List<String> rawItems = section.substring(firstLineBreak).trim().split('\n');

    List<BoardItem> items = [];
    String currentItem = '';
    bool isDone = false;

    for (String rawItem in rawItems) {
      if (rawItem.startsWith('- [ ]') || rawItem.startsWith('- [x]') || rawItem.startsWith('- [X]')) {
        if (currentItem.isNotEmpty) {
          items.add(BoardItem(currentItem.trim(), isDone));
        }
        isDone = rawItem.startsWith('- [x]') || rawItem.startsWith('- [X]');
        currentItem = rawItem.replaceFirst(RegExp(r'^- \[[ xX]\] '), '');
      } else if (rawItem.startsWith('    ') || rawItem.startsWith('\t')) {
        currentItem += '\n${rawItem.trim()}';
      } else {
        if (currentItem.isNotEmpty) {
          items.add(BoardItem(currentItem.trim(), isDone));
        }
        currentItem = rawItem.trim();
      }
    }

    if (currentItem.isNotEmpty) {
      items.add(BoardItem(currentItem.trim(), isDone));
    }

    // 创建 BoardCard 实例并添加到列表中
    cards.add(BoardCard(title.replaceAll('##', ''), items));
  }

  // 输出 BoardCard 实例列表
  // for (BoardCard card in cards) {
  //   print(card);
  //   print('---\n');
  // }
  return cards;
}

String removeHeaderFooter(String data) {
  // 使用正则表达式匹配需要去除的部分
  // 使用正则表达式匹配并去除---和---之间的所有内容
  String result = data;
  RegExp pattern = RegExp(r'^---[\s\S]*?---\n', multiLine: true);
  result = result.replaceAll(pattern, '');

  // 去除kanban设置部分
  pattern = RegExp(r'\n%% kanban:settings[\s\S]*?%%', multiLine: true);
  result = result.replaceAll(pattern, '');

  return result;
}

class BoardCard {
  String title;
  List<BoardItem> items;
  BoardCard(this.title, this.items);

  @override
  String toString() {
    return 'Title: $title\nItems: ${items.join("\n")}';
  }
}

class BoardItem {
  String content;
  final bool isDone;
  BoardItem(this.content, this.isDone);

  @override
  String toString() {
    return '${isDone ? "[x]" : "[ ]"} $content';
  }
}
