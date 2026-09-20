# AGENTS.md — 项目规范与待办施工单

> 本文件写给 AI 协作者（你）。人类仓库主人是 Flutter/Android 新手，你的职责是把下面
> 的施工单翻译成他能理解的语言并引导他逐步完成，或直接代为实现后向他解释。
> 施工单执行完毕后请回填「结果」字段，并在 docs/plans/ 追加记录。
> 人类读者可把本文件当作「当前已知问题与待办」清单阅读。

## 0. 项目速览

### 品牌与图标

- **品牌主色 teal**：Flutter 壳 `ColorScheme.fromSeed(Colors.teal)`，前端编辑器
  accent `#00897B`（见 `assets/web/editor.css` 的 `--editor-accent`），二者同源。
- **应用图标**（2026-09-21 定稿）：teal 对角渐变 `#26A69A → #00695C` + 白色
  几何粗笔画 "M" + 白色圆角光标条，意为「正在编辑的 Markdown」。
- **改图标**：编辑 `test/icon_generation_test.dart`（矢量几何，不依赖字体），
  运行 `GEN_ICONS=1 flutter test test/icon_generation_test.dart`，提交全部生成
  产物（Android legacy 5 密度 + adaptive 前景/背景 + iOS AppIcon 全槽位）。
  不要手改 PNG。

### 结构

- **是什么**：Android Markdown 编辑器。Flutter 壳 + `webview_flutter` 加载
  Milkdown（ProseMirror）前端做所见即所得编辑；前端源码在 `milkdown_src/`
  （Vite 构建后产物提交入库于 `assets/web/`，**改前端要本地跑 `npm run build`
  并提交产物**）。
- **平台现状**：Android 完整可用；iOS 已有原生壳（`ios/`，2026-09-21 生成），
  UI 与 WebView 编辑器可运行，但依赖原生通道的功能显示降级提示（见施工单B）。
- **四条 Android 原生 MethodChannel**（Kotlin 实现在
  `android/app/src/main/kotlin/com/mdeditor/app/`）：
  | 通道 | 作用 | Dart 封装 | iOS 现状 |
  |---|---|---|---|
  | `mdeditor/saf` | 文件打开/另存/读写（SAF） | `lib/file_io/saf_channel.dart` | 未实现，guard 降级 |
  | `mdeditor/intent` | 外部「打开方式」唤起 | `lib/file_io/intent_channel.dart` | 未实现，返回空 |
  | `mdeditor/render` | 原生解析/mermaid/latex/剪贴板/导出 | `lib/native/native_render_channel.dart` | 未实现，内置降级（返回 null 走 WebView 兜底） |
  | `mdeditor/print` | 系统打印对话框（PDF） | `lib/export/pdf_export.dart` | 未实现（当前无调用方，预留代码） |
- `android/render-core/` 是原生渲染 Kotlin 模块（增量渲染、LaTeX 预处理等），
  仅 Android；iOS 靠 WebView 自渲染，行为差异属预期。

## 1. 构建与发布（2026-09-21 起）

- **版本号唯一来源**：`pubspec.yaml` 的 `version: X.Y.Z+N`（X.Y.Z → versionName /
  CFBundleShortVersionString，N → versionCode / CFBundleVersion）。
  **不要**在 `android/app/build.gradle.kts` 或 Xcode 工程里硬编码版本号。
- **发版流程**：改 pubspec 版本 → 提交 → 打 tag（安卓正式版 `vX.Y.Z`；iOS 里程碑
  `ios-vX.Y.Z` 且勾选 pre-release）→ 在 GitHub 上写说明发布 Release。CI 自动构建
  并挂载资产，无需本地打包上传。
  - `v*` Release 自动附：`Mdeditor-<tag>.apk` + `Mdeditor-latest.apk`
  - `ios-v*` Release 自动附：`Mdeditor-ios-<版本>.ipa`（**无签名**，需用户侧重签侧载）
