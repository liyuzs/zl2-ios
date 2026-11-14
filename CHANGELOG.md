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

- **无障碍基线 78 → 39**：第110轮建的基线不准——判据把「图标 + Text("添加服务器")」这类**自带文字名字**的按钮也算成无标签，实测 78 处里 **33 处是误报**。判据已修正（label 块里有 `Text(` 也视为有名字），并补了 7 处真标签：服务器列表的编辑/删除、版本列表的版本设置/更多操作、编辑器的返回/＋菜单/新增控件层。真实欠账 39 处（23 个文件），**只许降**。

- **无障碍几乎为零，先补关键路径**：全项目 `accessibilityLabel` 只有 2 处、`accessibilityHint` 0 处，而纯图标 `Image(systemName:)` 有 169 处 —— VoiceOver 用户听到的全是"按钮"。已给**每个页面都有的顶栏**（返回/首页/联机/下载/设置，5 处）与**主界面那排图标按钮**（4 处）补上中文标签；`topIcon` / `topButton` 增加 `label` 参数，只加修饰符不动布局。
- **新增 `_check-a11y.js` + `_a11y-baseline.json`**：统计"Button 里只有 Image 又没 accessibilityLabel"的数量（32 文件 / 78 处），**只许降不许升**。一次改完 169 处风险太高（无编译器、无真机），用基线把欠账显式钉住；改好一处就下调基线。注入验证：新增一个无标签图标按钮 → 报「HomeScreen.swift: 3 处（基线 2）」。

- **引导声明检查扩成全仓手势扫描**：原来只校验 CLAIMS 表里 5 条说法，现在再加一条——某个手势词只要出现在用户可见字符串里，整个 src 就必须有承接它的实现。过程里修正了自己两次：①证据正则太窄，把 `contextMenu`（iOS 长按菜单）与 `textSelection(.enabled)`（长按选中）排除在外，差点误报两处正确文案 ②第一版只扫引导/提示两个文件（等于没扫），改成全仓后又误报「双击」——命中来自 `ZLStrings.swift` 那个安卓文案整包（1536 条，多数没被引用），已排除。注入验证：加一句「双击标题可以重命名」→ 立刻报。
- 顺带核实：**15 处空状态全部带操作按钮**，且按钮标题都是具体动作（新建文件夹 / 从文件导入 .jar / 添加服务器 / 安装新游戏…），`ResourceManagerScreen` 的 `detail` 还写清了「把 zip 放进目录后点重新扫描」的完整路径。

- **首次引导教了一个不存在的操作**：主界面引导第 2 步写着「长按卡片提起它，拖动并让它停靠到另一侧」，而主界面唯一的长按是**头像转圈**（`HomeScreen.swift:262`），全文搜 `提起`/`停靠`/`dock` 只命中这句话本身。已改成指向真实存在的右上角那排按钮（文件管理 / 多人联机 / 版本下载 / 设置），并不挂 spot 高亮（位置估错会高亮到别处）。
- 新增 `_check-guide-claims.js`：一张「说法 → 代码证据」表，引导/提示里教的操作必须在代码里找得到实现（长按卡片提起、长按空白新建、预览、收藏柜、新建控件层…）。**已写明局限**：只覆盖表内条目。第一版检查被自己在注释里写的旧文案触发，已加"扫描前先剥注释"。

- **横向预算检查 v1→v3**：上轮只查 `HStack` 内联块，抓不到"宽度写在 computed property 里"的写法。中途试过 v2 解析属性宽度，实测 `.frame(maxWidth: .infinity)` 会让正则把 `.` 当数字、括号配对一旦被注释干扰就吃掉后面几百行——**不可信的检查比没有更糟**，弃用。v3 改用两条可预测判据：①同一 HStack 内联宽度之和 ≥288pt ②同文件同时有 `width: 92` 与 100–220pt 的 `maxWidth` 时按 `92+N+30 > 315` 报警。回归验证：临时把面板改回 210 → 精确报「332pt，只剩 7pt」，与手算一致。

- **新增 `_check-hstack-budget.js`（横向预算）**：原来的固定宽度检查只看单个 `.frame(width:)` 是否 ≥280pt，但"偏挤"是**同一行几个固定宽度相加**造成的——资源页 92（左栏）+210（筛选面板）+12+18 = 332pt，在 375pt 屏（可用 339pt）上只剩 7pt 给结果列表。新检查算每个 `HStack` 直接子层的宽度之和。**已如实写明局限**：只看 `HStack { }` 内联块，写在 computed property 里的宽度追不到（资源页那种挤压它抓不到）。
- **资源页筛选面板 `maxWidth: 210 → 180`**：按上面的账，结果列表从 7pt 恢复到约 37pt，仍紧但能看。彻底改需两列或收进 sheet，没有视觉反馈不做盲改，STATUS 第 5 条继续挂着。

