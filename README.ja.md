# Mdeditor

[简体中文](README.md) | [English](README.en.md) | [Français](README.fr.md)

Mdeditor は Flutter で開発された Android 向け Markdown エディターです。編集画面には WebView 上で動作する Milkdown を使用し、Android Storage Access Framework（SAF）でファイルにアクセスします。

## 機能

- Android のドキュメント URI を保持した Markdown ファイルの閲覧・編集・保存
- 最近使ったファイル、アプリテーマ、エディター文字サイズ
- Android のファイル連携から Markdown ファイルを開く
- DOCX と HTML へのエクスポート、Android のシステム印刷による PDF 作成
- テーマ連動のコードハイライト、行番号、折りたたみ、コピー

ソース編集モードは未実装です。HTML、PDF、DOCX のエクスポートでは、完全な構文トークンのハイライトはまだありません。

## 必要環境

- `pubspec.yaml` の Dart SDK 制約を満たす Flutter SDK
- Android SDK（現在の設定は `minSdk` 28、`compileSdk` 36）
- Milkdown のフロントエンドを変更する場合のみ Node.js/npm

## 実行とビルド

```powershell
flutter pub get
flutter run
flutter build apk --release
flutter build appbundle --release
```

`milkdown_src/` 内のソースを変更した場合は、そのディレクトリで実行します。

```powershell
npm ci
npm run build
```

`assets/web/editor.js` が更新されます。

## ライセンス

[GNU General Public License v3.0](LICENSE)
