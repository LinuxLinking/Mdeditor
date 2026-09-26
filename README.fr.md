# Mdeditor

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

Mdeditor est un éditeur Markdown destiné principalement à Android et construit avec Flutter. Milkdown s’exécute dans une WebView pour l’édition, et le Storage Access Framework (SAF) d’Android gère l’accès aux documents.

## Fonctionnalités

- Ouvrir, modifier et enregistrer des fichiers Markdown en conservant leurs URI Android
- Fichiers récents, thèmes de l’application et taille du texte de l’éditeur
- Ouvrir des fichiers Markdown depuis les applications Android
- Export DOCX et HTML, et création de PDF via l’impression système Android
- Blocs de code avec coloration par thème, numéros de ligne, repli et copie

Le mode source n’est pas implémenté. Les exports HTML, PDF et DOCX ne proposent pas encore une coloration complète des tokens syntaxiques.

## Prérequis

- SDK Flutter respectant la contrainte Dart indiquée dans `pubspec.yaml`
- SDK Android ; le projet définit actuellement `minSdk` 28 et `compileSdk` 36
- Node.js/npm uniquement pour modifier le code source frontend de Milkdown

## Exécution et compilation

```powershell
flutter pub get
flutter run
flutter build apk --release
flutter build appbundle --release
```

Après une modification dans `milkdown_src/`, exécutez dans ce répertoire :

```powershell
npm ci
npm run build
```

Cette commande met à jour `assets/web/editor.js`.

## Licence

[GNU General Public License v3.0](LICENSE)
