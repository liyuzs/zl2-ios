# 更新日志

> 记录每个版本改了什么。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。
> 版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [未发布] —— 打磨中

这一轮次的改动**尚未构建成 IPA**，代码在 `master` 分支本地，等待推送。

### 新增

- **环境诊断**（设置 → 环境诊断）：一键检查设备、Java 运行时、启动核心、图形库、沙盒权限、游戏数据，可复制报告
- **首次启动引导**：三页欢迎 + 真实自检（检查 JRE 和核心是否就位）
- **启动闪屏**：5 个步骤的进度条，替代原来的白屏
- **新手引导卡**：首页没装版本时显示三步指引
- **版本自定义图标**：30 个内置图标 + 从相册选图，按版本独立保存
- **FPS / 内存显示**：游戏内悬浮球显示实时帧率和内存占用
- **键位映射表**：GLFW 全键码（可打印字符 / 功能键 / 小键盘 / 修饰键）
- **文档索引**：25 篇文档的导航

### 修复

- **特殊按钮 / 方向键 / 小键盘的键位全是哑的**：控制布局的键位存的是字符串，导出时要翻译成整数键码，而核心有一份自己的键名表（108 个名字）。三处对不上：①`SPECIALBTN_*`（打开菜单、弹键盘、虚拟鼠标等 9 个，核心里是负数 −1…−9）完全没映射；②核心用 `NUMPAD_*` / `DPAD_*`，我们写的是 `KP_*` / `UP|LEFT|...`；③导出器用 `code > 0` 过滤，把所有负数特殊键码丢掉了。全部已对齐。
- **首次进游戏没有任何控件**：`defaultTouchCtrl` 的默认值是 `default.json`，但生成该文件的 `generateAndSaveDefaultControl()` **在整个工程里没有任何调用点**，`controlmap/` 目录也没人创建（而它用 `NSOutputStream` 写文件，父目录不在会静默失败）。首次启动必然弹 `Could not open ...`，且屏幕上没有按钮和摇杆 —— 进游戏没法操作。
- **两个核心函数从未被调用**：手柄默认布局 `generateAndSaveDefaultControlForGamepad()`、UIKit 钩子 `init_hookUIKitConstructor()`（上游在 `main.m` 里调，我们用 SwiftUI `@main` 没有 `main.m`，所以图片等比例缩放的 swizzle 和 idiom 强制从没生效）。
- **桥接头少了 `setPrefBool` 声明**：上一轮用到它但头文件只声明了 4 个函数，会直接编译失败（`swift-lint` 只查括号，查不出这类）。
- **保存过自定义控制布局后，进游戏必崩（最严重的一个）**：导出器把 `version` 写成 `1`，而核心按这个字段决定是否跑旧格式迁移 —— `version 1` 会依次执行 `convertV1Layout → V2 → V5 → V7 → V8`。迁移代码里有 `[keycodes addObject:btnDict[@"keycode"]]`，而我们写的是 `keycodes`（复数）、没有 `keycode`（单数），`nil` 塞进 `NSMutableArray` 会抛 `NSInvalidArgumentException`，这条路径没有 `@try` 包着 —— 直接闪退。顺带还会把所有控件尺寸减半、样式全部覆盖。改成 `version: 8`（核心自己生成的默认布局用的就是这个）。
- **摇杆放错了列表**：核心把控件分成三个互不相通的列表（`mControlDataList` / `mJoystickDataList` / `mDrawerDataList`），摇杆原来被塞进按钮列表，而 `mJoystickDataList` 从未写出去 —— 摇杆会以普通按钮的身份被创建，没有方向摇杆行为，进游戏等于走不了路。
- **两处写不进去的偏好**：`controll.hardware_hide` 拼写笔误（同文件其它三处都是 `control.`），导致接鼠标后控制层不恢复显示；`internal.internal_launch_on_boot` 在默认字典里从未定义，而 `PLPreferences.setObject` 只写「已存在的键」，未定义就静默失败。
- **内存分配滑块完全无效**：写的是 `general.allocated_memory`，核心读的是 `java.allocated_memory`；而且核心在 `java.auto_ram` 为真时根本不看这个值（没有内存 entitlement 的设备上它默认就是真）。两层叠在一起，用户拖了滑块等于没拖。现在同时写对键名并关掉 auto，还把值压到物理内存一半以内。
- **控制布局导出了却没人加载**：JSON 正确写进了 `controlmap/`，但没告诉核心去加载它。核心读布局名走 `PLProfiles` 的两处（`launcher_profiles.json` 或 `control.default_ctrl`），原代码只写了 `UserDefaults` —— 核心一直在加载默认布局。
- **渲染器选了不生效**：`JavaLauncher` 进启动流程后会重新读一次 renderer 并覆盖环境变量，兜底是 `video.renderer`（默认 auto）。上一轮的净化避免了崩溃，但用户的选择被丢掉。现在同步写 `video.renderer`。
- **1.20.1 被强行用 Java 21 启动**：`requiredJavaVersion` 里 `if mi >= 20` 把整个 1.20.x 判成要 21，实际分界是 1.20.5。加上 `java_homes` 里 `1_17_newer` 被写成 21（核心自己的默认是 17），1.17~1.20.4 全被拉去 Java 21 —— 而 1.17 用 Java 21 会直接崩。
- **JRE 自检"通过"但启动失败**：`runtimeCheck()` 只要任意一个 JRE 在就返回 true，但启动用的是按版本算出的 minJava。拆成按版本检查，失败时报「需要 Java X，包里只有…」。
- **bootstrap 里写偏好的动作全丢失**：`applyUserSettings()` 在 `loadPreferences()` 之前执行，那时全局 `pref` 还是 nil，ObjC 对 nil 发消息是静默无操作。顺序已改为 setenv → loadPreferences → 再读写。
- **渲染器可以填任意字符串**：设置页的「渲染器」本来是自由输入框，打进 `OpenGL` 或旧配置残留的 `libmobileglues.dylib`，核心会拿这个名字直接 `dlopen("@rpath/<名字>")`，必然失败 —— 表现是启动黑屏或闪退，界面上完全看不出原因。现在改成下拉，只列包里真实存在的后端；启动时还会把旧配置里的残留值净化掉（认不出来的短名补成全名，认不出来就回落 ANGLE → GL4ES）。
- **版本号从来没被真的写进去**：`project.yml` 里 `MARKETING_VERSION` 硬编码 `0.1.0`、`CFBundleVersion` 硬编码 `1`，而 CI 的 Release tag 用的是运行号（`build-235`、`build-236`…），两者毫无关联 —— 不管装哪个构建，App 都自称 `0.1.0 (1)`。现在 CI 在生成工程之前把 `1.0.<运行号>` 和 `<运行号>` 写进 `project.yml`，并加了断言：注入失败直接构建失败，不会静默产出旧版本号。
- **「检查更新」永远说有新版本**：旧逻辑把 tag `build-236` normalize 成 `"236"`，再跟 `"0.1.0"` 比大小，`236 > 0` 恒成立，于是线上就是最新版也一直提示更新。改成优先按 build 号比较（tag 的 `build-N` 与 `CFBundleVersion` 同源），抽不到 build 号才退回语义化版本。21 条用例覆盖了这条回归。
- **点「下载更新」会 404**：Release 里的文件名是 `ZL2.ipa`，兜底地址却写着 `CraftLauncher.ipa`。已对齐。
- **渲染器崩溃**：`MobileGlues` 在代码里声明可选但 IPA 里没有这个库，选了必崩
- **启动崩溃**：`egl_bridge` 的 `default` 分支默认指向 MobileGlues，所有 OpenGL 3.0+ 版本启动即崩
- **首屏文案**：写着「专为 Android 设备打造」
- **渲染器说明**：全是 Turnip / Adreno 等安卓术语
- **按钮无响应**：编辑器的「布局信息」按钮设置了标志但没人监听
- **孤儿组件**：SplashScreen / WelcomeScreen 写好了从没挂载
- **CI 构建失败**：JRE 下载源域名失效，改为从已有 IPA 提取

