// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';

import '../lib/editor/editor_controller.dart';

/// Bug fix: 进入编辑器时键盘弹不出。
///
/// Android WebView 在某些 OEM ROM 上点击 contenteditable 元素不会自动弹
/// 出原生软键盘。Milkdown 编辑器创建后光标也不会自动落在 DOM 上。
/// 修复方案:在 Milkdown 通过 `MdBridge.postMessage({type:'ready'})`
/// 报告初始化完成时,从 Dart 端注入 JS 主动 focus 编辑器 DOM 节点。
///
/// 本测试以静态字符串断言验证注入的 JS 逻辑正确——避免启动完整 WebView。
void main() {
  test('EditorController.kFocusEditorScript: 命中 contenteditable / textarea', () {
    final js = EditorController.kFocusEditorScript;
    expect(js, contains('.ProseMirror'),
        reason: '应优先命中 Milkdown 的 contenteditable 容器');
    expect(js, contains('contenteditable'),
        reason: '退化场景:任意 contenteditable 元素');
    expect(js, contains('textarea'),
        reason: '退化场景:fallback textarea');
    expect(js, contains('.focus('),
        reason: '必须调用 DOM focus() 形式 1');
    expect(js, contains('focus()'),
        reason: '必须调用 DOM focus() 形式 2');
  });

  test('EditorController.kFocusEditorScript: ASCII-only 字面量', () {
    // _jsStringLiteral 把所有非 ASCII 转 \uXXXX,确保整段是 ASCII。
    // Android WebView 在 MethodChannel 链路里 UTF-8 处理曾踩过编码坑,
    // 这里锁住"全 ASCII"避免回归。
    final js = EditorController.kFocusEditorScript;
    for (final c in js.codeUnits) {
      expect(c < 0x80, isTrue,
          reason: '存在非 ASCII 码点 0x${c.toRadixString(16)} — '
              '应通过 _jsStringLiteral 转义为 \\uXXXX');
    }
  });
}