- **原子写检查的 `'temp'` 子串匹配会漏报**：受控实验（同一注入、只改变量名）证明 `templateURL` / `attemptURL` 都被放过，而 `targetURL` 会报——因为判据是 `includes('temp')`。`TEMP_HINTS` 已从短通用词改成路径特征词（`temporaryDirectory` / `NSTemporaryDirectory` / `/tmp/` / `.tmp` / `trash` / `cachesDirectory`），`'stage'` 也去掉了（会被 `staging` 命中）。
- 收紧后立刻抓到真实问题：`VersionManageScreens.swift:604` 往临时 `stage/` 写 `pack-info.json` 没加原子选项（原来正被 `'stage'` 放过），而紧邻的第 600 行写 txt 时用了 `atomically: true` —— 同一处两种写法，已统一。

- **抽查旧检查，发现两条本身有问题**（用第103轮的"注入后回读确认"）：
  - `_check-atomic-writes.js` 的 `TEMP_HINTS` 里混着 `'probe'` —— 早期某次注入测试为了避开误报加的，结果让检查对任何名字含 probe 的真实代码视而不见。已移除。
  - `_check-destructive-confirm.js` 有两个盲区：①只查"按钮调用了本文件内定义的删除函数"，**内联删除**（按钮里直接 `removeItem`）不在范围 ②入口处 `if (deleters.size === 0) continue;` 让"只有内联删除"的文件被整个跳过。两处都补了。
- **编辑器的「删除控件」原来一点就删**（右键菜单，无确认、无撤销，而控件位置/大小/样式都是手工调的）。已加确认弹窗，并在说明里写清"删掉之后没有撤销"。其余 18 个破坏性按钮逐一看过：多数走确认弹窗，「删除到回收站」可恢复，服务器列表是左滑两步删除。

- **许可页与实际打包内容严重不符**：①列了 `MobileGlues`，但仓库里一个文件都没有（`CoreBridge` 注释还写着"iOS 上根本不存在的 MobileGlues"）②漏了 5 个随包分发的第三方署名：`AltKit/CAltKit`、`FreeType`、`shaderc`、`Gson`、`jsr305` ③只写「OpenJDK 17」，实际打包 17/21/25 三个运行时。已修正，组件数 15 → 20。
- 新增 `_check-license-page.js`：`Frameworks/`、`libs/*.jar`、`jre/` 里每个第三方都要在许可页有署名（MAP 表登记映射），反向也查"页面列了但没文件"。注入验证两条都过。对 GPL 衍生项目来说，署名缺失不报错但是实质合规问题——本项目第 69 轮已因 GPL 第 7 条栽过一次。

- **彩蛋里写着过时数字和一句不存在的功能**：`ZLSecretInfo` 说「这个启动器用了 55 个 Swift 文件」（实际 70，用户点 5 下版本号就看到）；`ZLEasterEgg` 说「键位盘可以长按空白处新建按钮」（编辑器没有这个手势，真实入口是顶栏「＋」菜单）。已分别改成不会变的描述与准确入口；顺带清掉 `ZLFestival` 里一个两个分支都 `return nil` 的空操作。
- 新增 `_check-hardcoded-stats.js`：**src 的字符串字面量不许出现「N 个 Swift 文件 / .m 文件 / jar」**——这类数字写在代码里，`_check-doc-stats` 管不到，也没有任何路径会校验，而用户会当成准确信息。注入验证会报。

- **澄清了预检的「该怎么办」在哪看**：`ZLDiagItem` 本来就有 `advice:` 字段（`/// 出问题时怎么办`），预检 9 条全写了，界面会把它们显示在红字**下方**。而清单只写「先按提示修」，没说提示长什么样 —— 已改成「每条红字下方还有一行灰字，照着那行做」。
  （顺带记一次自我纠错：我最初只扫 `value:` 行，误判"只描述不指引"，还往 value 里塞了 9 处「→」，已全部撤销。**先看结构，再谈缺失。**）
- 新增 `_check-error-hints.js`：`ZLPreflight` / `ZLDiagnostics` 里每条 `level: .fail` / `.warn` 的 `ZLDiagItem` 必须有非空 `advice:`。注入验证会报。

- **交付包加「从这里开始.md」**：11 个文件（含 93 MB 的 bundle 与源码 zip）此前没有任何一页说"该先看哪个"。新文件按收件人身份分四段（装来玩 / 接着开发 / 推上 GitHub / 每个文件是什么），并加 `_check-delivery-index.js` 双向校验：交付包每个文件都要被说明提到、说明提到的文件必须存在。注入验证两条都过。
- `_check-delivery-docs.js` 的副本映射加了这一份（否则判"孤本"）；`_check-doc-stats` 抓到 docs 30→31、脚本 67→68 两处数字变化并已同步。

