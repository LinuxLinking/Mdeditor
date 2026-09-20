# 工作计划：CI 工作流搭建 + iOS 构建链路（ci-and-ios-v1）

> 状态：**已完成（本地验收全绿）**——CI 实际构建验证待仓库推送后按 §9 栦对单执行
> 日期：2026-09-21
> 执行环境：macOS（无 Xcode / 无 Android SDK / 无本地 Flutter，构建验证依赖 CI，与 MDOpener 项目工作模式一致）
> 交付目标仓库：LinuxLinking/Mdeidetor（上游）；本次施工在 honlnk/Mdeidetor fork 内进行，**不 push、不发 PR**，推送方式由仓库主人决定

## 1. 背景与目标

仓库主人（LinuxLinking）无 Mac 电脑，无法本地打包 iOS；目前 GitHub 利用率接近零（无 CI、发版靠本地构建手动上传 APK）。本次由协作者（honlnk）按 MDOpener 项目已验证的方案，为其搭建：

1. **安卓工作流**：push 验证 + Release 自动构建挂载 APK（签名可降级，不依赖仓库主人先配 secrets）
2. **iOS 构建链路**：生成 ios/ 工程 + 无签名 IPA 工作流（交付后由用户侧重签侧载，同 MDOpener 模式）
3. **AGENTS.md 审计文档**：以审计者角度写足「签名问题」与「iOS 功能适配」两份施工单，供仓库主人的 AI 阅读并引导其自助完成

### 现状审计结论（2026-09-21 侦察）

- 3 个提交、仅 master 分支、1 个 tag（v1.0.0）、1 个 Release（APK 手动上传，65MB）
- 无 `.github/` 目录：零 CI、零自动化
- `android/app/build.gradle.kts`：release 构建使用 **debug 签名**（新手常见写法，风险见 AGENTS.md 施工单A）
- 版本号双源：pubspec.yaml `1.0.0+1` 与 gradle 硬编码 versionCode/versionName 并存
- 无 ios/ 目录（Flutter 仅启用 android 平台）
- 4 条 Android 原生 MethodChannel（`mdeditor/saf`、`mdeditor/intent`、`mdeditor/print`、`mdeditor/render`），Dart 侧**无任何 `Platform.is` 守卫**——iOS 上直接调用会抛 MissingPluginException
- 前端产物（assets/web/editor.js 等）已提交入库，CI 无需 Node 构建步骤
- 工具链：Flutter 3.47.0 stable（.metadata revision `4cf2416…`）/ Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0 / JDK 17；gradle 仓库与 wrapper 均指向腾讯/阿里国内镜像
- 测试基线：test/ 下 4 个文件（docx_export / docx_isolate / widget / recent_files）

## 2. 范围

### 本期做

| # | 交付物 | 说明 |
|---|---|---|
| 1 | `.github/workflows/build.yml` | 安卓：push 到 master（paths 过滤）+ workflow_dispatch + Release published 时构建，自动挂 `Mdeditor-<tag>.apk` 与 `Mdeditor-latest.apk` |
| 2 | `android/app/build.gradle.kts` 改造 | ① 签名降级：注入 `KEYSTORE_FILE`/`KEYSTORE_PASSWORD`/`KEY_ALIAS` 环境变量时用正式签名，缺失回退 debug（平移 MDOpener android/build.gradle:19-49 模式）② 版本单源：删除硬编码 versionCode/versionName，pubspec 为唯一源 |
| 3 | `ios/` 工程 | `flutter create --platforms=ios --ios-bundle-id com.mdeditor.app`（对齐 Android applicationId），入库 |
| 4 | Dart 侧 iOS 降级 guard | 涉及原生通道的功能在 iOS 上给出「暂不支持」提示（走现有 l10n 中英机制），不崩溃不红屏；**Android 分支行为零变化** |
| 5 | `.github/workflows/build-ios.yml` | iOS：`flutter build ipa --no-codesign` → 无签名 IPA → artifact + `ios-v*` Release 自动挂 `Mdeditor-ios-<ver>.ipa` |
| 6 | `AGENTS.md` | 审计发现 + 施工单A（正式签名切换）+ 施工单B（iOS 功能适配）+ 项目规范 |
| 7 | `docs/` | 本计划文档 + README 索引，起 docs 目录的头 |
| 8 | `README.md` 增补 | 构建徽章、下载/发版说明、iOS 侧载指引 |