- **CI**：`.github/workflows/build.yml`（APK，ubuntu）与 `build-ios.yml`（IPA，macos）。
  push 到 master 自动构建验证（paths 过滤），Release 事件挂资产。
- **Flutter 版本固定 3.47.0**（见两个 workflow 与 `.metadata`），升级须显式提交并全量回归。
- **签名机制**：gradle 读 `KEYSTORE_FILE`/`KEYSTORE_PASSWORD`/`KEY_ALIAS` 环境变量，
  未注入时回退 debug 签名（CI 日志有 warning）。**当前尚未配置正式密钥** → 施工单A。

## 2. 开发规范

- 提交信息：conventional commits + 中文描述（如 `feat: 代码块语法高亮、括号自动补全`）。
- 测试：`flutter test`（23 个测试，含 `test/ios_guard_test.dart` 的平台降级守卫）；
  静态检查：`flutter analyze`。两者必须全绿才算完成。
- 本地无 Mac / 无 Android SDK 时，所有构建验证依赖 CI（push 后看 Actions）。
- 无 Mac 的协作者（及其 AI）的完整工作循环、CI 查看、发版、坑速查：
  [DEVELOPMENT.md](DEVELOPMENT.md)。
- iOS 降级守卫：`lib/native/platform_support.dart` 的 `requireAndroid()`。新增
  MethodChannel 的 Dart 封装时，入口必须调用它（或像 `NativeRenderChannel` 那样
  捕获 `MissingPluginException` 优雅降级），并补进 `test/ios_guard_test.dart`。

---

## 施工单A：配置正式签名密钥（优先级：高）

**现状**：release APK 一直用 debug 密钥签名（CI 未配 secrets，自动回退）。
**风险**：debug 密钥是公开已知的，任何人都能伪造同签名的 APK 冒充升级你的应用；
也无法上架 Google Play；debug 签名的 APK 之间签名一致性无保障。
**已完成的前提**：gradle 与 CI 的注入链路已就绪（2026-09-21），配好 secrets 即自动生效，
工作流无需任何改动。

### 步骤（仓库主人操作，约 10 分钟）

1. **生成密钥**（在自己电脑上，只需一次；JKS/PKCS12 均可，密码自己定并妥善保管）：
   ```bash
   keytool -genkey -v -keystore mdeditor-release.keystore \
     -alias mdeditor -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
   ```
2. **转 base64**：
   ```bash
   base64 -w 0 mdeditor-release.keystore > keystore.b64      # Linux
   base64 -i mdeditor-release.keystore -o keystore.b64        # macOS
   ```
3. **配置 secrets**（仓库 Settings → Secrets and variables → Actions → New repository secret，共 3 个）：
   | Secret 名 | 值 |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | keystore.b64 文件的完整内容 |
   | `ANDROID_KEYSTORE_PASSWORD` | 第 1 步设置的 store 密码 |
   | `ANDROID_KEY_ALIAS` | `mdeditor` |
4. **触发构建**：Actions → Build APK → Run workflow，或直接 push 一个小改动。

### 验收

- 构建日志中**不再出现**「未配置 ANDROID_KEYSTORE_BASE64」warning。
- 下载产物 APK，确认签名主体是自己的密钥（指纹与 keytool 显示的一致）：
  ```bash
  apksigner verify --print-certs Mdeditor-latest.apk
  ```
- 连续两次构建的 APK 互相可覆盖安装（签名一致）。

### 决策点（需要仓库主人知情后自己拍板）

已发布的 v1.0.0（debug 签名）用户**无法**覆盖安装正式密钥的新版本，需要卸载重装
（数据丢失：仅「最近文件」索引，文档本身在用户自己的目录）。趁当前用户量小，
切换成本最低；拖得越久代价越大。

### 禁止事项

- **keystore 文件与密码永远不进仓库**（`android/.gitignore` 已忽略 `**/*.keystore`
  与 `key.properties`，继续保持）。一旦泄漏须作废重生成。