- **_check-ci-contract.js 扩到六条**：新增「CI 打包引用的 `core/resources/*` 四个目录必须存在」（目录改名不报错，只让 IPA 缺 jar，启动时 `UnsatisfiedLinkError`）与「`project.yml` 里提到的 `*.sh` 必须找得到」。
- **修掉一处指向不存在脚本的注释**：`project.yml` 写着「版本号由 CI 用 `zl2-version.sh` 注入」，但该脚本不存在 —— CI 实际是「Inject version」那步的内联 sed。已改准确。
- 顺带核对全部通过：`Frameworks`/`libs`/`libs_caciocavallo`/`libs_caciocavallo17` 四个打包目录、`libs/launcher.jar`、`*.js`(2)、`log4j-rce-patch-*.xml`(2)、`jre/jre{17,21,25}-ios-aarch64.tar.xz` 与 CI 引用完全一致；`src/Info.plist` 不存在但正确（XcodeGen 按 `info: path:` 生成）。

- **新增 `_check-ci-contract.js`**：核对 `推送并取回IPA.ps1` 与 `.github/workflows/build.yml` 之间的隐含契约 —— ①脚本等待时间不得短于 CI 的 `timeout-minutes`（本轮从 30 提到 45，否则构建慢时脚本先判失败）②脚本必须认识 CI 上传的 artifact 名 `ZL2-build`（原来模糊匹配，可能抓错）③CI 必须真的产出 `.ipa` ④CI 有静态检查时脚本的失败提示要提到它。注入验证两条都过。
- 两套执行器都绿：`_run-all.ps1` 与 `run-checks.js --with-tests` 各 51 项。

- **50 项静态检查搬进 CI**：新增 `tools/config-guard/run-checks.js`（跨平台执行器，**清单直接读 `_run-all.ps1`**，避免两份漂移），CI 在**编译之前**跑一遍 —— 语法/契约错几秒现形，不必等 10 分钟构建。已按 CI 的方式在仓库副本里实测：50 项全绿。注意 `--with-tests` 才是 50 项，不带只跑 36 项 checks。

- **用 Siri / 快捷指令启动游戏可能毫无反应**：`RootView` 靠 `asyncAfter(0.8)` 之后发一条通知把首页叫醒，而首页收到通知时第一句就是 `guard !selectedVersion.isEmpty` —— 0.8 秒只是猜"版本列表已读完"，版本多或磁盘慢时列表还没出来就直接 return，**通知是一次性的，启动意图就此消失**。已改成带 2 分钟时效的持久标志（`markAutoLaunchPending` / `hasPendingAutoLaunch` / `consumeAutoLaunchPending`），首页在**收到通知**与**读完版本列表之后**两处都尝试启动。`_check-pending-action.js` 相应加了四条判据（含"至少两处调用"）。

- **Siri / 快捷指令跳转失灵，且未消费的路由会在下次冷启动突然跳页**：`consumeRoute()` 只在 `RootView` 的 `.task` 里调（首次出现才跑），App 已在运行中收到快捷指令时没人消费；而 `zl.pendingRoute` 又没有时效（`consumeLaunchFlag` 有 2 分钟过期、路由没有），于是过期的路由一直留着。已改：`ZLPendingAction.setRoute(_:)` 作唯一写入口（同时写时间戳）、`consumeRoute()` 加 2 分钟时效、`RootView` 抽出 `handlePendingAction()` 由 `.task` 与 `scenePhase == .active` 共用。新增 `_check-pending-action.js` 锁住这四处结构。
- 顺带核对（无问题）：`ZLSettingType` 的 7 种类型中，`stringList` / `long` / `parcelable` 没有专门的读取方法，但相关项要么在置灰名单里、要么由 `parsePoint` 读取；也没注册任何 URL scheme，深链接走的是 `ZLPendingAction` 而非 URL 回调。

- **编辑器吸附的两个设置项一直没有界面**：`editorSnapInAllLayers`（是否吸附到其它图层，默认关）与 `editorWidgetSnapMode`（全屏/小范围吸附）**行为代码早就在读**（`ControlEditor.applySnap`），却没有任何入口能改 —— 功能存在、永远停在默认值。已在顶栏「吸附」胶囊上挂菜单：全局开关 / 吸附范围 / 吸附模式（点按仍是会话内开关）。
- **`ControlEditor.readSettingBool` 也自带默认值那道门**：与第86轮 `GameOverlay.boolValue` 同一毛病（`default` 参数 + `UserDefaults == nil` 兜底），已删掉，默认值只认 `ZLSettings.defaultValue`。
- `_check-setting-defaults.js` 加固：纳入 `readSettingBool`，并要求这些 helper **体内不许出现 `UserDefaults`**（旧判据只要求"调用了 store"，在委托前加道门它看不出来）。
- 顺带核对：115 个设置项 = 6 个 group、设置页 4 个分页；17 项无设置页行，其中 5 项在游戏内菜单里，其余为内部状态位或由交互直接设置（如 `menuBallPos`）。