### 本期不做（诱惑项显式排除）

- **Swift 通道实现**（saf→UIDocumentPicker、intent→onOpenURL、print→WKWebView 打印、render 降级）→ AGENTS.md 施工单B 留给仓库主人接力。本期交付的 iOS IPA 是「构建链路验证版」：能安装启动、界面可浏览，但打开/保存文件等依赖原生通道的功能显示「暂不支持」提示
- **Info.plist UTI 文件关联**（Files App「打开方式」注册）——依赖 intent 通道，做了无人接收，随施工单B
- **正式 keystore 生成与 secrets 配置**——签名身份属仓库主人，施工单A 引导自助完成
- AAB / Play 上架；按 ABI 拆分 APK（保持单 fat APK，65MB 体积问题在 AGENTS.md 记为可选优化项）
- 开启 R8/minify（仓库主人显式关闭；render-core/dexmaker 有反射，贸然开启有风险，不动）
- GitHub Pages 官网、README 结构性重写
- push / 发 PR / 合并到上游（推送决策留给用户）

## 3. 设计决策（已拍死，不留开放题）

| 决策点 | 结论 |
|---|---|
| Flutter 版本 | CI 固定 **3.47.0**（与 .metadata revision 一致），升级须显式提交 |
| tag 约定 | 安卓正式版 `vX.Y.Z`；iOS 里程碑 `ios-vX.Y.Z`（prerelease）。对齐 MDOpener 约定，为将来官网 latest 直链留路 |
| Release 资产名 | `Mdeditor-<tag>.apk` / `Mdeditor-latest.apk`（安卓）；`Mdeditor-ios-<ver>.ipa`（iOS） |
| 签名降级机制 | gradle 读 `KEYSTORE_FILE` 环境变量（PKCS12），三元切换 release/debug 配置；CI 仅当 `secrets.ANDROID_KEYSTORE_BASE64` 存在时解码注入，否则打警告用 debug——工作流先跑起来，仓库主人配好 secrets 后自动升级，无需改工作流 |
| 版本号来源 | pubspec.yaml `version: X.Y.Z+N` 唯一源（gradle 硬编码删除）；发版流程 = 改 pubspec → 打 tag → 发 Release |
| iOS bundle id | `com.mdeditor.app`（与 Android applicationId 一致） |
| iOS 降级文案 | 走现有 l10n（中/英），语义：「此功能在 iOS 上暂不可用，适配开发中」；呈现方式融入现有错误处理（error_handler.dart），不新增独立弹窗体系 |
| 触发分支 | master（上游默认分支）+ workflow_dispatch；fork 协作分支不自动触发 |
| gradle 国内镜像在 CI 的可达性 | 首跑按原样（腾讯/阿里镜像通常海外可达）；若 CI 拉取超时，预案为 workflow 内 `sed` 临时替换 distributionUrl 为 services.gradle.org（不改仓库文件，交付说明记录） |

## 4. 阶段划分与验收

门禁：每阶段收尾 `flutter analyze` 0 error + `flutter test` 全过 + 本文档状态随手更新。门禁不过不开下一阶段。

### 阶段① 环境与基线
- Flutter SDK 3.47.0 下载至 /tmp（临时，不污染系统），`flutter pub get` / `flutter analyze` / `flutter test` 跑通
- **验收**：analyze 0 issue、test 全过（若上游基线本身红，如实记录基线状态，后续以「不比基线差」为门禁）

### 阶段② 安卓工作流
- build.gradle.kts 签名降级 + 版本单源；编写 build.yml
- **验收**：analyze/test 复跑绿；gradle 改动与 MDOpener 模式逐行文本对照；yaml 语法校验通过；本机无 Android SDK，APK 实际构建归入 CI 首跑核对单（降级验证，兜底=核对单人工步骤）

