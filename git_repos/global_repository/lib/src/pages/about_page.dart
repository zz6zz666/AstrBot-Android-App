import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:global_repository/generated/l10n.dart';
import 'package:global_repository/global_repository.dart';
import 'package:global_repository/src/extension/color_ext.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher_string.dart';

FontWeight? _bold = GetPlatform.isLinux ? null : FontWeight.bold;
String _defaultApplicationName(BuildContext context) {
  // This doesn't handle the case of the application's title dynamically
  // changing. In theory, we should make Title expose the current application
  // title using an InheritedWidget, and so forth. However, in practice, if
  // someone really wants their application title to change dynamically, they
  // can provide an explicit applicationName to the widgets defined in this
  // file, instead of relying on the default.
  final Title? ancestorTitle = context.findAncestorWidgetOfExactType<Title>();
  return ancestorTitle?.title ?? Platform.resolvedExecutable.split(Platform.pathSeparator).last;
}

String baseUri = 'http://nightmare.press';

// const int opacity

/// 关于页面
class AboutPage extends StatelessWidget {
  const AboutPage({
    Key? key,
    this.appVersion = '1.0.0',
    this.versionCode = '1',
    this.applicationName,
    this.coolapkLink,
    this.license,
    this.logo = const SizedBox(),
    this.otherVersionLink,
    this.openSourceLink,
    this.hasTerms = false,
    this.canOpenDrawer = true,
    this.showAppbar = true,
  }) : super(key: key);

  final String appVersion;
  final String versionCode;
  final String? applicationName;
  final String? coolapkLink;
  final String? license;
  final String? otherVersionLink;
  final String? openSourceLink;
  final Widget logo;
  final bool hasTerms;
  final bool canOpenDrawer;
  final bool showAppbar;

