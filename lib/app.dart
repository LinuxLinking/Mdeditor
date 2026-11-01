import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'file_io/recent_files.dart';
import 'l10n/app_localizations.dart';
import 'ui/editor_page.dart';
import 'ui/home_page.dart';
import 'ui/settings/theme_controller.dart';

class MdeditorApp extends StatelessWidget {
  const MdeditorApp({super.key, this.initialUri, this.navigatorKey});

  final Uri? initialUri;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mdeditor',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeController.flutterMode,
      localizationsDelegates: AppLocalizations.delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeController.scale.value),
          ),
          // 启动占位:Flutter 第一帧渲染一个与 Android splash 视觉一致的 teal 底 +
          // splash 图标,避免 splash 移除时 teal→surface 的底色跳变;首帧后淡出。
          child: _SplashGate(child: child ?? const SizedBox.shrink()),
        );
      },
      home: initialUri == null
          ? const HomePage()
          : EditorPage(initialUri: initialUri, initialName: 'document.md'),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      listTileTheme: const ListTileThemeData(minLeadingWidth: 24),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// 冷启动占位层。在 Flutter 第一帧渲染一个与 Android splash 屏视觉一致的
/// teal 底 + splash 标志,使 Android 系统 splash 移除后不会直接露出 surface
/// (近白/近深)造成"闪进";首帧渲染后再淡出,露出真实 UI。
///
/// 占位层包在 [MaterialApp.builder] 里,位于 Navigator 之上,因此能盖住所有路由。
/// 淡出完成后 [IgnorePointer] 保证它不拦截交互。
class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});

  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _show = true;

  @override
  void initState() {
    super.initState();
    // 等真实 UI 至少渲染一帧,再开始淡出——保证从 Android splash 无缝衔接到
    // Flutter 占位,再从占位淡出到真实 UI,中间没有空白/跳变帧。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _show = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 与 android values/colors.xml 的 launch_bg 完全一致。
    final Color bg =
        isDark ? const Color(0xFF075F5A) : const Color(0xFF0B8F87);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: IgnorePointer(
            child: ColoredBox(
              color: bg,
              child: const Center(
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(painter: _SplashMarkPainter()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 绘制 splash_mark.xml 的同一组 path(96 viewport,已缩进 Android 12 splash
/// 安全区)。用 CustomPainter 手画,避免引入 flutter_svg 依赖。
class _SplashMarkPainter extends CustomPainter {
  const _SplashMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFFFFFFF);
    final Path page = Path()
      ..moveTo(30, 22)
      ..cubicTo(30, 19.8, 31.8, 18, 34, 18)
      ..lineTo(57, 18)
      ..lineTo(66, 27)
      ..lineTo(66, 74)
      ..cubicTo(66, 76.2, 64.2, 78, 62, 78)
      ..lineTo(34, 78)
      ..cubicTo(31.8, 78, 30, 76.2, 30, 74)
      ..close();
    canvas.drawPath(page, paint);

    paint.color = const Color(0xFFB8E5E1);
    final Path fold = Path()
      ..moveTo(57, 18)
      ..lineTo(57, 24)
      ..cubicTo(57, 25.7, 58.3, 27, 60, 27)
      ..lineTo(66, 27)
      ..close();
    canvas.drawPath(fold, paint);

    paint.color = const Color(0xFF0B8F87);
    final Path caret = Path()
      ..moveTo(36, 38)
      ..lineTo(48, 50)
      ..lineTo(60, 38)
      ..lineTo(64, 42)
      ..lineTo(48, 58)
      ..lineTo(32, 42)
      ..close();
    canvas.drawPath(caret, paint);

    paint.color = const Color(0xFF8ACFC9);
    final Path rule = Path()
      ..moveTo(36, 64)
      ..lineTo(60, 64)
      ..cubicTo(61.7, 64, 63, 65.3, 63, 67)
      ..cubicTo(63, 68.7, 61.7, 70, 60, 70)
      ..lineTo(36, 70)
      ..cubicTo(34.3, 70, 33, 68.7, 33, 67)
      ..cubicTo(33, 65.3, 34.3, 64, 36, 64)
      ..close();
    canvas.drawPath(rule, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashMarkPainter oldDelegate) => false;
}

class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.recentFiles,
    required this.themeController,
    required this.child,
  });

  final RecentFiles recentFiles;
  final ThemeController themeController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RecentFiles>.value(value: recentFiles),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: child,
    );
  }
}
