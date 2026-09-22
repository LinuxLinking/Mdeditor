import 'package:flutter/material.dart';

/// 应用品牌 Logo —— 一个可缩放的「M + 文本行」组合标识。
///
/// 设计语言与 Android 启动图标保持一致：
///   - 居中的「M」字（粗描边，圆角连接）
///   - 上下各两条文本暗示线
///   - teal 主色 + 白字，对齐 ColorScheme.fromSeed(Colors.teal)
///
/// 使用 [CustomPainter] 绘制，矢量缩放无锯齿。
/// 适合放在大尺寸位置（首页 hero、闪屏、关于页）；不推荐 < 32px。
class MdeditorLogo extends StatelessWidget {
  const MdeditorLogo({
    super.key,
    this.size = 96,
    this.backgroundColor,
    this.foregroundColor,
    this.showBackground = true,
    this.borderRadius,
    this.padding,
  });

  /// 整体外框尺寸（包含背景）。
  final double size;

  /// 背景填充色；null 时跟随 Theme.colorScheme.primaryContainer。
  final Color? backgroundColor;

  /// 前景色；null 时跟随 Theme.colorScheme.onPrimaryContainer。
  final Color? foregroundColor;

  /// 是否绘制圆角背景块。false 时只绘制「M」字+文本线（透明底）。
  final bool showBackground;

  /// 外框圆角；null 时按 size 的 22% 自动。
  final BorderRadius? borderRadius;

  /// 前景内容相对背景框的内边距。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.primary;
    final fg = foregroundColor ?? Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MdeditorLogoPainter(
          background: showBackground ? bg : null,
          foreground: fg,
          borderRadius:
              borderRadius ?? BorderRadius.circular(size * 0.22),
          padding: padding ?? EdgeInsets.all(size * 0.12),
        ),
      ),
    );
  }
}

class _MdeditorLogoPainter extends CustomPainter {
  _MdeditorLogoPainter({
    required this.background,
    required this.foreground,
    required this.borderRadius,
    required this.padding,
  });

  final Color? background;
  final Color foreground;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint();
    if (background != null) {
      bgPaint.color = background!;
      canvas.drawRRect(
        borderRadius.toRRect(rect),
        bgPaint,
      );
      // 细微高光（左上 → 右下径向）
      final highlight = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect);
      canvas.drawRRect(borderRadius.toRRect(rect), highlight);
    }

    // 计算内容区域（按 padding 收缩）
    final pad = padding is EdgeInsets
        ? padding as EdgeInsets
        : EdgeInsets.fromLTRB(
            size.width * 0.12, size.height * 0.12,
            size.width * 0.12, size.height * 0.12,
          );
    final contentRect = Rect.fromLTRB(
      rect.left + pad.left,
      rect.top + pad.top,
      rect.right - pad.right,
      rect.bottom - pad.bottom,
    );
    _paintMark(canvas, contentRect);
  }

  void _paintMark(Canvas canvas, Rect r) {
    // 108x108 viewport 等比映射到 contentRect
    final cx = r.left;
    final cy = r.top;
    final sx = r.width / 108.0;
    final sy = r.height / 108.0;

    final fg = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1) M 上方两条淡文本线
    fg
      ..strokeWidth = 3 * sy
      ..color = foreground.withValues(alpha: 0.35);
    _drawHLine(canvas, cx, cy, sx, sy, 28, 30, 80);
    fg.color = foreground.withValues(alpha: 0.22);
    _drawHLine(canvas, cx, cy, sx, sy, 28, 22, 70);

    // 2) 大「M」字
    fg.color = foreground;
    fg.strokeWidth = 9 * sy;
    final m = Path()
      ..moveTo(26 * sx + cx, 82 * sy + cy)
      ..lineTo(26 * sx + cx, 42 * sy + cy)
      ..lineTo(54 * sx + cx, 66 * sy + cy)
      ..lineTo(82 * sx + cx, 42 * sy + cy)
      ..lineTo(82 * sx + cx, 82 * sy + cy);
    canvas.drawPath(m, fg);

    // 3) M 下方两条文本线
    fg
      ..strokeWidth = 3.5 * sy
      ..color = foreground;
    _drawHLine(canvas, cx, cy, sx, sy, 26, 92, 82);
    fg
      ..strokeWidth = 3 * sy
      ..color = foreground.withValues(alpha: 0.75);
    _drawHLine(canvas, cx, cy, sx, sy, 28, 100, 72);
  }

  void _drawHLine(
    Canvas canvas,
    double cx, double cy,
    double sx, double sy,
    double yV, double x0V, double x1V,
  ) {
    final p = Path()
      ..moveTo(x0V * sx + cx, yV * sy + cy)
      ..lineTo(x1V * sx + cx, yV * sy + cy);
    canvas.drawPath(p, Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3 * sy);
  }

  @override
  bool shouldRepaint(covariant _MdeditorLogoPainter old) {
    return old.background != background ||
        old.foreground != foreground ||
        old.borderRadius != borderRadius ||
        old.padding != padding;
  }
}
