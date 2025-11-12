import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:global_repository/src/utils/utils.dart';

import 'custom_icon_button.dart';

class DrawerOpenButton extends StatelessWidget {
  const DrawerOpenButton({Key? key, this.scaffoldContext}) : super(key: key);
  final BuildContext? scaffoldContext;

  @override
  Widget build(BuildContext context) {
    return NiIconButton(
      child: Icon(
        Icons.menu,
        size: 24.w,
      ),
      onTap: () {
        Scaffold.of(scaffoldContext ?? context).openDrawer();
      },
    );
  }
}
