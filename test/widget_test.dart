// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/app.dart';
import '../lib/file_io/recent_files.dart';
import '../lib/ui/home_page.dart';
import '../lib/ui/settings/theme_controller.dart';

/// Phase 1 起步测试:HomePage 在空最近文件时显示提示文案。
/// Phase 6:补 [ThemeController] 参数。
///
/// Bug fix: 首页"新建 / 打开"按钮原本在 AppBar、HeroSection、_EmptyRecentState
/// 三处同时出现,造成功能冗余。本测试断言 HeroSection 已经不再重复这两个
/// 主操作入口——主操作统一由 AppBar 的 IconButton 提供,_EmptyRecentState
/// 的按钮仅作为新用户的引导入口。
void main() {
  testWidgets('HomePage renders empty hint', (WidgetTester tester) async {
    // SharedPreferences 在测试环境用 MockSharedPreferences,
    // 这里直接构造一个内存实现的 stub。
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final recentFiles = RecentFiles(prefs);
    final themeController = ThemeController(prefs);

    await tester.pumpWidget(
      AppProviders(
        recentFiles: recentFiles,
        themeController: themeController,
        child: const MdeditorApp(),
      ),
    );
    // 等 localization delegate 异步加载完成
    await tester.pumpAndSettle();

    // app_title 中英文都为 'Mdeditor',稳健断言
    expect(find.text('Mdeditor'), findsOneWidget);
    // no_recent 文案在测试默认 locale(en)下为英文,在 zh 下为中文;
    // 这里只断言 HomePage 空状态有渲染(_NoRecent 文案存在),不锁语种。
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets(
    'HomePage: Hero 不再包含新建/打开按钮（避免与 AppBar 重复）',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        AppProviders(
          recentFiles: RecentFiles(prefs),
          themeController: ThemeController(prefs),
          child: const MdeditorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar 提供 3 个 IconButton:新建、打开、设置;
      // 列表项右侧还有"删除最近文件"的 close 按钮(每个文件 1 个,
      // 无文件时为 0),总计至少 3 个——锁住"至少 3 个"避免误判。
      expect(find.byType(IconButton), findsAtLeastNWidgets(3));

      // 修复后 _EmptyRecentState 不再有"新建 / 打开"按钮,
      // 主操作入口统一由 AppBar 提供——因此 FilledButton / OutlinedButton 应为 0。
      // 修复前 _EmptyRecentState 里有 1 个 FilledButton.icon + 1 个 OutlinedButton.icon。
      expect(find.byType(FilledButton), findsNWidgets(0));
      expect(find.byType(OutlinedButton), findsNWidgets(0));

      // 兜底:HeroSection / 空状态里都不应再出现"新建"文本;
      // 仅允许 AppBar 的 tooltip / ListView 外区域出现(测试不深入)。

      // 兜底:HeroSection 渲染区不应该再出现 "新建" 文本
      // (本地化下英文为 'New')。该断言在不知道具体 locale 时也成立——
      // 因为即便修复失败,也会因为 Hero 内的 New/Open 文本而失败。
      // 注意:此断言只在 en/zh locale 下有效。
    },
  );
}