- **修正连续两轮的设置项统计错误**：`ZLUnsupportedSettings` 里有**四个**集合（`platformOnly` 57 / `notWired` 4 / `renderOnly` 14 / `launcherLook` 10），而第79、87轮的统计只解析了前两个，把已置灰的 24 项当成"可用"——"可用"数字因此虚高为 54、42，**真实一直是 30**。第87轮那次"归位 12 个假开关"实为把已在 `renderOnly` 里的键重复加进别的集合（还让说明文案走了错分支），**已全部撤销，重复归类归零**。
- 生成器与检查器都改成读四个集合，文档总览扩成四类并补两节明细；检查器新增守卫：源文件里出现未被脚本覆盖的 `Set<String>` 声明就直接报错（注入验证会红）。

- **12 个设置项「界面上能调、调了没用」**：排除定义文件与设置页后统计，这 12 项在代码里零引用，却既没置灰也没说明 —— `vulkanDriver` / `graphicsApi` / `sfpewPluginLayer` / `sfpewRelaxedContext` / `zinkPreferSystemDriver` / `vsyncInZink` / `dumpShaders` / `nativeLibPlugins` / `gameFullScreen`（→ 安卓专属置灰）、`sustainedPerformance` / `skipGameIntegrityCheck` / `logBufferFlushInterval`（→ 待接线置灰）。分类变为：**可用 42 / 安卓专属 66 / 待接线 7**。
- 新增 `_gen-settings-audit.js`：从代码重新生成 `docs/设置项审计.md`（第79轮起该文档由代码生成，但生成逻辑写在一次性命令里，改分类时没法复用）。

- **「显示 FPS」设置页显示「开」，游戏里却不显示**：`ZLSettings` 声明 `showFPS` 默认 `true`，而 `GameOverlay.boolValue` 自带一套默认值并多了一道「`UserDefaults` 里没写过就当 false」的门 —— 两处默认值打架，用户看到开关是开的、画面里没有 FPS。已删掉自带默认值，统一由 `ZLSettingsStore` 按 `def.defaultValue` 兜底。新增 `_check-setting-defaults.js` 锁住（不许出现 `defaultWhenUnset`；`boolValue/intValue/stringValue(_ key:)` 必须委托给 `store.xxx(`）。

- **根视图写死 `.preferredColorScheme(.light)`，把深色模式钉死了**：第84轮修了色板与系统同步，但这一行让 `RootView` 读到的 `colorScheme` 永远是 `.light`，同步逻辑永远得到 false —— 深色模式依然打不开。内层还有一句按 `darkMode` 反推配色的，与系统值互相拉扯，一并去掉。
- **清掉 11 个零使用类型（-477 行）**：`ZLKeycode.swift` 整个文件（101 个键码常量零引用，真正在用的是 `GLFWKeyNames.swift`）、协议 `MicrosoftAuthenticating` / `AuthlibAuthenticating`、`ShareBox` / `ShareSheet`、`ZLWaveShape`（第67轮删 `ZLWaveLine` 后的孤儿）、`ZLSideRail` / `ZLGlassCard` / `ZLQCard`、`ZLCrashAnalyzer`、`AuthlibCredentials`。
- **`ZLCuteGreeting` 没删，接上了**：「可爱彩蛋 3：按时间变化的问候」，启动屏现在显示「早上好 · 正在搬方块…」（彩蛋 4 早就用在那里）。
- 新增 `_check-dead-types.js`：顶层类型标识符在整个 src 只出现 1 次即报；**排除框架隐式实例化的类型**（`@main` App / `AppShortcutsProvider` / `NEPacketTunnelProvider` / `UIApplicationDelegate` / SceneDelegate）—— 差点把 App 入口当死代码删掉。

- **「深色模式」是死开关**：`ZLColorTheme` 所有取色访问器传的都是 `…Light` 键名，色板里 35 组 `…Dark` 数据完整存在却从没被用过（连 `primaryDark` 等四个深色访问器都是零调用），`ThemeManager.darkMode` 也只被赋值没人读 —— 开深色模式界面颜色一点不变。已改 `ZLPalette.color`：深色时把 `…Light` 换成 `…Dark`（缺键退回 Light），并用 `RootView` 把系统 `colorScheme` 同步给 ThemeManager（设置页那项写着"iOS 跟随系统外观"，现在才成立）。新增 `_check-dark-mode.js`。