### 改进

- **版本隔离**：每个游戏版本独立的 mods / saves / config 目录（`libraries` 与 `assets` 保持共享）
- **控制布局回写**：编辑器调好的布局现在能真正应用到游戏里（新增 ZL2 → Pojav 格式转换）
- **设置项标注**：115 项中 75 项明确标注「不支持 / 未接入」，置灰并说明原因
- **下拉刷新**：模组管理、资源管理页支持下拉重扫目录
- **死代码清理**：删除 204 行无用代码
- **键名表契约测试**：新增 `_test-keynames.js`，把核心的 108 个键名全抽出来逐条确认可解析
- **跨边界契约测试**：新增 `_test-layout-contract.js`，从核心源码读出布局格式要求、从导出器源码读出实际行为，两边对撞
- **偏好键存在性审计**：新增 `_audit-prefkeys.js`，检查所有 `setPref*` 的键是否在默认字典里定义过（未定义会静默失败）
- **三套存储对撞审计**：新增 `_audit-stores.js`，把「Swift 写 UserDefaults 但核心在别处读」的键全找出来。这次靠它翻出上面三个假功能
- **渲染器可见性**：环境诊断多一项「当前渲染器」，显示净化后真正生效的后端；存的值和实际不一致时标黄并写出原值
- **版本号单一来源**：`Info.plist` 不再重复写死版本，改为引用 `$(MARKETING_VERSION)`；`LicenseScreen` 也不再自己写一份兜底值，统一走 `ZLUpdateChecker`

