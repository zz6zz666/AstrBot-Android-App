import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:global_repository/global_repository.dart';

class PrivacyAgreePage extends StatefulWidget {
  const PrivacyAgreePage({
    Key? key,
    this.onAgreeTap,
  }) : super(key: key);
  final void Function()? onAgreeTap;

  @override
  State<PrivacyAgreePage> createState() => _PrivacyAgreePageState();
}

class _PrivacyAgreePageState extends State<PrivacyAgreePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: PrivacyPage()),
            Row(
              children: [
                Expanded(
                  child: GestureWithScale(
                    onTap: () {
                      SystemNavigator.pop();
                    },
                    child: Container(
                      height: 48.w,
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      child: Center(
                        child: Text(
                          '我不同意',
                          style: TextStyle(
                            fontSize: 16.w,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureWithScale(
                    onTap: () {
                      widget.onAgreeTap?.call();
                    },
                    child: Container(
                      color: Theme.of(context).primaryColor,
                      height: 48.w,
                      child: Center(
                        child: Text(
                          '同意继续',
                          style: TextStyle(
                            fontSize: 16.w,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({Key? key}) : super(key: key);

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String? data;
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/privacy_policy.md').then((value) {
      data = value;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        left: false,
        child: Markdown(
          controller: ScrollController(),
          selectable: true,
          data: data ?? '加载协议中',
        ),
      ),
    );
  }
}