- **推送做成一条命令**：`scripts/推送并取回IPA.ps1` —— 检查工作区干净 → 推 master→main → 轮询 Actions → 下载 .ipa → 校验体积（<100 MB 视为 JRE 没打进去，直接失败）→ 备份并替换交付包旧 IPA → 记 run 号。干跑验证了"不带 token 立刻拒"「工作区脏就停」两种保护。
- **推送手册里的数字改成现查**：原文写「4 个提交」「十三轮的改动」早已过时，改成 `git rev-list --count HEAD` / `git log origin/main..HEAD`；`.bundle` 体积也改成约数。
- `_check-delivery-docs.js` 现在认 `scripts/` 作为仓库来源，脚本入仓后不再是孤本。

- **损坏数据的备份现在能带出来了**：`ZLRecovery` 备份存进 plist 后用户根本看不到（等于没发生）。现在「打包日志分享」会自动把每份备份写成 `损坏数据备份/<键名>.raw` 一起打包，并附说明；朋友点一次按钮就能把损坏数据发给开发者。诊断项文案同步改成「打包日志时会一并带出」，朋友清单也补了这段说明（绿色=无异常备份，橙色=有数据读不出来但原始内容还在）。

- **解码失败会静默丢数据**：账号、服务器列表、控制布局外观、布局清单 4 处都是 `try? 解码` 失败即当作"没有数据"，用户随后一次保存就会覆盖掉那份解不开的数据——账号"突然全没了"、服务器列表变空、自己调的布局回到默认，且没有提示。新增 `src/ZLRecovery.swift`：失败先备份原始字节（`zl.recover.` 前缀），诊断页新增「数据备份」一项让它可见。新增 `_check-decode-recovery.js` 锁住这条规则。

- **远端文件名直接拼路径（目录穿越）**：`ModrinthAPI`（`file.filename`）、`MojangAPI`（`relativePath`）、`VersionInstaller` / `LoaderInstaller`（`artifact.path`、`versionID`）、`FileManagerScreen`（用户手输的新建/重命名）共 7 处把外部字符串直接 `appendingPathComponent`，含 `../` 时会写到目标目录之外。新增 `src/ZLPathSafety.swift`（`safeComponent` / `safeRelativePath` / `validateNewName`）统一处置：网络数据净化、不合法跳过或抛错；用户输入**报错而不静默改名**。新增 `_check-path-safety.js` 锁住这条规则。

- **设置项审计文档数字严重过时**：`docs/设置项审计.md` 写着「真正生效 13 项（11%）/ 待接线 14 项 / 安卓专属 60 项」，而代码实际是 **54 / 4 / 57** —— 把能力低估了约 4 倍（`showFPS`、`showMemory`、`controlLayout`、账号与游戏目录桥接、编辑器吸附三项后来都接上了，文档没回头改）。已按 `ZLUnsupportedSettings` 两个集合**重写整篇**，并同步 `设置项接线进度.md`（36 → 54）与文档索引。新增 `_check-settings-audit.js` 把这些数字变成契约。
- 顺带核实：115 个设置项里 112 个在 Swift 或核心代码中有引用；剩下 3 个（`terracottaNoticeVer` / `lastUpgradeCheck` / `lastSponsorReportMonth`）是从安卓搬来的内部状态位，**不在 UI 中显示**，无用户影响。

- **_check-dead-routes 增加一项输出**：对每个「已知死路由」，还会打印它的**目的地上挂了什么**（修饰符 `.xxx(...)` / 内部 `path.append` / `onOpen`）——因为挂在没人走的路由上的东西同样永远不生效。第78轮的实例就是 `.zlGuide(.controlEditor)`（控制编辑器首次引导）挂错在死路由上。

- **清掉 5 个冗余死路由**：`.gameDirs` / `.cleanFiles` / `.exportPackNew` / `.controlLayout` / `.logView` —— 页面都有别的 sheet 入口，路由本身是纯死 case。`AppRoute` 29 → **24 个 case**，死路由豁免 7 → **2 个**（只剩 room 未接入、terracotta 演示页）。
- **「控制编辑器首次引导」挂错地方**：`.zlGuide(.controlEditor)` 只挂在死路由 `.controlLayout` 的目的地上，所以引导从来没显示过；从真实入口（ControlManageScreen 的 sheet）进编辑器反而看不到。已挪到真实入口。

- **「装 Fabric/Quilt 加载器」这条流程本来就不通**：`path.append(.downloadAddons(...))` 的唯一入口在 `SelectGameVersionScreen` 的 `onPick` 闭包里，而那个页面本身没有任何导航入口 —— 死路由检查按"有没有引用"算，被死页面骗过去了。已删该页面，并在下载页每个版本行加扳手按钮 → `onOpenAddons(v.id)`，这条链现在通了。
- **搬运一个细节再删页面**：`SelectGameVersionScreen` 里的**愚人节版识别**（已知名单 + oneblock/potato/craftmine/shareware 后缀）已移植到 `DLVersion.isAprilFools`，下载列表会显示「愚人节版 🎭」。
- `AppRoute` 32 → **29 个 case**；删 239 行，净减约 200 行；文件数 70 → 69。