### 已知问题 / 新增

- **【新增】启动前预检**：点「尝试启动」之前先列出七项必崩条件（版本 JSON/mainClass、client jar（含 `inheritsFrom` 父版本）、libraries、资源索引、对应 Java 运行时、渲染器、控制布局），只提示不阻止。配套 `_test-preflight.js` 11 条契约测试，锁住「布局名必须从核心偏好读」「jar 检查必须考虑 inheritsFrom」等约定。

- **【新增】启动失败页「打包日志发给开发者」**：启动失败那一屏直接可打包（复用诊断页的组包逻辑，并附加错误信息与启动日志），不用退出全屏页再去设置里找。同时补了 `launchJVM 返回错误码 N` 的提示分支——原来这一类最可能撞到的错误在界面上没有任何说明。

- **诊断报告的结论会误报「一切正常」**：`exportText` 原来看 `fails.isEmpty && warns.isEmpty` 就写「一切正常」，但 `items` 为空还有另一种原因——检查还没跑完（用户一进页面就点打包）。已改成三态：未完成 / 一切正常 / N 项异常。
- **打包分享有两条静默失败路径**：组包失败、或拿不到根视图时都静默返回，用户点了按钮什么都不会发生。已都改成弹提示（拿不到根视图时还把 zip 文件名告诉用户）。

- **【新增】环境诊断页「打包日志分享」**：一键把诊断报告 + `ame.log` + `latest.log` + 最近两个崩溃报告 + 目录清单打成 zip 分享。真机出问题时不用再让朋友进「文件」App 手动找日志。目录清单是刻意加的——即使日志为空也能看出 `bundle/libs` 有没有 jar、`java_runtimes` 有没有三套。

- **10 个只声明没用的 `@State`**：`AssetsScreen.installedOnly`（想做「只看已安装」筛选但控件没做）、`DownloadAddonsScreen` 的三个 `show*Picker`、`HomeScreen.secretIdx`（彩蛋实际用 `versionTaps`）、`JavaManageScreen.importing`、`ModifyVersionScreen.showLoaderList`、`SkinCapeScreen.selectedCape`、`TerracottaScreen.playerName`、`ZL2App.lanTab`。已全部删除，无功能影响。

