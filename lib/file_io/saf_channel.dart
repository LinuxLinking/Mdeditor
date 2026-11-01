import 'package:flutter/services.dart';

/// SAF (Storage Access Framework) Platform Channel 的 Dart 侧封装。
///
/// 对应原生 [android/app/src/main/kotlin/com/mdeditor/app/SafChannel.kt],
/// channel name = `mdeditor/saf`,提供:
///   - `openDocument(mime)`:发起 `ACTION_OPEN_DOCUMENT`,返回 `content://` URI
///     (Kotlin 侧已 `takePersistableUriPermission`,应用重启后仍可访问)
///   - `createDocument(suggestedName, mime)`:发起 `ACTION_CREATE_DOCUMENT`(另存为)
///   - `readUri(uri)`:经 `ContentResolver` 读取文本
///   - `writeUri(uri, bytes)`:以 `"wt"` 截断模式写入字节
///   - `queryName(uri)`:查 `OpenableColumns.DISPLAY_NAME`
///
/// 历史教训:file_picker 在 Android 上会把文件复制到 app cache 后返回缓存路径,
/// 不保留原始 content:// URI,导致"保存回原位置"会写到缓存副本而非用户原始选择的位置。
/// 因此本项目**不使用 file_picker**,改用本 channel。
class SafChannel {
  static const MethodChannel _ch = MethodChannel('mdeditor/saf');

  /// 通过 SAF 打开文件。返回选中的 `content://` URI;用户取消返回 null。
  static Future<Uri?> openDocument({required String mime}) async {
    final s = await _ch.invokeMethod<String>('openDocument', {'mime': mime});
    return s == null ? null : Uri.parse(s);
  }

  /// 通过 SAF 让用户选择另存为的目标位置。返回选中的 URI;用户取消返回 null。
  static Future<Uri?> createDocument({
    required String suggestedName,
    required String mime,
  }) async {
    final s = await _ch.invokeMethod<String>('createDocument', {
      'suggestedName': suggestedName,
      'mime': mime,
    });
    return s == null ? null : Uri.parse(s);
  }

  /// 读取 `content://` URI 文本。失败抛 [PlatformException]。
  static Future<String?> readUri(Uri uri) =>
      _ch.invokeMethod<String>('readUri', {'uri': uri.toString()});

  /// 以 `"wt"`(截断)模式写入字节到 `content://` URI。
  static Future<void> writeUri(Uri uri, Uint8List bytes) =>
      _ch.invokeMethod<void>('writeUri', {
        'uri': uri.toString(),
        'bytes': bytes,
      });

  /// 查询 URI 对应文件的显示名(`OpenableColumns.DISPLAY_NAME`)。
  static Future<String?> queryName(Uri uri) =>
      _ch.invokeMethod<String>('queryName', {'uri': uri.toString()});

  /// 删除 `content://` document URI。
  /// 修导出:用于导出写入失败时清理已 pick 的 0B 残留文件。
  static Future<bool> deleteDocument(Uri uri) async {
    final r = await _ch.invokeMethod<bool>('deleteDocument', {
      'uri': uri.toString(),
    });
    return r ?? false;
  }

  /// 兜底清理:删除 Download 里同 basename 前缀的 0B 空壳文件。
  /// 修连点保存:连点保存按钮会在 Download 留下 `xxx (1).md`、`xxx (2).md` 等 0B
  /// 空壳(Download provider 对同名加后缀)。Kotlin 侧扫描 MediaStore downloads,
  /// 删除 displayName 以 basename 主名开头、size=0、且非 basename 本身的文件。
  /// 返回删除的文件数。
  static Future<int> deleteZeroSiblings(String basename) async {
    final r = await _ch.invokeMethod<int>('deleteZeroSiblings', {
      'basename': basename,
    });
    return r ?? 0;
  }

  /// 检查 app 是否已获"所有文件访问权限"(MANAGE_EXTERNAL_STORAGE)。
  /// 授权后 [deleteZeroSiblings] 才能用 File 清理 Download 里的 0B 空壳。
  static Future<bool> hasAllFilesAccess() async {
    final r = await _ch.invokeMethod<bool>('hasAllFilesAccess');
    return r ?? false;
  }

  /// 跳转系统设置页引导用户授权"所有文件访问权限"。返回当前授权状态
  /// (true=已授权,false=已跳转设置页待用户操作)。
  static Future<bool> requestAllFilesAccess() async {
    final r = await _ch.invokeMethod<bool>('requestAllFilesAccess');
    return r ?? false;
  }
}

/// 便捷别名:封装 [SafChannel.queryName] 的常见用法。
class SafColumn {
  /// 返回 URI 的显示名;查询失败回退到 'unknown.md'。
  static Future<String> name(Uri uri) async =>
      (await SafChannel.queryName(uri)) ?? 'unknown.md';
}