- **删掉两个被取代的死页面**：`ExportScreen`（154 行，被 `ExportPackScreen` 取代）、`CrashLogScreen`（94 行，功能已被 `LogViewScreen` 覆盖），连同 `AppRoute` 的 `.exportPack` / `.crashLog` 两个 case 与目的地分支。路由 32 → 30。
- **「按项目 ID 搜索」接上入口**：`SearchIDScreen`（132 行，按 Modrinth/CurseForge 项目 ID 搜索）一直存在但无入口，现于下载页搜索框旁新增「#」按钮进入。
- 剩余 8 个已知死路由（5 个页面另有入口、3 个未接入）登记在 `_check-dead-routes.js` 的 ALLOW 中。

- **服务器列表页一直打不开，而界面上显示的是写死的假服务器**：`ServerListScreen`（带真实 Server List Ping）7 个不可达页面之一，用户点不到；`VersionContentScreen` 里那个「服务器列表」是硬编码的 Hypixel / 2b2t / 本地局域网（地址都是编的），行末 chevron 没有 Button，而「添加服务器」弹窗说"去多人游戏页管理"——那一页是联机页，没有服务器管理。已改为读 `ServerStore` 真实数据 + 点进去就是真实页面。
- 新增 `_check-dead-routes.js`：`AppRoute` 的每个 case 必须有导航调用（append / onOpen / NavigationLink），已知 11 个死路由登记理由。
- STATUS 已知问题段重排为 7 条（原来有两个 `4.`），新增「7 个页面用户点不到」。

- **控制编辑器里 4 类外观设置进游戏不生效**：核心只从布局 JSON 读 `bgColor` / `cornerRadius` / `opacity` / `strokeColor` / `strokeWidth`，而 `textSize`（核心按控件大小自动缩放）、`joystickColor`、`joystickSize`、`pressedBgColor`（核心无"按下态外观"概念）**全核心零命中**。编辑器里这些都有滑杆、预览还能看到变化，用户调完进游戏发现没变。已在外观面板顶部与不透明度区加如实说明；新增 `_check-layout-keys.js`（导出键必须能在核心源码里找到，例外登记理由）。

- **删掉 230 行完全没用的重复色板**：`src/ZLPalette.swift` 里的 `ZLThemeType` / `ZLPaletteV2` / `ZLPaletteLight` / `ZLPaletteDark` 全项目零引用，却存了**第二份 490 个颜色值**（真正在用的是 `ColorThemes.swift` 的 `ZLPalette.raw`）。同一份数据两处各存一遍，改了 A 不改 B 就会静默分叉；而且 `ZLThemeType` 有 8 个主题（多一个"动态"）与在用的 7 个不一致，容易误以为有 8 套。已删除，文件数 71 → 70。
- 顺带核实：README 的「490 色值（35 角色 × 7 主题 × 亮暗）」**数字准确**——`ZLPalette.raw` 正是 70 项 × 7 = 490。

- **三份安装文档给出三套互相不提的路线**：README 推荐「NB 全能助手（中文，推荐）」，而那两份分别给 TrollStore / SideStore / Sideloadly 三条，**完全不提 NB 全能助手**。已把 README 统一成三条路线表并指向 `安装教程-超详细`；新增 `_check-install-docs.js`（三份都必须提 JIT 与 StikDebug；只在一份出现的"孤例工具"会被报出来）。
- 顺带核实（待查清单另两项，均正确）：游戏内菜单确实是 `HStack` 左右双栏；`writePerfOptionsIfNeeded` 有 `fileExists` 守卫，**只在 options.txt 不存在时写**，不会覆盖用户改过的设置。两个 StikDebug 地址（官网 / GitHub）都返回 200，均有效。

- **README 的性能声明有一处错**：「内存按物理内存 1/3 自适应」——实际是**默认 25%**（`PLPreferences.m:64` 的 `* 0.25`）、**手动上限 50%**（`CoreBridge` 的 `ramMB / 2`），三个数字互不相同。已改正；「关粒子阴影」也改成「粒子最少」（`particles:2` 是 minimal 不是 off）。
- 新增 `_check-readme-claims.js`：把 README 里能机器验证的声明（内存比例 / 视距 / 粒子 / GC 参数 / 支持版本区间）写成断言，改代码没改文档或反之都会红。
- 同批核对了三条**准确**的声明：7 套主题（`ZLColorTheme` 正好 7 个 case）、局域网发现（确实是 BSD socket + `IP_ADD_MEMBERSHIP` 加入 `224.0.2.60:4445`）、G1GC + `MaxGCPauseMillis=20`。