- **导出整合包整屏有一半是摆设**：①三个格式（MCBBS / Modrinth / CurseForge）三选一，但 `startExport()` 从没读过 `format`，三者产出同一个普通 zip，也没有任何清单文件；②「一并打包远程资源」是个死 Toggle（绑定的状态没人读）；③名称/版本/作者/描述/最小内存五个字段各自只出现 1 次（就是绑定本身），导出时一个都没用。已去掉假格式与死开关，并让元数据真的写进 zip（`整合包说明.txt` + `pack-info.json`）。

- **多人联机页三个假交互**：「启用多人联机」Toggle 绑的是本地 `@State`（没持久化、没人读）；「分享联机核心日志」和「关于 EasyTier」都有图标/箭头暗示可点，但没有 `Button` 也没有目标页。远程联机需要 EasyTier 内核（iOS 未接入），已把这一组换成明确标注「尚未接入」的说明卡，并删掉无用的 `enabled` 状态。

- **「当前隔离规则」文案会说谎**：`versionIsolation` 已标为不可用（核心自己算游戏目录、忽略 `GAME_DIR`），但设置页那行仍按 `isolationEnabled` 分支——配置里残留 true 就会告诉用户「模组在 `versions/<版本>/` 下」，而游戏实际读 `.minecraft/mods`。已改成恒为真话并注明「按版本隔离在当前版本不可用」。

- **下载环节三处「看起来成功、实际是坏文件」**：①模组/资源包下载只要文件存在就跳过（0 字节或半截文件永远不重下），且不校验产物（HTML 错误页会被存成 `.jar`）；②`client.jar` 只判大小 >1KB，没校验 Mojang 给的 SHA-1；③依赖库下载失败只计个数，还输出「安装完成」。都已修：已有文件必须非空、jar/zip 校验 PK 魔数并识别 HTML、client.jar 校验 SHA-1、失败时列出具体库名并明说该版本可能启动不了。

- **Fabric API 安装会「找不到就用别的凑」**：`ZLFabricAPIInstaller` 里搜不到 `fabric-api` 项目就取搜索结果第一条（可能是完全无关的模组），找不到指定版本就取该项目第一个版本（版本与游戏版本绑定，装错多半加载失败）。两处都已改成精确匹配 + 明确报错。同类扫描后确认其余 `?? xxx.first` 都是同一实体内的兜底（换个文件），可以接受。

- **安装失败时会静默写一份「启动不了」的版本 JSON**：`VersionInstaller` 在元数据下载失败时，兜底用「自己重组」的 JSON 落盘，而那份缺 `arguments` / `minecraftArguments` / `assets` / `javaVersion` / `libraries.rules` —— Java 侧拼不出启动命令。更糟的是不报错，用户以为装好了、点启动才失败，且残缺 JSON 已落盘只能重装。已改成明确报错并删除该兜底。

- **`CallbackBridge` 两个 native 未导出**：`nativeSetInputReady(Z)Z` 由 `GLFW.class` 引用（真实路径），`nativeSendData(ZILjava/lang/String;)V` 是安卓那套 Java→native 输入入口。都已补上 JNI 导出；`nativeSendData` 是只记日志的占位实现（iOS 输入方向相反），若真机日志出现该行则说明确有代码走这条路。
- **上游 `window-size` 回调笔误**：`CallbackBridge_nativeSetInputReady` 里 `GLFW_invoke_WindowSize` 分支调的是 `GLFW_invoke_FramebufferSize`，导致该回调从未触发。已修正。

- **`UIKit.updateMCGuiScale` 没实现**：jar 里 `org/lwjgl/glfw/GLFW.class` 会引用它（LWJGL 建窗口/改尺寸时调），而核心只导出了 `showError`。缺了就是 `UnsatisfiedLinkError`。已补上并转发到 `MinecraftOptionUtils.updateMCGuiScale`；同时给无调用者的 `refreshAWTBuffer` 留了空实现兜底。