- 不要把密码写进任何文档、issue、聊天记录。

**结果**：（待回填：执行日期 / 验收结论）

---

## 施工单B：iOS 功能适配（优先级：中，可分批）

**现状**：iOS 壳已能构建（`flutter build ipa --no-codesign`），侧载安装后 UI、
设置、WebView 编辑器（Milkdown）可运行；但下列功能因原生通道无 Swift 实现而降级。
降级机制：`lib/native/platform_support.dart` 的 `PlatformUnsupportedError` +
`ErrorHandler` 统一转成「iOS 适配开发中,此功能暂不可用」提示。

**待实现**（按用户价值排序）：

1. **文件打开/保存**（`mdeditor/saf` 的 iOS 对应）——最高优先级，没有它 App 基本不可用：
   - `UIDocumentPickerViewController` 选文件，用 security-scoped access
     （`startAccessingSecurityScopedResource`）+ **bookmark 持久化**保证重启后仍可访问
     （对齐 Android 侧 `takePersistableUriPermission` 的语义）
   - 写入用 `NSFileCoordinator` 协调；「另存为」用 picker 的 export 模式
   - Dart 侧：在 `saf_channel.dart` 的 `requireAndroid()` 处改为按平台分发到
     新的 Swift handler（MethodChannel handler 注册在 `ios/Runner/AppDelegate.swift`）
2. **外部打开入口**（`mdeditor/intent` 的 iOS 对应）：
   - `Info.plist` 声明 `CFBundleDocumentTypes` + `UTImportedTypeDeclarations`
     （UTI：`net.daringfireball.markdown`，扩展名 md/markdown/mdown）
   - SceneDelegate/AppDelegate 的 `onOpenURL` → 通过现有 `mdeditor/intent` 通道
     推 URI 给 Dart（`main.dart` 的 `IntentChannel.openedUris` 监听已就绪）
   - 移除 `intent_channel.dart` 中的 iOS 空返回 guard
3. **PDF/HTML 导出**（当前 `mdeditor/render` 导出在 iOS 返回 null →「导出失败」提示）：
   - 最小实现：`UIMarkupTextPrintFormatter` / `WKWebView` 打印渲染 HTML，
     `UIGraphicsPDFRenderer` 落盘（成熟做法可参考 MDOpener 项目的 iOS 导出实现）
4. **mermaid / LaTeX**（`mdeditor/render` 的 iOS 对应）：可选。前端
   `assets/web/` 已带 katex/mermaid 资源，也可走纯前端渲染路线（WebView 内完成，
     不需要原生通道），改 `native_features.js` 的能力探测即可。

**验收方式**（每批）：`flutter analyze` + `flutter test` 全绿；iOS 真机或模拟器手动
走通对应功能；发 `ios-v*` prerelease 后侧载复核。完成后更新 `docs/plans/` 记录与
README 的「iOS 功能状态」表述。

**结果**：（待回填）

---

## 3. 已知可选优化（不紧急，动前先评估）

- **APK 体积 65MB**：`flutter build apk` 默认 fat APK 含三 ABI。可 `--split-per-abi`
  （多产物）或转 App Bundle（需 Play 上架）。
- **R8 压缩**：`build.gradle.kts` 中 minify/shrink 显式关闭。开启前需为
  render-core 的反射调用与 dexmaker 动态代理写 keep 规则，否则运行时崩溃。
- **错误文案 l10n**：`ErrorHandler.messageFor` 目前硬编码中文（与既有风格一致），
  英文界面下错误提示仍为中文，可迁移到 `lib/l10n/app_localizations.dart` 字典。

## 4. 变更记录

- 2026-09-21：初版。CI 双工作流、iOS 壳、版本单源、iOS 降级守卫由协作者 honlnk
  建立（详见 `docs/plans/ci-and-ios-v1.md`）；施工单A/B 待仓库主人执行。