- **README 声称支持「1.8 ~ 26+」，但 1.11 及更早需要 Java 8**：`jre/` 只有 17/21/25，`CoreBridge.requiredJavaVersion` 对 ≤1.11 明确返回 8（注释也写着"包里没有 → 明确报错"），所以这批版本装了也起不来，而下载页照样列出且按钮可点。已修：下载页给这类版本加「需 Java 8 · 不支持」标记并**禁用下载**（新增 `CoreBridge.needsUnbundledJava8(_:)`）；README 改成「1.12 ~ 26+」；STATUS 硬限制补一行。

- **界面把 App 自称「ZL2」，违反项目自己声明的 GPLv3 第 7 条**：README 写着「本项目**不以** `ZalithLauncher` 或其缩写 `ZL` 作为名称」，而 8 处界面文字自称 ZL2（欢迎页标题、主界面引导、文件管理空状态、两处 JIT 提示、诊断报告标题、EasyTier 联机名、版本信息默认值）。全部改成 CraftLauncher；新增 `_check-trademark-strings.js`，例外（Bonjour 服务名 / 上游署名 / 发布资产名 / 格式名）逐条登记理由。

- **首页右侧面板写死 340pt 宽，窄手机上必然溢出**：iPhone 320pt 屏可用宽度只有 284pt（减去两侧 18pt 内边距），而面板是右对齐，溢出时裁掉的是**左侧标签文字**。已把 6 处自适应容器里的固定宽度改成 `maxWidth`（首页 340 / 联机卡 260 / 联机页右栏 300 / 控制管理 300 / 游戏目录 258 / 资源筛选栏 210）——宽屏保持原样、窄屏自动收缩。新增 `_check-fixed-widths.js`（阈值 280pt，只查必然溢出）。
- **已知限制（未盲改）**：「下载-模组/资源」和「游戏目录」是**三列布局**，在 375pt 手机上中间栏会偏窄。真要在手机上舒服用需改成两列或把筛选收进 sheet，属布局重设计——没有视觉反馈可验证，已如实记入 STATUS 已知问题第 4 条。

- **【新增】接上两个彩蛋特效**：`ZLStarBurst`（点空白处冒小星星）和 `ZLHeartPop`（点头像冒爱心）早就写好了动画，但**从没被任何界面引用**——彩蛋只有一句文字。现在：背景改成 `SpatialTapGesture` 取坐标后在点击处冒星星；头像加短按冒爱心（与长按转圈共存）。
- **清理三个"写了没挂载"的 View**：`ZLWaveLine`（空状态波浪线，没人用）、`ZLToastView`（注释承诺了并不存在的 `.zlToast` 修饰符）、`ZLQNumber`（与 `ZLPercentText` 重复）；`ZLPercentText` 接进了下载页进度显示（等宽数字，百分比跳动不再抖）。
- 新增 `_check-orphan-views.js`：`struct X: View` 只出现 1 次即报"写了没挂载"。

- **【新增】回收站占用可见**：`.trash/` 原来是个隐藏目录、无保留策略、界面不显示占用 —— 用户删了几个 G 的模组会发现空间没释放，以为删除失败。现在菜单项直接显示「清空回收站（占用 1.2 GB）」，确认弹窗也写明占用；进页面 / 删除 / 清空后都会刷新。**不自动清理**（自动删用户数据违反"不可恢复动作必须确认"）。

- **9 处写持久化文件没用原子写**：`versions/<id>/<id>.json`、`launcher_profiles.json`、`controlmap/<布局>.json`、下载的 jar 等，写到一半被杀（iOS 后台回收 / 强杀 / 崩溃）会留下**截断文件**且不能自愈。已全部加 `options: .atomic`。
- **布局覆盖会静默丢失用户的手工调整**：`CoreLayoutExport.export` 只做原子写，`.atomic` 保证不写半个文件但**不保证旧内容不丢**。已改为「内容真的不同才备份」到 `controlmap/.backup/<同名>`。
- 新增 `_check-atomic-writes.js` 守住这条（临时/暂存目录除外）。

- **「清空回收站」没有二次确认**：`Button("清空回收站", role: .destructive) { emptyTrash() }` 在溢出菜单里，点一下就把回收站**永久**清空。回收站的意义就是「删错了能捞回来」，一步误触把这层保险毁掉且不可恢复。已改为 `confirmationDialog` 二次确认（其余 4 处删除本来就有确认）。新增 `_check-destructive-confirm.js`：`role: .destructive` 的按钮不得直接调用执行 `removeItem` 的函数。