### 阶段③ iOS 工程
- flutter create 生成 ios/ + 最小定制；Dart 侧降级 guard；编写 build-ios.yml
- **验收**：ios/ 生成物完整（Runner.xcodeproj / Podfile / Runner.entitlements 等）；analyze/test 复跑绿；guard 改动附测试（若通道层可注入平台判定则单测，不可测则降级为代码审查并记录）；本机无 Xcode，IPA 实际构建归入 CI 首跑核对单

### 阶段④ AGENTS.md
- **验收**：覆盖审计发现、施工单A（含 keytool 命令、secrets 配置入口、`apksigner verify --print-certs` 验收、v1.0.0 老用户卸载重装的迁移代价决策点、keystore 永不入库的禁止事项）、施工单B（四通道 iOS 实现清单与验收）、项目规范（提交格式/测试命令）

### 阶段⑤ README 增补与收尾
- **验收**：徽章/下载/侧载节齐全且链接指向上游仓库；本文档施工日志与状态收束；CI 首跑核对单落档

## 5. 迁移条款

| 改动 | 旧数据/用户影响 |
|---|---|
| 版本号单源化 | 无数据迁移。versionCode/versionName 数值不变（1 / 1.0.0），纯来源重构 |
| Android 签名（本次不动，仅留接口） | 仓库主人将来按施工单A 切正式 key 后，**v1.0.0 已安装用户（debug 签名）无法覆盖升级，需卸载重装**——该代价在 AGENTS.md 明示，决策权在仓库主人 |
| ios/ 新增 | 纯新增目录，Android 构建路径不受影响 |

## 6. 新旧机制替代表

| 旧机制 | 去向 |
|---|---|
| 本地构建 + 网页手动上传 APK 发版 | **替换**为 Release published 自动构建挂载（本地构建仍可用，但发版不再依赖） |
| gradle 硬编码 versionCode/versionName | **删除**（pubspec 单源接管，数值不变） |
| release 固定 debug 签名 | **并存降级**：env 注入则正式签名，缺失回退 debug（原行为保留为兜底） |
| 无 CI | 新增 build.yml / build-ios.yml（无旧机制冲突） |

## 7. 文档同步计划

- 本文档：状态流转（施工中 → 已完成）、施工日志（日期 + 阶段 + 提交 hash + 验收结论 + 偏差记录）随阶段追加
- README.md：阶段⑤ 增补徽章与下载/侧载说明
- AGENTS.md：阶段④ 一次性交付，施工单被仓库主人执行后由其 AI 回填结果

## 8. 施工日志

### 2026-09-21 · 阶段① 环境与基线
- Flutter 3.47.0（macOS zip）解压至 /tmp 临时使用，未污染系统；revision `4cf2416…` 与项目 `.metadata` 完全一致。
- 验收：`flutter analyze` 0 issue；`flutter test` 14/14 通过。基线干净。
- 偏差：`pub get` 曾改写 `pubspec.lock`（仅镜像 URL 从 `pub.flutter-io.cn` 变为 `pub.dev`，版本与哈希不变）——已 `git checkout` 还原，保持仓库主人的国内镜像配置；CI 上 pub 自动按默认源重新解析，不受影响。

### 2026-09-21 · 阶段② 安卓工作流
- `android/app/build.gradle.kts`：新增 `signingConfigs.create("release")`（读 `KEYSTORE_FILE`/`KEYSTORE_PASSWORD`/`KEY_ALIAS` 环境变量，PKCS12）+ buildTypes 三元切换（平移 MDOpener android/build.gradle 模式）；删除硬编码 versionCode/versionName（pubspec 单源，数值不变 1/1.0.0）。
- `.github/workflows/build.yml`：ubuntu-24.04 + JDK 17 + flutter-action v2（3.47.0）；push(master, paths)/workflow_dispatch/release(v*) 触发；secrets 缺失时解码步骤打 warning、构建步骤不导出 KEYSTORE_FILE → gradle 自动回退 debug；Release 自动挂 `Mdeditor-<tag>.apk` + `Mdeditor-latest.apk`。
- 门禁：analyze 0 issue、test 14/14、yaml 校验通过（9 steps / 触发器齐全）；gradle 改动与 MDOpener 模式逐行对照一致。APK 实际构建归 CI 首跑核对单。

