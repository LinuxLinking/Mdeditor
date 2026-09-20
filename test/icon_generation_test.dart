// Mdeditor 应用图标生成脚本（手动运行）。
//
// 运行方式（在项目根目录）：
//   GEN_ICONS=1 flutter test test/icon_generation_test.dart
//
// 输出：
//   - android/app/src/main/res/mipmap-*/ic_launcher.png           （legacy 全出血）
//   - android/app/src/main/res/mipmap-*/ic_launcher_foreground.png（adaptive 前景，透明底）
//   - android/app/src/main/res/mipmap-*/ic_launcher_background.png（adaptive 背景，渐变）
//   - android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml  （adaptive 描述）
//   - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-*.png     （Contents.json 全部槽位）
//
// 设计（2026-09-21）：
//   teal 对角渐变 #26A69A → #00695C（前端 --editor-accent #00897B 恰为中间值，
//   与 Flutter 壳 ColorScheme.fromSeed(Colors.teal) 同源）
//   + 白色几何粗笔画 "M" + 白色圆角光标条 = 「正在编辑的 Markdown」。
//   M 为手工矢量路径（不依赖字体度量，任意尺寸渲染一致）。
//
// 修改设计后重跑本脚本并提交全部产物，不要手改 PNG。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

const _tealLight = Color(0xFF26A69A); // Material teal 300
const _tealDark = Color(0xFF00695C); // Material teal 800
const _white = Color(0xFFFFFFFF);

/// 在 512×512 逻辑画布上绘制 M + 光标条组合（白色），整体居中。
///
/// 基准几何（未缩放，单位=逻辑像素）：总宽 378、总高 232。
/// 光标条刻意做得比 M 笔画细一半、矮一头、底部立于 M 的基线——
/// 等宽齐高的竖条会被读成字母 I，细而矮的基线竖条才是输入光标。
/// [contentWidth] 为组合的期望总宽（会等比缩放几何）。
void _drawMark(ui.Canvas canvas, double contentWidth) {
  const logical = 512.0;
  final s = contentWidth / 378;

  canvas.translate((logical - 378 * s) / 2, (logical - 232 * s) / 2 - 4 * s);
  canvas.scale(s);

  final paint = ui.Paint()..color = _white;

  // 左竖 / 右竖
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 58, 232), paint);
  canvas.drawRect(const ui.Rect.fromLTWH(266, 0, 58, 232), paint);

  // 中间 V：两条平行四边形斜笔（底部略高于左右竖，经典无衬线 M 比例）
  final leftDiag = ui.Path()
    ..moveTo(58, 0)
    ..lineTo(164, 132)
    ..lineTo(164, 196)
    ..lineTo(58, 64)
    ..close();
  canvas.drawPath(leftDiag, paint);
  final rightDiag = ui.Path()
    ..moveTo(266, 0)
    ..lineTo(164, 132)
    ..lineTo(164, 196)
    ..lineTo(266, 64)
    ..close();
  canvas.drawPath(rightDiag, paint);

  // 光标条：细胶囊（宽 26 ≈ M 笔画一半），高 196 顶部矮一头、
  // 底部与 M 基线齐平，模拟文本输入光标立于 M 右侧。
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(352, 36, 26, 196),
      const ui.Radius.circular(13),
    ),
    paint,
  );
}

Future<void> _renderPng(
  File target,
  int px, {
  required bool transparentBackground,
  required double contentWidth,
  bool roundedCorners = false,
}) async {
  const logical = 512.0;
  final recorder = ui.PictureRecorder();
  // toImage(px, px) 光栅化的是逻辑坐标 [0, px] 区间，因此先整体缩放，
  // 让 512 逻辑画布的内容精确铺满 px 物理像素。
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
  )..scale(px / logical);

  if (roundedCorners) {
    // 圆角图标（Android legacy png 自带圆角，四角透明）。
    // 半径取画布的 22.5%，接近 Material squircle 观感。
    canvas.clipRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, logical, logical),
        const ui.Radius.circular(115),
      ),
    );
  }

  if (!transparentBackground) {
    final rect = ui.Rect.fromLTWH(0, 0, logical, logical);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [_tealLight, _tealDark],
        ),
    );
  }
  _drawMark(canvas, contentWidth);

  final picture = recorder.endRecording();
  final image = await picture.toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  target.parent.createSync(recursive: true);
  await target.writeAsBytes(data!.buffer.asUint8List());
  debugPrint('written ${target.path} (${px}x$px)');
}

/// 从 iOS 图标文件名解析实际像素，如 Icon-App-83.5x83.5@2x.png → 167。
int _iosPixels(String name) {
  final m = RegExp(r'-(\d+(?:\.\d+)?)x\d+(?:\.\d+)?@(\d)x\.png$').firstMatch(name);
  if (m == null) {
    throw FormatException('无法解析 iOS 图标文件名: $name');
  }
  return (double.parse(m.group(1)!) * int.parse(m.group(2)!)).round();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate app icons', () async {
    if (Platform.environment['GEN_ICONS'] != '1') {
      markTestSkipped('手动脚本：GEN_ICONS=1 flutter test test/icon_generation_test.dart');
      return;
    }
    final root = Directory.current.path;
    const res = 'android/app/src/main/res';

    // Android legacy：自带圆角（透明四角）+ 内容约 60% 宽
    const legacySizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in legacySizes.entries) {
      await _renderPng(
        File('$root/$res/mipmap-${e.key}/ic_launcher.png'),
        e.value,
        transparentBackground: false,
        contentWidth: 310,
        roundedCorners: true,
      );
    }

    // Android adaptive：前景透明底、内容收进安全区；背景为同款渐变
    const adaptiveSizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    for (final e in adaptiveSizes.entries) {
      await _renderPng(
        File('$root/$res/mipmap-${e.key}/ic_launcher_foreground.png'),
        e.value,
        transparentBackground: true,
        contentWidth: 300,
      );
      await _renderPng(
        File('$root/$res/mipmap-${e.key}/ic_launcher_background.png'),
        e.value,
        transparentBackground: false,
        contentWidth: 310,
      );
    }

    // adaptive icon 描述文件（API 26+ 上优先于密度 png）
    final xml = File('$root/$res/mipmap-anydpi-v26/ic_launcher.xml');
    xml.parent.createSync(recursive: true);
    await xml.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''');
    debugPrint('written ${xml.path}');

    // iOS：覆盖 AppIcon.appiconset/Contents.json 列出的全部槽位
    final iosDir = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = await File('$iosDir/Contents.json').readAsString();
    final names = RegExp('Icon-[^"]+\\.png')
        .allMatches(contents)
        .map((m) => m.group(0)!)
        .toSet();
    for (final name in names) {
      await _renderPng(
        File('$iosDir/$name'),
        _iosPixels(name),
        transparentBackground: false,
        contentWidth: 310,
      );
    }
    debugPrint('iOS slots: ${names.length}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
