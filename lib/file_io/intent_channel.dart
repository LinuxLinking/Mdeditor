import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 接收外部 intent (Android `ACTION_VIEW`) 传入的 `.md` 文件 URI。
///
/// 对应原生 [android/app/src/main/kotlin/com/mdeditor/app/IntentChannel.kt],
/// channel name = `mdeditor/intent`。
///
/// 一次性取走(原生侧在 `getInitialUri` 返回后清空缓存,
/// 避免 app 重启后仍路由到旧 URI)。
///
/// 非 Android 平台(iOS 适配开发中)没有 intent 唤起机制:
/// [getInitialUri] 返回 null(等价于"无外部文档",app 正常进首页),
/// [openedUris] 返回空流。iOS 侧真正的入口(onOpenURL / UTI 文件关联)
/// 见 AGENTS.md 施工单B。
class IntentChannel {
  static const MethodChannel _ch = MethodChannel('mdeditor/intent');
  static const EventChannel _events = EventChannel('mdeditor/intent/events');

  /// 取走启动 intent 里的 URI;无 intent 或已取走返回 null。
  static Future<Uri?> getInitialUri() async {
    if (!Platform.isAndroid) return null;
    final s = await _ch.invokeMethod<String>('getInitialUri');
    return s == null ? null : Uri.parse(s);
  }

  /// App 已运行时收到新的 `ACTION_VIEW` intent 的事件流。
  ///
  /// 冷启动仍使用 [getInitialUri]；热启动时由 Android 在 `onNewIntent` 中
  /// 推送 URI，避免用户从文件管理器再次选择“用 Mdeditor 打开”却没有反应。
  static Stream<Uri> get openedUris {
    if (!Platform.isAndroid) return const Stream<Uri>.empty();
    return _events
        .receiveBroadcastStream()
        // dart:async 的 Stream 没有 whereType（那是 Iterable 的方法），
        // 用 where + cast 过滤出 String 事件再解析。
        .where((e) => e is String)
        .cast<String>()
        .map(Uri.parse);
  }
}