### 2026-09-21 · 阶段③ iOS 工程
- `flutter create --platforms=ios --org com.mdeditor --project-name mdeditor .` 生成 ios/（新模板含 SceneDelegate 与 Swift Package Manager 集成，无 Podfile——插件依赖走 SPM）。
- 偏差①：flutter create 无 `--ios-bundle-id` 参数（默认 `com.mdeditor.mdeditor`），生成后 sed 全量对齐为 `com.mdeditor.app`（主 target 3 处 + RunnerTests 3 处，后者自动成为 `com.mdeditor.app.RunnerTests`，符合惯例）。CFBundleDisplayName 模板自动生成为 `Mdeditor`，无需改动。
- Dart 降级守卫：新增 `lib/native/platform_support.dart`（`PlatformUnsupportedError` + `requireAndroid()`）；`saf_channel.dart` 5 方法加守卫；`intent_channel.dart` 的 `getInitialUri` 非 Android 返回 null、`openedUris` 返回空流（**偏差②**：计划笼统写「iOS 上给提示」，落地时区分语义——冷启动 `getInitialUri` 在 runApp 之前 await，抛错会让 app 无法启动，返回 null 等价「无外部唤起」是正确的降级语义）；`pdf_export.dart` 的 `printHtml` 加守卫。
- **偏差③（对计划的最重要修正）**：`native_render_channel.dart` **未加守卫**——细读后发现其每个方法已内置 `MissingPluginException` 捕获并返回 null（WebView 兜底），作者当初已考虑跨平台降级，无需重复建设。代价：iOS 上导出 PDF/HTML 显示通用「导出失败」而非「iOS 适配开发中」专门提示，记入 AGENTS.md 施工单B 一并处理。
- `error_handler.dart`：新增 `ErrorKind.platformUnsupported` + classify 类型特判 + messageFor 文案 + `display()` 统一显示方法；`editor_page.dart` 6 处 catch 的 `_showMessage('…: $e')` 改为 `ErrorHandler.display(...)`（结构不动，仅替换显示行）。
- **偏差④**：降级文案落地为硬编码中文而非计划所述「走 l10n 中英机制」——error 管线现状（`messageFor`）本就是硬编码中文不走 l10n，guard 单独接 l10n 反而风格割裂；l10n 迁移记入 AGENTS.md 可选优化。
- 测试：新增 `test/ios_guard_test.dart` 9 个测试（守卫抛错/intent 空返回/classify/display）。施工中自伤两次均已当场修复：① 编辑 saf_channel 时误删类闭合括号（analyzer 立即暴露）；② readUri 等同步函数的守卫异常是同步抛出，测试断言从 failed-Future 改为闭包形式。
- `.github/workflows/build-ios.yml`：macos-15 + flutter-action（3.47.0）；`flutter build ipa --release --no-codesign`（优先取 `build/ios/ipa/*.ipa`，缺失时从 xcarchive 手动打包 Payload 兜底）；`ios-v*` Release 自动挂 `Mdeditor-ios-<版本>.ipa`。
- 门禁：analyze 0 issue、test 23/23（基线 14 + 新增 9）、yaml 校验通过（7 steps）。IPA 实际构建归 CI 首跑核对单。

### 2026-09-21 · 阶段④⑤ 文档
- `AGENTS.md`：项目速览（四通道清单表）、构建与发版规范、施工单A（正式签名：keytool 命令 / 3 个 secrets / apksigner 验收 / v1.0.0 老用户卸载重装决策点 / 禁止事项）、施工单B（iOS 四通道适配清单，按用户价值排序）、可选优化（APK 体积 / R8 / 错误文案 l10n）。
- `README.md`：双工作流徽章（指向上游 LinuxLinking 仓库）、「下载」节（latest.apk 约定 + debug 签名现状提示）、「iOS（侧载版）」节、构建节 CI 说明、更新日志 2026-09-21 条目。
- 本文档状态收束。门禁终验：analyze 0 issue、test 23/23。

