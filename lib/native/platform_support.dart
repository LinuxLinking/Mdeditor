import 'dart:io';

/// iOS 等尚未实现原生通道的平台上的功能降级标记。
///
/// 本项目的四条 Android 原生通道（`mdeditor/saf`、`mdeditor/intent`、
/// `mdeditor/render`、`mdeditor/print`）目前只有 Kotlin 实现；在 iOS 上
/// 调用会抛出框架层的 [MissingPluginException]，且提示对用户不可读。
///
/// 因此各通道的 Dart 封装入口统一改为：非 Android 平台抛出本异常
/// （或按语义返回空值），由 ErrorHandler 归类为
/// `ErrorKind.platformUnsupported` 并转为用户可读的 SnackBar 提示。
///
/// iOS 功能适配的完整待办见仓库根目录 AGENTS.md 施工单B。
class PlatformUnsupportedError implements Exception {
  const PlatformUnsupportedError(this.feature);

  /// 不可用功能的简短标识（如 `'openDocument'`），仅用于日志。
  final String feature;

  @override
  String toString() => 'PlatformUnsupportedError: $feature is not available '
      'on ${Platform.operatingSystem} (iOS adaptation pending)';
}

/// 通道入口守卫：当前平台没有对应原生实现时抛 [PlatformUnsupportedError]。
///
/// 用法（在 MethodChannel 封装方法的开头）：
/// ```dart
/// requireAndroid('openDocument');
/// return _ch.invokeMethod(...);
/// ```
///
/// dart:io 的 Platform 在 flutter test 宿主上也不是 Android，
/// 因此单元测试同样走 guard 分支（ios_guard_test.dart 依赖此行为）。
void requireAndroid(String feature) {
  if (!Platform.isAndroid) {
    throw PlatformUnsupportedError(feature);
  }
}