  @override
  Widget build(BuildContext context) {
    S.load(Localizations.localeOf(context));
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Localizations(
      locale: Localizations.localeOf(context),
      delegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: Builder(builder: (context) {
        AppBar? appBar;
        final appName = applicationName ?? _defaultApplicationName(context);
        if (showAppbar && ResponsiveBreakpoints.of(context).isMobile) {
          appBar = AppBar(
            title: Text(S.of(context).aboutTitle),
            leading: canOpenDrawer ? DrawerOpenButton(scaffoldContext: context) : null,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.dark,
            ),
          );
        }
        return Scaffold(
          body: Column(
            children: [
              if (appBar != null) appBar,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.l(12)),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    controller: ScrollController(),
                    padding: EdgeInsets.only(bottom: context.l(48)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: context.l(24)),
                        logo,
                        SizedBox(height: context.l(8)),
                        Text(
                          appName,
                          style: TextStyle(
                            fontSize: context.l(20),
                            fontWeight: _bold,
                          ),
                        ),
                        SizedBox(height: context.l(24)),
                        GlobalCardItem(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SettingItem(
                                title: S.current.currentVersion,
                                suffix: Text(
                                  '$appVersion($versionCode)',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.opacity06,
                                    fontSize: context.l(16),
                                  ),
                                ),
                              ),
                              _SettingItem(
                                title: S.current.ref,
                                suffix: Text(
                                  'dev',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.opacity06,
                                    fontSize: context.l(16),
                                  ),
                                ),
                              ),
                              _SettingItem(
                                title: S.current.changelog,
                                onTap: () {
                                  openPage(
                                    ChangeLogPage(
                                      icon: logo,
                                    ),
                                    title: S.current.changelog,
                                  );
                                },
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: context.l(16),
                                ),
                              ),
                              if (otherVersionLink != null)
                                _SettingItem(
                                  title: S.current.otherVersionDownload,
                                  suffix: Icon(
                                    Icons.arrow_forward_ios,
                                    size: context.l(16),
                                  ),
                                  onTap: () async {
                                    if (otherVersionLink == null) {
                                      return;
                                    }
                                    String url = otherVersionLink!;
                                    if (await canLaunchUrlString(url)) {
                                      await launchUrlString(
                                        url,
                                        mode: LaunchMode.externalNonBrowserApplication,
                                      );
                                    } else {
                                      throw 'Could not launch $url';
                                    }
                                  },
                                ),
                              if (openSourceLink != null)
                                _SettingItem(
                                  title: '${applicationName ?? '应用'} ${S.current.openSourceLink}',
                                  suffix: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16.w,
                                  ),
                                  onTap: () async {
                                    String url = openSourceLink!;
                                    if (await canLaunchUrlString(url)) {
                                      await launchUrlString(
                                        url,
                                        mode: LaunchMode.externalNonBrowserApplication,
                                      );
                                    } else {
                                      throw 'Could not launch $url';
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.w),
                        GlobalCardItem(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              if (hasTerms)
                                _SettingItem(
                                  title: '服务条款',
                                  suffix: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16.w,
                                  ),
                                ),
                              _SettingItem(
                                title: S.current.privacyPolicy,
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.w,
                                ),
                                onTap: () {
                                  openPage(const PrivacyPage(), title: '隐私政策');
                                },
                              ),
                              _SettingItem(
                                title: S.current.OpenSourceLicenses,
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.w,
                                ),
                                onTap: () {
                                  openPage(
                                    LicensePage(
                                      applicationName: appName,
                                    ),
                                    title: '开源协议',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.w),
                        GlobalCardItem(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SettingItem(
                                title: 'github.com/mengyanshou',
                                subTitle: '关注开发者Github',
                                prefix: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.w),
                                  child: ClipOval(
                                    child: Image.network(
                                      '$baseUri/YanTool/image/hong.jpg',
                                      width: 44.w,
                                    ),
                                  ),
                                ),
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.w,
                                ),
                                onTap: () async {
                                  const String url = 'https://github.com/mengyanshou';
                                  if (await canLaunchUrlString(url)) {
                                    await launchUrlString(
                                      url,
                                      mode: LaunchMode.externalNonBrowserApplication,
                                    );
                                  } else {
                                    throw 'Could not launch $url';
                                  }
                                },
                              ),
                              SizedBox(height: 8.w),
                              _SettingItem(
                                title: '梦魇兽',
                                subTitle: '关注开发者酷安',
                                prefix: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.w),
                                  child: ClipOval(
                                    child: Image.network(
                                      '$baseUri/YanTool/image/hong.jpg',
                                      width: 44.w,
                                    ),
                                  ),
                                ),
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.w,
                                ),
                                onTap: () async {
                                  const String url = 'http://www.coolapk.com/u/1345256';
                                  if (await canLaunchUrlString(url)) {
                                    await launchUrlString(
                                      url,
                                      mode: LaunchMode.externalNonBrowserApplication,
                                    );
                                  } else {
                                    throw 'Could not launch $url';
                                  }
                                },
                              ),
                              SizedBox(height: 8.w),
                              _SettingItem(
                                title: '其他相关软件下载',
                                subTitle: '“无界”、“魇·工具箱”、“速享”、“Code FA”等相关作品下载',
                                prefix: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.w),
                                  child: ClipOval(
                                    child: Image.network(
                                      '$baseUri/YanTool/image/hong.jpg',
                                      width: 44.w,
                                    ),
                                  ),
                                ),
                                suffix: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.w,
                                ),
                                onTap: () async {
                                  String url = '$baseUri';
                                  if (await canLaunchUrlString(url)) {
                                    await launchUrlString(
                                      url,
                                      mode: LaunchMode.externalNonBrowserApplication,
                                    );
                                  } else {
                                    throw 'Could not launch $url';
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.w),
                        if (license != null)
                          GlobalCardItem(
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: EdgeInsets.all(context.l(10)),
                                child: Text(
                                  license!,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: context.l(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SettingItem extends StatefulWidget {
  const _SettingItem({
    Key? key,
    this.title,
    this.onTap,
    this.subTitle = '',
    this.suffix = const SizedBox(),
    this.prefix,
  }) : super(key: key);

  final String? title;
  final String subTitle;
  final void Function()? onTap;
  final Widget suffix;
  final Widget? prefix;
  @override
  State createState() => _SettingItemState();
}

class _SettingItemState extends State<_SettingItem> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      // highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: l(12),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: l(48)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (widget.prefix != null)
                  Padding(
                    padding: EdgeInsets.only(right: l(6)),
                    child: widget.prefix,
                  ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              widget.title ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: l(14),
                                // height: 1.0,
                              ),
                            ),
                            if (widget.subTitle.isNotEmpty)
                              Builder(builder: (_) {
                                final String content = widget.subTitle;
                                return Column(
                                  children: [
                                    SizedBox(height: 4.w),
                                    Text(
                                      content,
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                        // height: 1.0,
                                        fontSize: 12.w,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      widget.suffix,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalCardItem extends StatelessWidget {
  const GlobalCardItem({
    Key? key,
    required this.child,
    this.padding,
    this.backgroundColor,
  }) : super(key: key);
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12.w),
      clipBehavior: Clip.hardEdge,
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: padding ?? EdgeInsets.all(8.w),
        child: child,
      ),
    );
  }
}
