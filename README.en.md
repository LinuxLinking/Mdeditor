# Mdeditor

[简体中文](README.md) | [日本語](README.ja.md) | [Français](README.fr.md)

Mdeditor is an Android-focused Markdown editor built with Flutter. Milkdown runs in a WebView for editing, while Android Storage Access Framework (SAF) provides document access.

## Features

- Open, edit, and save Markdown documents while retaining Android document URIs
- Recent files, app themes, and editor text sizing
- Open Markdown documents through Android file intents
- Export DOCX and HTML, and create PDF through Android system printing
- Theme-aware code block highlighting, line numbers, folding, and copy controls

Source mode is not implemented. HTML, PDF, and DOCX exports do not yet provide full syntax token highlighting.

## Requirements

- Flutter SDK meeting the Dart SDK constraint in `pubspec.yaml`
- Android SDK; the project currently sets `minSdk` 28 and `compileSdk` 36
- Node.js/npm only when changing the Milkdown frontend source

## Run and build

```powershell
flutter pub get
flutter run
flutter build apk --release
flutter build appbundle --release
```

After editing files under `milkdown_src/`, run from that directory:

```powershell
npm ci
npm run build
```

This updates `assets/web/editor.js`.

## License

[GNU General Public License v3.0](LICENSE)
