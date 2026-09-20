# Mdeditor

[![Build APK](https://github.com/LinuxLinking/Mdeidetor/actions/workflows/build.yml/badge.svg)](https://github.com/LinuxLinking/Mdeidetor/actions/workflows/build.yml)
[![Build IPA](https://github.com/LinuxLinking/Mdeidetor/actions/workflows/build-ios.yml/badge.svg)](https://github.com/LinuxLinking/Mdeidetor/actions/workflows/build-ios.yml)

[English](README.en.md) | [日本語](README.ja.md) | [Francais](README.fr.md)

Mdeditor 是一个面向 Android 的 Markdown 编辑器，基于 Flutter + WebView + Milkdown 构建。它支持直接编辑 `.md` 文件、最近文件管理、主题切换，以及导出 PDF / DOCX / HTML。

## 主要功能

- 打开、编辑、保存 Markdown 文件
- 通过 Android SAF 访问文件，保留原始 `content://` URI
- 最近文件列表与快速打开
- 主题切换、编辑器主题切换、字体缩放
- 导出为 PDF、DOCX、HTML
- 支持外部 intent 打开 `.md` 文件
- 代码块语法高亮（JS/TS、Python、Bash、HTML、CSS、JSON、SQL、Markdown）
- 编辑器括号自动补全（`[` → `[]`、`(` → `()`，光标定位到中间）
- 智能闭合符号跳过（输入 `]` 时光标后已有 `]` 则跳过而非重复输入）

## 下载

在 [GitHub Releases](https://github.com/LinuxLinking/Mdeidetor/releases) 下载最新 APK。每个正式版（`v*` tag）都会自动附上 `Mdeditor-<版本>.apk` 与 `Mdeditor-latest.apk` 两个资产，`latest` 始终指向最新正式版。

> 注意：当前 release 构建暂使用 debug 签名（无法稳定覆盖安装），切换正式签名密钥的步骤见 [AGENTS.md 施工单A](AGENTS.md)。

## iOS（侧载版）

iOS 版不走 App Store，面向侧载场景：从 Releases 的 `ios-v*` 预发布版下载
`Mdeditor-ios-<版本>.ipa`（无签名），用 AltStore / Sideloadly / TrollStore 等工具
以自己的 Apple ID 重签安装。当前 iOS 功能状态：界面与编辑器可运行，文件打开/保存、
导出等依赖原生通道的功能暂显示「iOS 适配开发中」提示，适配待办见
[AGENTS.md 施工单B](AGENTS.md)。

## 环境要求

- Flutter 3.47+
- Android 9+（当前项目主要面向 Android）

* Node.js（仅在更新 `milkdown_src` 前端资源时需要）

## 运行

```bash
flutter pub get
flutter run
```

## 构建

```bash
flutter build apk --release
flutter build appbundle --release
```

版本号唯一来源是 `pubspec.yaml` 的 `version` 字段，不要在 gradle / Xcode 工程里硬编码。
发版无需本地打包：改 pubspec 版本 → 打 tag（`vX.Y.Z`）→ 在 GitHub 上发布 Release，
CI 会自动构建并把 APK 附到该 Release（安卓）/ 发 `ios-vX.Y.Z` 预发布得无签名 IPA（iOS）。
push 到 master 时 CI 也会自动构建验证。详见 `.github/workflows/`。

## 前端资源打包

当你修改 `milkdown_src/` 下的前端代码后，重新构建编辑器资源：

```bash
cd milkdown_src
npm install
npm run build
```

生成的产物会同步到 `assets/web/`，供 Flutter 端 WebView 加载。

## 说明

- 文件读写通过 Android SAF 完成
- 导出 DOCX 使用 Dart 端 OOXML 生成
- 导出 PDF 依赖原生打印能力

## 更新日志

### 2026-09-21

**工程化**
- 新增应用图标（teal 渐变 + 白色 M 与光标条，替换 Flutter 默认图标），Android 含 adaptive icon，iOS 全槽位覆盖；矢量生成脚本入库（`test/icon_generation_test.dart`）
- 新增 CI 双工作流：`Build APK`（push 验证 + Release 自动挂 `Mdeditor-<tag>.apk` / `Mdeditor-latest.apk`）、`Build IPA`（无签名 IPA，`ios-v*` 预发布自动挂载）
- 版本号单源化：删除 gradle 硬编码 versionCode/versionName，以 pubspec.yaml `version` 为唯一来源
- 签名可降级机制：CI 配置 keystore secrets 后自动使用正式签名，未配置时回退 debug 签名（配置步骤见 AGENTS.md 施工单A）

**iOS 构建链路（第一阶段）**
- 生成 `ios/` 工程（bundle id 与 Android 一致），支持 `flutter build ipa --no-codesign` 出无签名 IPA 供侧载
- 平台降级守卫：非 Android 平台调用原生通道改为统一「iOS 适配开发中」提示，不再抛 MissingPluginException；Android 行为零变化，新增 9 个守卫测试
- 文档：新增 `AGENTS.md`（项目规范 + 签名/iOS 两份施工单）与 `docs/plans/`（工作计划与施工日志）

### 2026-08-26

**新功能**
- 代码块语法高亮：基于 `@codemirror/language` 的 `StreamLanguage`，内置 JS/TS、Python、Bash、HTML、CSS、JSON、SQL、Markdown 轻量语法解析，无需引入完整 `@codemirror/language-data`，保持 APK 精简
- 括号自动补全：输入 `[` 或 `(` 时自动插入配对括号并定位光标
- 智能闭合跳过：输入 `]`、`)`、`` ` ``、`*` 等闭合字符时，若光标后紧接相同字符则跳过而非重复输入

**稳定性修复**
- EditorController 全面增加 `_disposed` 生命周期检查，防止 WebView 销毁后异步回调导致崩溃
- 所有 WebView JS 调用统一包裹 try-catch，渲染/主题切换/符号插入/格式化操作异常不再导致应用闪退
- 原生渲染管线 `_drainNativeRender` 修正 try-finally 结构，确保错误后仍能处理待渲染队列
- `_asciiEscapeJson` 修复 emoji 等补充平面字符（code unit > 0xFFFF）的转义处理
- 修复首页刷新时 `_future` 赋值顺序问题，避免竞态

**构建修复**
- Vite 构建配置增加 `process.env` polyfill，修复 prosemirror/micromark 运行时 `process is not defined` 错误

**新增模块**
- `android/render-core`：原生 Markdown 渲染模块（增量渲染、LaTeX/Math 预处理、光标偏移映射等 Kotlin 实现）

## 许可证

本项目基于 [GNU General Public License v3.0](LICENSE) 开源。

