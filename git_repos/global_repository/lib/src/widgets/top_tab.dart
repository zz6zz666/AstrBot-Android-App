import 'package:flutter/material.dart' hide TabController;
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:global_repository/src/controller/tab_controller.dart';
import 'package:window_manager/window_manager.dart';

class TopTab extends StatefulWidget {
  const TopTab({
    Key? key,
    this.value,
    required this.children,
    this.onChanged,
  }) : super(key: key);
  final int? value;
  // final void Function()
  final List<Widget> children;
  final void Function(int index)? onChanged;

  @override
  State<TopTab> createState() => _TopTabState();
}

class _TopTabState extends State<TopTab> with SingleTickerProviderStateMixin {
  TabController tabController = Get.put(TabController());
  late AnimationController controller;
  late Animation offset;
  int? index;
  double tabWidth = 120.w;
  double tabHeight = GetPlatform.isLinux ? 32.w : 24.w;
  double paddingTop = 4.w;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 200,
      ),
    );
    offset = Tween<double>(begin: 0, end: 0).animate(controller);
    index = widget.value;
    tabController.addListener(listenOpenPage);
  }

  @override
  void dispose() {
    controller.dispose();
    tabController.removeListener(listenOpenPage);
    super.dispose();
  }

  void listenOpenPage() {
    offset = Tween<double>(begin: offset.value, end: (tabWidth + 10.w) * tabController.pageindex).animate(controller);
    controller.reset();
    controller.forward();
  }

  String getIcon(int? type) {
    switch (type) {
      case 0:
        return 'assets/icon/phone.png';
      case 1:
        return 'assets/icon/computer.png';
      case 2:
        return 'assets/icon/broswer.png';
      default:
        return 'assets/icon/computer.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color tabColor = Theme.of(context).colorScheme.surfaceContainer;
    if (GetPlatform.isMobile) {
      return const SizedBox();
    }
    return Material(
      color: tabColor,
      child: SizedBox(
        height: tabHeight,
        width: double.infinity,
        child: Row(
          children: [
            if (GetPlatform.isDesktop)
              Expanded(
                child: DragToMoveArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: GetPlatform.isMacOS ? 60.w : 0,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: EdgeInsets.only(top: paddingTop),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: controller,
                                    builder: (context, c) {
                                      return SizedBox(width: offset.value);
                                    },
                                  ),
                                  Stack(
                                    children: [
                                      Material(
                                        color: Theme.of(context).colorScheme.surface,
                                        child: SizedBox(
                                          height: tabHeight,
                                          width: 10.w,
                                        ),
                                      ),
                                      Material(
                                        color: tabColor,
                                        borderRadius: BorderRadius.only(
                                          bottomRight: Radius.circular(16.w),
                                        ),
                                        child: SizedBox(
                                          height: tabHeight,
                                          width: 10.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: tabHeight,
                                    width: tabWidth,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12.w),
                                        topRight: Radius.circular(12.w),
                                      ),
                                    ),
                                  ),
                                  Stack(
                                    children: [
                                      Material(
                                        color: Theme.of(context).colorScheme.surface,
                                        child: SizedBox(
                                          height: tabHeight,
                                          width: 10.w,
                                        ),
                                      ),
                                      Material(
                                        color: tabColor,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(16.w),
                                        ),
                                        child: SizedBox(
                                          height: tabHeight,
                                          width: 10.w,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                SizedBox(width: 10.w),
                                for (int i = 0; i < widget.children.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(top: paddingTop, right: 10.w),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      onTap: () {
                                        index = 0;
                                        offset = Tween<double>(begin: offset.value, end: (tabWidth + 10.w) * i).animate(controller);
                                        controller.reset();
                                        controller.forward();
                                        setState(() {});
                                        // 等待200ms，让动画执行完毕
                                        Future<void>.delayed(const Duration(milliseconds: 200), () {
                                          widget.onChanged?.call(i);
                                        });
                                      },
                                      child: Material(
                                        borderRadius: BorderRadius.only(),
                                        color: Colors.transparent,
                                        child: Stack(
                                          alignment: Alignment.centerRight,
                                          children: [
                                            Container(
                                              height: tabHeight,
                                              width: tabWidth,
                                              child: Center(child: widget.children[i]),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  width: tabHeight,
                                                  height: tabHeight,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(tabHeight / 2),
                                                    onTap: () {
                                                      tabController.closePage(i);
                                                    },
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.clear,
                                                        size: 18.w,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (GetPlatform.isWindows) WindowsActionButtons(),
            if (GetPlatform.isLinux) LinuxActionButtons(),
          ],
        ),
      ),
    );
  }
}

class WindowsActionButtons extends StatefulWidget {
  const WindowsActionButtons({super.key});

  @override
  State<WindowsActionButtons> createState() => _WindowsActionButtonsState();
}

class _WindowsActionButtonsState extends State<WindowsActionButtons> {
  bool isFull = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expanded(
          //   child: DragToMoveArea(
          //     child: Container(
          //       color: Colors.transparent,
          //     ),
          //   ),
          // ),
          WindowCaptionButton.minimize(
            onPressed: () {
              windowManager.minimize();
            },
            brightness: Theme.of(context).brightness,
          ),
          isFull
              ? WindowCaptionButton.unmaximize(
                  onPressed: () {
                    isFull = false;
                    setState(() {});
                    windowManager.unmaximize();
                  },
                  brightness: Theme.of(context).brightness,
                )
              : WindowCaptionButton.maximize(
                  onPressed: () {
                    isFull = true;
                    setState(() {});
                    windowManager.maximize();
                  },
                  brightness: Theme.of(context).brightness,
                ),
          WindowCaptionButton.close(
            onPressed: () {
              windowManager.close();
            },
            brightness: Theme.of(context).brightness,
          ),
        ],
      ),
    );
  }
}

class LinuxActionButtons extends StatefulWidget {
  const LinuxActionButtons({super.key});

  @override
  State<LinuxActionButtons> createState() => _LinuxActionButtonsState();
}

class _LinuxActionButtonsState extends State<LinuxActionButtons> {
  bool isFull = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8.w,
        children: [
          // Expanded(
          //   child: DragToMoveArea(
          //     child: Container(
          //       color: Colors.transparent,
          //     ),
          //   ),
          // ),
          GestureDetector(
            onTap: () {
              windowManager.minimize();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.all(Radius.circular(12.w)),
              ),
              height: 24.w,
              width: 24.w,
              child: Icon(
                Icons.minimize,
                size: 16.w,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (isFull) {
                isFull = false;
                windowManager.unmaximize();
              } else {
                isFull = true;
                windowManager.maximize();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.all(Radius.circular(12.w)),
              ),
              height: 24.w,
              width: 24.w,
              child: Icon(
                isFull ? Icons.unfold_less : Icons.unfold_more,
                size: 16.w,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              windowManager.close();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.all(Radius.circular(12.w)),
              ),
              height: 24.w,
              width: 24.w,
              child: Icon(
                Icons.close,
                size: 16.w,
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
    );
  }
}

// ignore: must_be_immutable
class WindowCaptionButton extends StatefulWidget {
  WindowCaptionButton({
    super.key,
    this.brightness,
    this.icon,
    this.iconName,
    required this.onPressed,
  });

  WindowCaptionButton.close({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  })  : iconName = 'images/ic_chrome_close.png',
        _lightButtonBgColorScheme = _ButtonBgColorScheme(
          normal: Colors.transparent,
          hovered: const Color(0xffC42B1C),
          pressed: const Color(0xffC42B1C).withOpacity(0.9),
        ),
        _lightButtonIconColorScheme = _ButtonIconColorScheme(
          normal: Colors.black.withOpacity(0.8956),
          hovered: Colors.white,
          pressed: Colors.white.withOpacity(0.7),
          disabled: Colors.black.withOpacity(0.3614),
        ),
        _darkButtonBgColorScheme = _ButtonBgColorScheme(
          normal: Colors.transparent,
          hovered: const Color(0xffC42B1C),
          pressed: const Color(0xffC42B1C).withOpacity(0.9),
        ),
        _darkButtonIconColorScheme = _ButtonIconColorScheme(
          normal: Colors.white,
          hovered: Colors.white,
          pressed: Colors.white.withOpacity(0.786),
          disabled: Colors.black.withOpacity(0.3628),
        );

  WindowCaptionButton.unmaximize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = 'images/ic_chrome_unmaximize.png';

  WindowCaptionButton.maximize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = 'images/ic_chrome_maximize.png';

  WindowCaptionButton.minimize({
    super.key,
    this.brightness,
    this.icon,
    this.onPressed,
  }) : iconName = 'images/ic_chrome_minimize.png';

  final Brightness? brightness;
  final Widget? icon;
  final String? iconName;
  final VoidCallback? onPressed;

  _ButtonBgColorScheme _lightButtonBgColorScheme = _ButtonBgColorScheme(
    normal: Colors.transparent,
    hovered: Colors.black.withOpacity(0.0373),
    pressed: Colors.black.withOpacity(0.0241),
  );
  _ButtonIconColorScheme _lightButtonIconColorScheme = _ButtonIconColorScheme(
    normal: Colors.black.withOpacity(0.8956),
    hovered: Colors.black.withOpacity(0.8956),
    pressed: Colors.black.withOpacity(0.6063),
    disabled: Colors.black.withOpacity(0.3614),
  );
  _ButtonBgColorScheme _darkButtonBgColorScheme = _ButtonBgColorScheme(
    normal: Colors.transparent,
    hovered: Colors.white.withOpacity(0.0605),
    pressed: Colors.white.withOpacity(0.0419),
  );
  _ButtonIconColorScheme _darkButtonIconColorScheme = _ButtonIconColorScheme(
    normal: Colors.white,
    hovered: Colors.white,
    pressed: Colors.white.withOpacity(0.786),
    disabled: Colors.black.withOpacity(0.3628),
  );

  _ButtonBgColorScheme get buttonBgColorScheme => brightness != Brightness.dark ? _lightButtonBgColorScheme : _darkButtonBgColorScheme;

  _ButtonIconColorScheme get buttonIconColorScheme => brightness != Brightness.dark ? _lightButtonIconColorScheme : _darkButtonIconColorScheme;

  @override
  State<WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<WindowCaptionButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  void _onEntered({required bool hovered}) {
    setState(() => _isHovering = hovered);
  }

  void _onActive({required bool pressed}) {
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.buttonBgColorScheme.normal;
    Color iconColor = widget.buttonIconColorScheme.normal;

    if (_isHovering) {
      bgColor = widget.buttonBgColorScheme.hovered;
      iconColor = widget.buttonIconColorScheme.hovered;
    }
    if (_isPressed) {
      bgColor = widget.buttonBgColorScheme.pressed;
      iconColor = widget.buttonIconColorScheme.pressed;
    }

    return MouseRegion(
      onExit: (value) => _onEntered(hovered: false),
      onHover: (value) => _onEntered(hovered: true),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onActive(pressed: true),
        onTapCancel: () => _onActive(pressed: false),
        onTapUp: (_) => _onActive(pressed: false),
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minWidth: 46, minHeight: 32),
          decoration: BoxDecoration(
            color: bgColor,
          ),
          child: Center(
            child: WindowCaptionButtonIcon(
              name: widget.iconName!,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonBgColorScheme {
  _ButtonBgColorScheme({
    required this.normal,
    required this.hovered,
    required this.pressed,
  });
  final Color normal;
  final Color hovered;
  final Color pressed;
}

class _ButtonIconColorScheme {
  _ButtonIconColorScheme({
    required this.normal,
    required this.hovered,
    required this.pressed,
    required this.disabled,
  });
  final Color normal;
  final Color hovered;
  final Color pressed;
  final Color disabled;
}