### 2026-09-21 · 追加：应用图标设计

- 设计：teal 对角渐变 `#26A69A → #00695C`（`--editor-accent #00897B` 恰为中值，与壳层 `fromSeed(Colors.teal)` 同源）+ 白色几何粗笔画 M + 白色圆角光标条（「正在编辑的 Markdown」）。
- 实现：`test/icon_generation_test.dart`——纯 `dart:ui` 矢量绘制（M 为手工 Path，不依赖字体度量），`GEN_ICONS=1` 环境变量门控手动运行，CI 不跑。产物：Android legacy 5 密度 + adaptive icon（`mipmap-anydpi-v26/` + 前景/背景，新 Android 圆形蒙版不裁图）+ iOS AppIcon 全部 15 个唯一槽位。
- 验收：像素级校验（四角渐变色、内容包围盒对称性）通过——1024 图内容左右边距 202/202、432 前景 90/90、48px 图 10/10。施工中修复一个 rasterization bug（`picture.toImage(px)` 光栅化的是逻辑 0..px 区间，须先 `canvas.scale(px/512)`）。视觉模型复核两轮：第一轮报告的缺陷与像素数据一致（真 bug）；修复后第二轮仍复述旧症状（幻觉），最终以像素校验为准。
- 门禁：analyze 0 issue、test 23 过 + 1 skip（图标脚本）。

### 2026-09-21 · 追加：DEVELOPMENT.md 工作法文档 + 修复 .gitignore 吞文档事故

- 应用户要求补写 `DEVELOPMENT.md`（无 Mac 靠 CI 的调试工作法，写给仓库主人及其 AI，结构对齐 MD Opener 同名文档）。
- **偏差（重要）**：发现仓库根 `.gitignore` 的 `*.md` 全忽略规则（仅白名单 README 系）静默吞掉了 `AGENTS.md` 与 `docs/plans/ci-and-ios-v1.md`——**此前两个提交声称已交付的这两份文档实际从未进入 git**（`git add -A` 跳过 ignored 文件，`git status` 也不显示，形成假象）；README 中的 AGENTS.md 链接在 git 历史里一度指向不存在的文件。本轮在 .gitignore 白名单补 `!AGENTS.md`、`!DEVELOPMENT.md`、`!docs/**`（保留「根目录不乱放 md」的既有意图）并补交全部文档。核对确认：Kotlin/Dart/工作流/图标产物此前均已正常入库，仅 md 文档受影响；CI 构建链路不受影响。
- 教训记档：**交付含文档的项目时必须以 `git ls-files` 核对实际入库清单，不能只看 `git status`/`git add` 的输出下结论**（ignored 文件在两者中都不出现）。

## 9. CI 首跑核对单（push 后人工执行）

> 本次施工不含 push。仓库主人（或协作者经其同意）推送后按序核对：

1. push 后 Actions 页两个工作流均出现且绿：`Build APK`（push 触发）、`Build IPA`（push 触发）
2. 若 gradle 依赖拉取超时/失败：按 §3 预案在 workflow 中临时替换镜像源后重跑，并将结论回填本节
3. 手动 `workflow_dispatch` 跑一次 Build APK，下载 artifact 确认 `app-release.apk` 可安装（debug 签名阶段属预期）
4. 改 pubspec 版本号 → 打 `v1.0.1` tag → 发 Release：确认自动挂载 `Mdeditor-v1.0.1.apk` 与 `Mdeditor-latest.apk`
5. 发 `ios-v1.0.1` prerelease Release：确认自动挂载 `Mdeditor-ios-1.0.1.ipa`，下载后用 AltStore/Sideloadly 重签安装验证「暂不支持」降级提示呈现正常
6. 核对结论回填本节，关闭本计划
