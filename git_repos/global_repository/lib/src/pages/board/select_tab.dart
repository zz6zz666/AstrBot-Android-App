import 'package:flutter/material.dart';
import 'package:global_repository/src/widgets/widgets.dart';

class SelectTab extends StatefulWidget {
  const SelectTab({
    Key? key,
    required this.onTabChange,
    required this.value,
    required this.tabs,
  }) : super(key: key);
  final int value;
  final void Function(int index) onTabChange;
  final List<String> tabs;

  @override
  State<SelectTab> createState() => _SelectTabState();
}

class _SelectTabState extends State<SelectTab> {
  late List<String> tabs = widget.tabs;
  int selectValue = 0;
  late TextStyle style = TextStyle(
    fontSize: l(20),
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context).copyWith(
      brightness: Brightness.dark,
    );
    ColorScheme colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Builder(builder: (context) {
              bool isSelect = selectValue == i;
              return GestureDetector(
                onTap: () {
                  selectValue = i;
                  widget.onTabChange(i);
                  setState(() {});
                },
                child: Container(
                  height: l(40),
                  decoration: BoxDecoration(
                    color: isSelect ? colorScheme.primary : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(l(12)),
                  ),
                  margin: i != tabs.length - 1 ? EdgeInsets.only(right: l(20)) : null,
                  padding: EdgeInsets.symmetric(horizontal: l(20)),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: style.copyWith(
                        color: isSelect ? colorScheme.onPrimary : colorScheme.onSurface,
                        fontSize: l(18),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
