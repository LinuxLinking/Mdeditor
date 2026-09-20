# 无 Mac、靠 CI 的调试与开发工作法

> **写给谁**：手上没有 Mac（装不了 Xcode，本地出不了 iOS 包），但会用 Git 和 GitHub，
> 并且有一个 AI 编程助手（ZCode / Claude Code / Cursor 等任一）的人。有本地 Flutter /
> Android 环境更好，没有也不影响——本文主线全程只要求浏览器和手机。
>
> **两种用法**：
> 1. 自己通读一遍，理解整个闭环怎么转（约 10 分钟）；
> 2. 把 **第 6 节** 整段复制给你的 AI 当工作约定。（如果你的 AI 工具遵循 AGENTS.md
>    约定，仓库根目录已有一份常驻版，可不用手动贴。）
>
> 来源：这套方法在 MD Opener 项目上完整跑通过（安卓 + iOS 双端纯 CI 开发）。本仓库的
> CI 链路与 iOS 工程由协作者 honlnk 按同一模式于 2026-09-21 搭建，施工记录见
> `docs/plans/ci-and-ios-v1.md`。

---

## 1. 核心思想：把「编译」外包给 GitHub

三个事实凑成一套完整做法：

1. **Flutter 项目的代码全是文本**。Dart / Kotlin / 前端 TS 改起来不需要 IDE，
   AI 直接改文件就行。
2. **iOS 原生壳已经生成入库**（`ios/` 目录）。日常开发几乎不需要碰它；真要动工程
   配置也是改文本文件（`Info.plist`、`project.pbxproj`），AI 能处理。
3. **GitHub Actions 白送构建机**。公开仓库 ubuntu（安卓）与 macOS（iOS）runner
   **完全免费、不限总量**，`flutter build` 在云上完成。

于是分工变成三方循环：

| 角色 | 职责 |
|---|---|
| 你的 AI（在你电脑上） | 改代码、提交、推送 |
| GitHub Actions（在云上） | 回答「能不能编译过」，产出安装包 |
| 你的手机 | 回答「好不好用」 |

**AI 改 → CI 编译 → 真机测 → 反馈 → AI 再改**。安卓循环如此；iOS 因为本地没有 Mac
也**只能**如此。每一轮验证等几分钟，换来零本地环境维护成本。

---

## 2. 本仓库已经搭好的东西

| 文件 / 目录 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 安卓 APK 构建（**签名可降级**：未配 keystore secrets 时回退 debug 签名，日志有 warning） |
| `.github/workflows/build-ios.yml` | iOS IPA 构建（**无签名**，侧载前需重签） |
| `AGENTS.md` | 给 AI 的项目规范 + 两份施工单（A：正式签名配置；B：iOS 功能适配） |
| `docs/plans/ci-and-ios-v1.md` | 本次 CI / iOS 链路的施工记录（含 CI 首跑核对单） |
| `test/icon_generation_test.dart` | 应用图标矢量生成脚本（`GEN_ICONS=1` 门控） |

**版本号唯一来源**：`pubspec.yaml` 的 `version: X.Y.Z+N`。gradle / Xcode 工程里都不要
再写版本号。

**触发规则**（两个构建 workflow 一致）：

- push 到 `master` 且改动碰到 `android/`、`ios/`、`lib/`、`assets/`、`test/`、
  `pubspec.*`——只改文档不会触发构建（没跑 ≠ 坏了）。
- 在 GitHub 上**发布 Release** 时触发，构建完把安装包自动挂到该 Release。
- push 触发的构建只存 Actions artifact（30 天过期），**绝不发布到 Release**——
  发不发版永远是人工决定。

**iOS 当前功能状态**（重要，见第 3 节的预期管理）：UI 与编辑器可用；打开/保存文件、
导出等依赖原生通道的功能显示「iOS 适配开发中」提示。这是**现状不是 bug**，
适配待办在 `AGENTS.md` 施工单B。

**费用**：公开仓库构建免费不限量。唯一红线：仓库转私有后 macOS 按 10 倍费率计费，
保持公开就永远不用想这件事。

