import 'package:flutter/material.dart';

Future<T?> showCustomDialog<T>({
  required BuildContext context,
  Duration duration = const Duration(milliseconds: 300),
  double? height,
  Widget? child,
  bool bval = true,
  bool ispadding = true,
  String? tag,
}) {
  // print(tag);
  //if (tag == null) tag = "dialog";
  return showDialog<T>(
    context: context,
    barrierDismissible: bval, // user must tap button!
    builder: (BuildContext context) {
      return DialogBuilder(
        tag: tag,
        isPadding: ispadding,
        duration: duration,
        height: height ?? 0,
        child: child,
      );
    },
  );
}

class Height {
  Height(this.height);
  final double height;
}

class DialogBuilder extends StatefulWidget {
  const DialogBuilder({
    Key? key,
    this.child,
    this.actions,
    this.title,
    this.padding = const EdgeInsets.symmetric(
      vertical: 8.0,
      horizontal: 16.0,
    ),
    this.duration = const Duration(milliseconds: 1000),
    this.height = 1000,
    this.tag,
    this.isPadding = true,
  }) : super(key: key);

  final Widget? child;
  final List<Widget>? actions;
  final Widget? title;
  final EdgeInsetsGeometry padding;
  final Duration duration;
  final double height;
  final String? tag;
  final bool isPadding;
  static void changeHeight(double height) {
    // dialogeventBus.fire(Height(height));
  }

  @override
  State<StatefulWidget> createState() => DialogBuilderState();
}

// EventBus dialogeventBus;

class DialogBuilderState extends State<DialogBuilder> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> dialogHeight;
  late Animation<double> curve;
  Key? _key;

  @override
  void initState() {
    super.initState();
    if (widget.tag != null)
      _key = GlobalObjectKey(widget.tag!);
    else
      _key = GlobalKey();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    curve = CurvedAnimation(parent: _animationController, curve: Curves.ease);
    dialogHeight = Tween<double>(
      begin: 0,
      end: widget.height,
    ).animate(curve);
    dialogHeight.addListener(() {
      setState(() {});
    });
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback(_onAfterRendering);
    super.didChangeDependencies();
  }

  Future<void> _onAfterRendering(Duration timeStamp) async {
    // dialogeventBus = EventBus()
    //   ..on<Height>().listen((Height event) {
    //     dialogHeight = Tween<double>(
    //       begin: dialogHeight.value,
    //       end: event.height,
    //     ).animate(curve);
    //     if (_animationController != null) {
    //       _animationController.reset();
    //       _animationController.forward();
    //     }
    //   });
  }

  @override
  void dispose() {
    _animationController.dispose();
    // dialogeventBus.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      key: _key,
      backgroundColor: Colors.transparent,
      child: Material(
        shadowColor: Theme.of(context).scaffoldBackgroundColor == Colors.black ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.6),
        elevation: 0.0,
        color: Theme.of(context).dialogBackgroundColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
          Radius.circular(12.0),
        )),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(12.0),
          ),
          child: Padding(
            padding: widget.isPadding ? const EdgeInsets.all(6.0) : const EdgeInsets.all(0),
            child: SizedBox(
              height: dialogHeight.value,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

//这个Widget会默认把ListView显示到最大
class FullHeightListView extends StatefulWidget {
  const FullHeightListView({Key? key, this.child}) : super(key: key);
  final Widget? child;

  @override
  _FullHeightListViewState createState() => _FullHeightListViewState();
}

class _FullHeightListViewState extends State<FullHeightListView> {
  final ScrollController _scrollController = ScrollController();
  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback(_onAfterRendering);
    super.didChangeDependencies();
  }

  Future<void> _onAfterRendering(Duration timeStamp) async {
    // dialogeventBus.fire(Height(
    //   _scrollController.position.viewportDimension +
    //       _scrollController.position.maxScrollExtent,
    // ));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // print(cont)
    return SizedBox(
      child: ListView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          widget.child!,
        ],
      ),
    );
  }
}
