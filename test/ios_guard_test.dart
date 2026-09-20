import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:mdeditor/file_io/intent_channel.dart';
import 'package:mdeditor/file_io/saf_channel.dart';
import 'package:mdeditor/native/platform_support.dart';
import 'package:mdeditor/utils/error_handler.dart';

/// iOS 降级守卫测试。
///
/// flutter test 宿主（macOS/linux VM）不是 Android，因此
/// [requireAndroid] 会走 guard 分支——这些测试正是依赖该行为，
/// 验证非 Android 平台上通道调用被替换为可读的降级信号，
/// 而不是抛出框架层 MissingPluginException。
void main() {
  group('requireAndroid', () {
    test('非 Android 平台抛 PlatformUnsupportedError', () {
      expect(
        () => requireAndroid('openDocument'),
        throwsA(isA<PlatformUnsupportedError>()),
      );
    });

    test('异常 toString 包含功能名,便于日志定位', () {
      const err = PlatformUnsupportedError('writeUri');
      expect(err.toString(), contains('writeUri'));
    });
  });

  group('SafChannel 降级', () {
    test('openDocument / createDocument 抛 PlatformUnsupportedError', () {
      expect(
        SafChannel.openDocument(mime: 'text/markdown'),
        throwsA(isA<PlatformUnsupportedError>()),
      );
      expect(
        SafChannel.createDocument(
          suggestedName: 'a.md',
          mime: 'text/markdown',
        ),
        throwsA(isA<PlatformUnsupportedError>()),
      );
    });

    test('readUri / writeUri / queryName 抛 PlatformUnsupportedError', () {
      final uri = Uri.parse('content://test/a.md');
      // 这三个方法是非 async 的同步函数,guard 异常同步抛出(而非 failed
      // Future),因此断言用闭包形式。
      expect(
        () => SafChannel.readUri(uri),
        throwsA(isA<PlatformUnsupportedError>()),
      );
      expect(
        () => SafChannel.writeUri(uri, Uint8List(0)),
        throwsA(isA<PlatformUnsupportedError>()),
      );
      expect(
        () => SafChannel.queryName(uri),
        throwsA(isA<PlatformUnsupportedError>()),
      );
    });
  });

  group('IntentChannel 降级', () {
    test('getInitialUri 返回 null(等价于无外部唤起)', () async {
      expect(await IntentChannel.getInitialUri(), isNull);
    });

    test('openedUris 是空流且不发错误事件', () async {
      final events = <Uri>[];
      final errors = <Object>[];
      final sub = IntentChannel.openedUris.listen(
        events.add,
        onError: (Object e) => errors.add(e),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('ErrorHandler 平台不支持归类', () {
    test('classify 识别 PlatformUnsupportedError', () {
      expect(
        ErrorHandler.classify(const PlatformUnsupportedError('exportPdf')),
        ErrorKind.platformUnsupported,
      );
    });

    test('messageFor 给出非空可读文案', () {
      final msg = ErrorHandler.messageFor(ErrorKind.platformUnsupported);
      expect(msg, isNotEmpty);
      expect(msg, contains('iOS'));
    });

    test('display: 平台不支持 → 降级文案;其他错误 → 前缀拼接', () {
      expect(
        ErrorHandler.display('保存失败', const PlatformUnsupportedError('save')),
        isNot(contains('保存失败')),
      );
      expect(
        ErrorHandler.display('保存失败', StateError('boom')),
        allOf(contains('保存失败'), contains('boom')),
      );
    });
  });
}