---

## 3. 标准工作循环：从「发现 bug」到「装上新包」

安卓为例约 5~10 分钟；iOS 多一步重签。

### 第 1 步：把问题记录成 AI 能用的反馈

不要只说「闪退」，按这个模板写：

```
【现象】点导出 PDF 后 SnackBar 显示「导出 PDF 失败: ...」
【复现】打开 a.md → 右上角更多 → 导出 PDF → 选位置 → 报错
【期望】应该正常生成 PDF 文件
【补充】报错完整文字 / 截图 / 文件内容
```

现象、复现步骤、期望行为，三样齐了 AI 就能开工。

**iOS 特有的预期管理**：如果某功能在 iOS 上点出来「iOS 适配开发中，此功能暂不可用」
的提示，这不是 bug，是施工单B 里排好队的待办——把「希望优先适配哪个功能」作为需求
提给 AI 即可，不用按 bug 报。

### 第 2 步：交给 AI 修

把反馈贴给你的 AI（第一次使用前先把第 6 节的约定贴给它，或确认它已读 AGENTS.md）。
它会改代码、提交、push 到 `master`。

### 第 3 步：等 CI

约 3~8 分钟。改动没碰到触发路径（比如只改了 README）就不会跑构建，属正常。

### 第 4 步：确认绿了

见第 4 节。绿了才有包拿；红了看日志，把**第一个**编译错误整段贴回给 AI。

### 第 5 步：下载安装包

从 Actions 运行页下载 artifact（安卓 `mdeditor-apk`、iOS `mdeditor-ipa`）。网页下载的
是 **zip**，解压出里面的 `.apk` / `.ipa` 才是安装包。

### 第 6 步：装机

- **安卓**：直接安装 APK。注意——**当前尚未配置正式签名**（施工单A 未执行时），
  CI 出的是 debug 签名包，与已装的 v1.0.0 或本地构建包可能互相顶不掉，签名冲突时
  先卸载再装。
- **iOS**：IPA 无签名，用你的重签工具（爱思助手自签 / AltStore / SideStore /
  Sideloadly）以自己的 Apple ID 重签后安装。**每次拿到新 IPA 都要重新签一次**——
  签名跟着文件走，旧签名对新文件无效。

装上后复测第 1 步的问题，解决了进入下一个，没解决把新现象再喂给 AI。

---

## 4. 查看 CI 与下载产物的两种方式

### 方式 A：纯网页

1. 打开仓库的 **Actions** 页，左侧选 `Build APK`（或 `Build IPA`），点最新一次运行
2. 绿勾 = 成功；红叉点进 `build` 任务看日志
3. 成功时页面底部 **Artifacts** 区域点对应名字下载

### 方式 B：gh 命令行（装了 [GitHub CLI](https://cli.github.com/) 更顺手）

```bash
gh run list --limit 5                      # 最近几次构建
gh run view <run-id> --json conclusion --jq .conclusion   # 权威结论：success / failure
gh run download <run-id> --name mdeditor-ipa --dir ./out  # 下载产物（直接解包）
```

一个教训：`gh run watch` 接管道（如 `| tail`）会丢真实退出码，**别用管道后的 `$?`
判断成败**，以 `gh run view --json conclusion` 为准。

---

## 5. 关于发版（可选阅读）

日常修 bug 用 artifact 就够了。想给用户分发时：

1. 改 `pubspec.yaml` 的 `version`（唯一来源，别处不写）
2. 提交并 push
3. 打 tag：安卓正式版 `vX.Y.Z`；iOS 里程碑 `ios-vX.Y.Z` 且**必须勾选 prerelease**
4. 在 GitHub 上写说明**发布 Release**（注意：推裸 tag 不触发，必须走「发布 Release」）

CI 自动挂载资产：安卓 `Mdeditor-<tag>.apk` + `Mdeditor-latest.apk`；iOS
`Mdeditor-ios-<版本>.ipa`。

---

## 6. 给你的 AI 的工作约定（复制整段贴给它）

