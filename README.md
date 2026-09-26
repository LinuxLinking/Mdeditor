# Mdeditor

[English](README.en.md) | [日本語](README.ja.md) | [Français](README.fr.md)

Mdeditor 是一款面向 Android 的 Markdown 编辑器，使用 Flutter 构建应用界面，以 WebView 中的 Milkdown 编辑 Markdown，并通过 Android SAF 访问文档。

## 功能

- 打开、编辑和保存 Markdown 文件，保留 Android 文档 URI
- 最近文件列表、主题设置和编辑器字号设置
- 通过 Android 文件关联接收外部 Markdown 文件
- 导出 DOCX、HTML，并通过 Android 系统打印生成 PDF
- 编辑器代码块主题化高亮、行号、折叠和复制

源码模式尚未实现。HTML、PDF 和 DOCX 导出目前没有完整的语法 token 高亮。

## 环境

- Flutter SDK，版本需满足 `pubspec.yaml` 中的 Dart SDK 约束
- Android SDK；当前项目 `minSdk` 为 28、`compileSdk` 为 36
- Node.js/npm 仅在修改 Milkdown 前端源码时需要

## 运行与构建

```powershell
flutter pub get
flutter run
flutter build apk --release
flutter build appbundle --release
```

修改 `milkdown_src/` 后，在该目录执行：

```powershell
npm ci
npm run build
```

该构建会更新 `assets/web/editor.js`。

## License

[GNU General Public License v3.0](LICENSE)