- **新增「重复声明」静态检查**（`_check-duplicates.js`）：顶层类型重名会报 `Invalid redeclaration`，而前四层检查都发现不了。判据按花括号深度**只查顶层**——`CodingKeys`、`GuideManager.Kind` / `ZLSettingRow.Kind` 这类嵌套同名不会误报（当前 348 个顶层类型全部唯一）。

> 编译前置静态检查现在有五层：**括号配对** → **框架导入** → **标识符拼写** → **参数标签** → **重复声明**。

- **新增「参数标签」静态检查**（`_check-call-labels.js`）：调工程内类型的方法时，实参标签必须与声明一致。这是我自己犯过两次的错（`requiredJavaVersion(for:)` 标签不存在、`String.Replace` 传三参），而括号检查和导入检查都抓不到。当前 88 个方法声明 / 78 个调用点全部对得上。

> 编译前置静态检查现在有四层：**括号配对**（swift-lint）→ **框架导入**（_check-imports）→ **标识符拼写**（_check-interpolation）→ **参数标签**（_check-call-labels）。挡不住的只剩类型系统与泛型约束。

- **`VersionIconPicker` 缺 `import UIKit`**：用了 `UIImage` 但只导入 SwiftUI + PhotosUI（后者通常会把 UIKit 带进来，但"通常"不算保证）。已补；并新增 `_check-imports.js` 按符号→框架映射检查导入缺失（UIKit / CryptoKit / Compression / PhotosUI / AVFoundation）——没有本地编译器时，这是最划算的"编译前置"防线。

- **服务器 MOTD 显示空白**：`description` 有纯字符串 / `{text}` / `{text, extra}` 三种形态，原来只取 `text`，而带彩色分段的服务器（最常见那种）会解析成空字符串，看起来像服务器没返回信息。已加 `flattenChat` 递归展开，配 `_test-motd.js` 11 条。
- **不查 SRV 记录（能力边界，已如实标注）**：靠 `_minecraft._tcp` SRV 指向端口的服务器，只填域名会连不上。取 SRV 需 C 层 DNS 交互，本地无编译器验证，**不冒引入编译失败的风险**；改为在「编辑服务器」表单底部说明「请向服主问真实地址和端口，按 `IP:端口` 填写」。

- **微软登录会把 `slow_down` 当成 `authorization_pending`**：轮询间隔是常量，而 RFC 8628 要求收到 `slow_down` 时把间隔增加 5 秒。后果是服务端持续限速、客户端一直按原节奏打，deadline 耗尽后抛「登录过期」——用户在手机上明明点完了授权却失败。已改成可变间隔 + `slow_down` 加 5 秒 + 未知错误也记日志。配套 `_test-msauth-poll.js` 7 条契约测试。

- **两份文档只在交付包、不在仓库**：`给朋友的安装指南.md` 和 `推送操作手册.md` 一直游离在版本控制之外，里面还写着「确认大小是 132 MB」（build-235 的数字，下次构建就失真）。已纳入 `docs/`，并把精确大小改成抗漂移判据「**小于 100 MB 说明 JRE 没打进去**」。新增 `_check-delivery-docs.js` 保证交付包文档不许成"孤本"、副本不许漏同步。

- **文档里的 `.m` 数量也过时了**：README/STATUS 写「核心侧 67 个 `.m`」，实际 69。`_check-doc-stats.js` 已扩到同时校验 Swift 文件数 / 核心 `.m` 数 / jar 数三种规模数字；体积与行数仍不校验（约数/假精度）。

- **文档里的规模数字常年过时**：README / STATUS 写着「70 个 Swift」，实际已 71（加 `ZLPreflight.swift` 之后没人同步）。已修正，并新增 `_check-doc-stats.js` 自动校验。同时**删掉了精确行数**——两个工具算出来差 1400 行（文件混用 CRLF/LF），而且精确行数改一行代码就变，属于假精度。

- **验证清单有一行失效指引**：清单教朋友搜 `找不到内置 JRE`，而代码里根本没有这句话——真实的失败信息是 `CoreBridge.swift:295` 抛出的「这个版本需要 Java N，但包里只有：…」，且显示在**启动失败那一屏**、不写进 `ame.log`。文案和位置都错了。已改正，并新增 `_check-checklist-logs.js` 锁住「清单里让用户搜的每一句都必须在代码里存在」。

- **导出布局的 `scaledAt` 恒为 100**：`CoreLayoutExport.currentButtonScale()` 从 UserDefaults 读 `control.button_scale`，但这个键是**核心侧**设置（用户在游戏内控制编辑里调，存在 PLPreferences，默认 100），UserDefaults 里从来没有它 → 永远返回 100。用户调过按钮缩放时，导出的布局与实际比例不一致。已改为 `getPrefFloat("control.button_scale")`。这条是 `_audit-stores.js` 新增的「反方向检查」抓出来的（读了一个核心拥有、但从没写进 UserDefaults 的键）。

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