- **JNI 注册拿 NULL 的 jclass 去调 RegisterNatives（每次 JVM 启动都会崩）**：`registerOpenHandler()` 在 `JNI_OnLoad` 里注册 `CTCClipboard` 的 native 方法，而两个包名的 `CTCClipboard` 在我们用的 cacio jar 里都不存在 → `FindClass` 返回 NULL 且留下未清理的异常 → `RegisterNatives(env, NULL, ...)` 让 HotSpot abort。已在两处 `RegisterNatives` 加判空；代价是游戏内复制粘贴不可用（需要带 `CTCClipboard` 的 cacio 构建才能恢复）。

- **Java 侧环境变量回退分支曾被漏掉**：`libs/launcher.jar` 的 `Tools.class` 同时引用 `GAME_DIR` / `POJAV_GAME_DIR`、`AME_HOME` / `POJAV_HOME`，做的是"读一个、没有退回另一个"。我们原来只设了不带前缀的那份，走 `POJAV_` 分支会拿到 null。已把两份都设上（`setGameEnv`），并新增 `_audit-env.js` 自动对撞。

- **缺 Java 侧启动器 jar（最严重）**：`core/JavaLauncher.m` 拉起 JVM 时要用 `<bundle>/libs/patchjna_agent.jar`（`-javaagent`）、`<bundle>/libs/*.jar`（`-cp`，主类 `net.kdt.pojavlaunch.PojavLauncher`）、`<bundle>/libs_caciocavallo17/*.jar`（`-Xbootclasspath/a`），而**仓库里一个 jar 都没有，也没有 Java 构建步骤**，已发布的 build-235 IPA 解包后同样没有 `libs/`。JVM 连启动都完不成。详见 [缺失组件-Java启动器jar](docs/缺失组件-Java启动器jar.md)，`_check-runtime-assets.js` 会自动检出。
- **版本隔离实际无效**：核心在元数据启动分支里自己算游戏目录、忽略 `GAME_DIR`，所以隔离改不到真实目录；而 UI 又会显示模组在 `versions/<id>/mods`，实际游戏读的是 `<mcRoot>/mods`。已置灰并写明原因、默认关闭。
- **核心算的游戏目录曾比实际少一层 `.minecraft`**：核心用 `general.game_directory`（默认 `default`）+ profile 的 `gameDir`（默认 `.`）拼出 `instances/default`，而我们装在 `instances/<实例名>/.minecraft`。已通过写 `general.game_directory = "<实例名>/.minecraft"` 对齐。

- **尚未在任何 iPhone 上跑通过** —— 能编译、结构完整，但游戏能否真正启动未知
- Forge / NeoForge 装不了（iOS 禁止 fork 子进程）
- Terracotta 远程联机需要 Network Extension 权限（付费开发者账号）

---

## [build-235] —— 2026-11-05

最后一个成功构建的版本。

### 包含

- 界面完整（27 个页面）
- Amethyst 启动核心已链接
- JRE 17 / 21 / 25 三套齐全
- 19 个 Frameworks（图形 / 声音 / 认证）
- UniversalJIT26.js
- IPA 大小 132 MB

### 状态

- Swift 编译通过
- IPA 结构完整（980 个条目）
- **未在真机验证**

---

## [build-150] —— 2026-11-04

- 修复 Swift 编译错误（`@ViewBuilder` 缺 escaping）
- 首次成功产出 IPA

---

## [build-1 ~ build-149] —— 2026-10-31 ~ 11-04

早期开发，UI 原型阶段。主要是界面搭建和核心集成调试。

---

## 版本号说明

这个项目用两种标识：

| 标识 | 含义 |
|---|---|
| `build-NNN` | GitHub Actions 的构建序号，每次推送自动递增 |
| `0.1.0 (1)` | App 的 `CFBundleShortVersionString` / `CFBundleVersion` |

**目前还没有正式的语义化版本号**，因为一直没到「能稳定跑起来」的程度。
等真机验证通过、核心功能稳定后，会打第一个 `v0.1.0`。

---

## 怎么查当前版本

1. App 内：设置 → 关于
2. IPA 文件名或构建页：`build-NNN`
3. 代码里：`project.yml` 的 `MARKETING_VERSION`