```text
【环境与工具链】
- iOS 构建只能靠 GitHub Actions（本机无 Mac 无 Xcode）；安卓建议也走 CI 保持一致。
- Flutter 版本固定 3.47.0（workflow 与 .metadata 一致），升级须显式提出。
- 版本号唯一来源是 pubspec.yaml 的 version，不要在 gradle / pbxproj 里写版本号。

【仓库纪律】
- 提交信息：conventional 前缀 + 中文描述（feat: / fix: / docs: / chore: …）。
- 单人开发直接 push master；有协作者时开分支走 PR。不 push tag、不发 Release、
  不动 .github/workflows/，除非我明确要求。
- 小步提交：一次改动一个关注点，编译错误只有 CI 能暴露。
- pubspec.lock 只提交有意义的依赖变更：在国内镜像与 pub.dev 之间切换会让 lock 里
  的 URL 字段来回改写，这种纯 URL 变更不要提交。
- 前端 assets/web/ 是构建产物入库：改 milkdown_src/ 后要 npm run build 并把产物
  一起提交，否则 App 里的编辑器不会变。

【平台通道纪律】
- 四条原生 MethodChannel 只有 Android 实现；新增通道的 Dart 封装入口必须调用
  lib/native/platform_support.dart 的 requireAndroid()（或像 NativeRenderChannel
  那样捕获 MissingPluginException 优雅降级），并把测试补进 test/ios_guard_test.dart。
- iOS 功能适配的完整待办见 AGENTS.md 施工单B，按用户指定的优先级做。

【验证与汇报】
- 你无法验证任何运行时行为；一切 UI、交互、崩溃问题以我的真机反馈为准。
- push 后以 gh run view --json conclusion 为准跟踪构建；失败时从日志顶部找第一个
  编译错误，修复后再推，不要原样重推。
- 任务结束时汇报：改了什么；CI 结果与 run 链接；哪些行为没法验证、需要我重点测什么。
```

---

## 7. 前置条件清单

1. **Git** 与 GitHub 账号。仓库主人无需额外操作；协作者需要被加为
   Collaborator（Settings → Collaborators），或自己 fork。
   - fork 注意：安卓构建在 fork 里会以 debug 签名回退（签名 secrets 不随 fork
     复制）——能编译能装，但与原仓库的包不互通；iOS 不受影响。
2. （可选但推荐）**gh CLI**，装后 `gh auth login` 一次。
3. 一个 **AI 编程助手** + 第 6 节的约定（或 AGENTS.md 自动加载）。
4. iOS 调试额外需要：苹果设备 + 重签安装工具。

---

## 8. 已知坑速查

| 坑 | 一句话解法 |
|---|---|
| push 了但 CI 没跑 | 检查改动是否碰到触发路径；纯文档不触发 |
| 构建失败不知道哪错 | 日志从上往下第一个编译错误才是根因，后面的多是连带 |
| CI 上 gradle 依赖拉取超时 | 国内镜像在海外机房偶发不稳；重跑一次，仍失败让 AI 在 workflow 里临时把 distributionUrl 换成 services.gradle.org |
| 装新 APK 提示签名冲突 | 当前是 debug 签名回退阶段的预期行为，卸载旧包再装；根治见 AGENTS.md 施工单A |
| iOS 上功能点了没反应或提示「适配开发中」 | 预期降级，不是 bug；想优先适配哪个功能直接对 AI 说 |
| 网页下载的 artifact 装不了 | 那是 zip，先解压出里面的 .ipa / .apk |
| iOS 新包装不上 | 新 IPA 每次都要重新重签 |

---

## 9. 这套方法的边界

- **能做**：全部 Dart / 前端 / 原生壳代码开发、编译验证、双端安装包交付、真机功能
  验证的完整迭代闭环；iOS 原生功能适配（施工单B）也可以此模式推进。
- **不能做**：断点调试与性能分析（运行时深排障靠「加日志 → 复现 → 看输出」）；
  上架 App Store（需要开发者账号与签名链）。
- **代价**：每轮迭代多等几分钟 CI。

---

*创建：2026-09-21，伴随 CI 双工作流与 iOS 构建链路交付整理成文。*
