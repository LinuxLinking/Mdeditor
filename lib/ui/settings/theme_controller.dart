import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../native/native_render_channel.dart';

/// 主题模式:跟随系统 / 浅色 / 深色。
///
/// 设计对齐 dev-doc.md Phase 6 第 1722 行"主题切换(跟随系统 / 浅 / 深)"。
enum ThemeModePreference {
  /// 跟随系统(platformBrightness)
  system,

  /// 强制浅色
  light,

  /// 强制深色
  dark,
}

/// 字体缩放档位。
///
/// 设计对齐 dev-doc.md Phase 6 第 1723 行"字体缩放"。
/// 三档:小(0.85) / 标准(1.0) / 大(1.3),覆盖大多数用户需求,
/// 后续可改为滑条 (0.7~1.5) 步进 0.05。
enum TextScalePreference {
  small(0.85),
  standard(1.0),
  large(1.3);

  final double value;
  const TextScalePreference(this.value);
}

enum EditorThemePreference { githubLight, githubDark, vue }

/// 主题控制器:基于 [SharedPreferences] 持久化用户主题偏好 +
/// 字体缩放偏好,用 [ChangeNotifier] 让 MaterialApp 监听变化。
///
/// 设计参见 dev-doc.md 第 319 行 `settings/` 模块分工。
///
/// 用法:
/// ```dart
/// final tc = ThemeController(prefs);
/// // 读
/// final mode = tc.mode;
/// // 写
/// tc.setMode(ThemeModePreference.dark);
/// ```
class ThemeController extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keyScale = 'text_scale';
  static const _keyEditorTheme = 'editor_theme';

  final SharedPreferences _prefs;
  ThemeModePreference _mode;
  TextScalePreference _scale;
  EditorThemePreference _editorTheme;

  ThemeController(this._prefs)
      : _mode = _readMode(_prefs.getInt(_keyMode)),
        _scale = _readScale(_prefs.getInt(_keyScale)),
        _editorTheme = _readEditorTheme(_prefs.getInt(_keyEditorTheme));

  /// 当前主题模式(默认跟随系统)。
  ThemeModePreference get mode => _mode;

  /// 当前字体缩放档位(默认标准)。
  TextScalePreference get scale => _scale;

  EditorThemePreference get editorTheme => _editorTheme;

  /// 等宽字体栈，三个主题共用。Android 上多半没装 JetBrains Mono / Fira Code，
  /// 会自动回退到 Consolas / monospace；有装的设备能拿到更好看的字形。
  static const _codeFonts = <String>[
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Cascadia Code',
    'Consolas',
    'monospace',
  ];

  /// 语言徽章颜色（GitHub 语言色板）。当前 editor.css 只用 --code-badge-default，
  /// 按语言的变量是前向预留，先填上以备后续工具栏着色。
  static const _codeBadgeMap = <String, String>{
    'javascript': '#f1e05a',
    'typescript': '#3178c6',
    'python': '#3572a5',
    'bash': '#89e051',
    'html': '#e34c26',
    'css': '#563d7c',
    'json': '#292929',
    'sql': '#e38c00',
    'markdown': '#083fa1',
  };

  /// GitHub Light 代码 token 调色板（对齐 GitHub Primer 浅色）。
  static const _githubLightHighlight = <NativeCodeHighlight>[
    NativeCodeHighlight(tag: 'comment', color: '#6e7781'),
    NativeCodeHighlight(tag: 'string', color: '#0a3069'),
    NativeCodeHighlight(tag: 'number', color: '#0550ae'),
    NativeCodeHighlight(tag: 'keyword', color: '#cf222e'),
    NativeCodeHighlight(tag: 'controlKeyword', color: '#cf222e'),
    NativeCodeHighlight(tag: 'functionName', color: '#8250df'),
    NativeCodeHighlight(tag: 'typeName', color: '#953800'),
    NativeCodeHighlight(tag: 'operator', color: '#0550ae'),
    NativeCodeHighlight(tag: 'variableName', color: '#24292f'),
    NativeCodeHighlight(tag: 'regexp', color: '#116329'),
    NativeCodeHighlight(tag: 'escape', color: '#1a7f37'),
    NativeCodeHighlight(tag: 'punctuation', color: '#24292f'),
    NativeCodeHighlight(tag: 'meta', color: '#6e7781'),
  ];

  /// GitHub Dark 代码 token 调色板（对齐 GitHub Primer 深色）。
  static const _githubDarkHighlight = <NativeCodeHighlight>[
    NativeCodeHighlight(tag: 'comment', color: '#8b949e'),
    NativeCodeHighlight(tag: 'string', color: '#a5d6ff'),
    NativeCodeHighlight(tag: 'number', color: '#79c0ff'),
    NativeCodeHighlight(tag: 'keyword', color: '#ff7b72'),
    NativeCodeHighlight(tag: 'controlKeyword', color: '#ff7b72'),
    NativeCodeHighlight(tag: 'functionName', color: '#d2a8ff'),
    NativeCodeHighlight(tag: 'typeName', color: '#ffa657'),
    NativeCodeHighlight(tag: 'operator', color: '#79c0ff'),
    NativeCodeHighlight(tag: 'variableName', color: '#e6edf3'),
    NativeCodeHighlight(tag: 'regexp', color: '#a5d6ff'),
    NativeCodeHighlight(tag: 'escape', color: '#bb8009'),
    NativeCodeHighlight(tag: 'punctuation', color: '#e6edf3'),
    NativeCodeHighlight(tag: 'meta', color: '#8b949e'),
  ];

  /// Vue 主题代码 token 调色板（浅色底，绿系强调）。
  static const _vueHighlight = <NativeCodeHighlight>[
    NativeCodeHighlight(tag: 'comment', color: '#6a737d'),
    NativeCodeHighlight(tag: 'string', color: '#0b7a57'),
    NativeCodeHighlight(tag: 'number', color: '#005cc5'),
    NativeCodeHighlight(tag: 'keyword', color: '#b043c9'),
    NativeCodeHighlight(tag: 'controlKeyword', color: '#b043c9'),
    NativeCodeHighlight(tag: 'functionName', color: '#1f6feb'),
    NativeCodeHighlight(tag: 'typeName', color: '#953800'),
    NativeCodeHighlight(tag: 'operator', color: '#005cc5'),
    NativeCodeHighlight(tag: 'variableName', color: '#2c3e50'),
    NativeCodeHighlight(tag: 'regexp', color: '#0b7a57'),
    NativeCodeHighlight(tag: 'escape', color: '#1a7f37'),
    NativeCodeHighlight(tag: 'punctuation', color: '#2c3e50'),
    NativeCodeHighlight(tag: 'meta', color: '#6a737d'),
  ];

  NativeEditorTheme get nativeTheme {
    switch (_editorTheme) {
      case EditorThemePreference.githubLight:
        return const NativeEditorTheme(
          name: 'github-light',
          codeFonts: _codeFonts,
          codeBadgeMap: _codeBadgeMap,
          codeHighlight: _githubLightHighlight,
          variables: {
          '--editor-bg': '#ffffff',
          '--editor-fg': '#24292f',
          '--editor-muted': '#57606a',
          '--editor-code-bg': '#f6f8fa',
          '--editor-accent': '#0969da',
          '--h1-size': '2em', '--h1-color': '#1f2328', '--h1-space': '24px',
          '--h2-size': '1.5em', '--h2-color': '#1f2328', '--h2-space': '20px',
          '--h3-size': '1.25em', '--h3-color': '#24292f', '--h3-space': '18px',
          '--h4-size': '1em', '--h4-color': '#24292f', '--h4-space': '16px',
          '--h5-size': '0.875em', '--h5-color': '#57606a', '--h5-space': '14px',
          '--h6-size': '0.85em', '--h6-color': '#6e7781', '--h6-space': '12px',
        });
      case EditorThemePreference.githubDark:
        return const NativeEditorTheme(
          name: 'github-dark',
          codeFonts: _codeFonts,
          codeBadgeMap: _codeBadgeMap,
          codeHighlight: _githubDarkHighlight,
          variables: {
          '--editor-bg': '#0d1117',
          '--editor-fg': '#e6edf3',
          '--editor-muted': '#8b949e',
          '--editor-code-bg': '#161b22',
          '--editor-accent': '#58a6ff',
          '--h1-size': '2em', '--h1-color': '#f0f6fc', '--h1-space': '24px',
          '--h2-size': '1.5em', '--h2-color': '#e6edf3', '--h2-space': '20px',
          '--h3-size': '1.25em', '--h3-color': '#e6edf3', '--h3-space': '18px',
          '--h4-size': '1em', '--h4-color': '#c9d1d9', '--h4-space': '16px',
          '--h5-size': '0.875em', '--h5-color': '#b1bac4', '--h5-space': '14px',
          '--h6-size': '0.85em', '--h6-color': '#8b949e', '--h6-space': '12px',
        });
      case EditorThemePreference.vue:
        return const NativeEditorTheme(
          name: 'vue',
          codeFonts: _codeFonts,
          codeBadgeMap: _codeBadgeMap,
          codeHighlight: _vueHighlight,
          variables: {
          '--editor-bg': '#f8faf9',
          '--editor-fg': '#2c3e50',
          '--editor-muted': '#6b7280',
          '--editor-code-bg': '#eef5f2',
          '--editor-accent': '#42b883',
          '--h1-size': '2.1em', '--h1-color': '#2c3e50', '--h1-space': '26px',
          '--h2-size': '1.55em', '--h2-color': '#345b4d', '--h2-space': '22px',
          '--h3-size': '1.3em', '--h3-color': '#3b6555', '--h3-space': '18px',
          '--h4-size': '1.05em', '--h4-color': '#2c3e50', '--h4-space': '16px',
          '--h5-size': '0.9em', '--h5-color': '#47675c', '--h5-space': '14px',
          '--h6-size': '0.85em', '--h6-color': '#6b7280', '--h6-space': '12px',
        });
    }
  }

  /// Flutter [ThemeMode] 映射(供 MaterialApp.themeMode 用)。
  ThemeMode get flutterMode {
    switch (_mode) {
      case ThemeModePreference.system:
        return ThemeMode.system;
      case ThemeModePreference.light:
        return ThemeMode.light;
      case ThemeModePreference.dark:
        return ThemeMode.dark;
    }
  }

  /// 切换模式,写入 prefs + notify。
  Future<void> setMode(ThemeModePreference m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    await _prefs.setInt(_keyMode, m.index);
  }

  /// 切换字体缩放,写入 prefs + notify。
  Future<void> setScale(TextScalePreference s) async {
    if (s == _scale) return;
    _scale = s;
    notifyListeners();
    await _prefs.setInt(_keyScale, s.index);
  }

  Future<void> setEditorTheme(EditorThemePreference theme) async {
    if (theme == _editorTheme) return;
    _editorTheme = theme;
    notifyListeners();
    await _prefs.setInt(_keyEditorTheme, theme.index);
  }

  static ThemeModePreference _readMode(int? v) {
    switch (v) {
      case 1:
        return ThemeModePreference.light;
      case 2:
        return ThemeModePreference.dark;
      default:
        return ThemeModePreference.system;
    }
  }

  static TextScalePreference _readScale(int? v) {
    switch (v) {
      case 0:
        return TextScalePreference.small;
      case 2:
        return TextScalePreference.large;
      default:
        return TextScalePreference.standard;
    }
  }

  static EditorThemePreference _readEditorTheme(int? v) {
    switch (v) {
      case 1:
        return EditorThemePreference.githubDark;
      case 2:
        return EditorThemePreference.vue;
      default:
        return EditorThemePreference.githubLight;
    }
  }
}
