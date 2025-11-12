import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'test.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          child: Builder(builder: (context) {
            double adaptiveWidth = 414;
            ScreenAdapter.init(adaptiveWidth);
            return ScreenQuery(
              uiWidth: adaptiveWidth,
              screenWidth: MediaQuery.of(context).size.width,
              child: child!,
            );
          }),
          landscapePlatforms: ResponsiveTargetPlatform.values,
          breakpoints: const [
            Breakpoint(start: 0, end: 500, name: MOBILE),
            Breakpoint(start: 500, end: 800, name: TABLET),
            Breakpoint(start: 800, end: double.infinity, name: DESKTOP),
          ],
          breakpointsLandscape: [
            const Breakpoint(start: 0, end: 500, name: MOBILE),
            const Breakpoint(start: 500, end: 800, name: TABLET),
            const Breakpoint(start: 800, end: double.infinity, name: DESKTOP),
          ],
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

    final color1 = Color(0xff141414);
    final color2 = Color(0xff050505);
    final contrast = contrastRatio(color1, color2);
    print('Contrast ratio: $contrast');
  }

  @override
  Widget build(BuildContext context) {
    return ProjBoard();
  }
}
