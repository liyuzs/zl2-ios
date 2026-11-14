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

- **给"用户到不了的联机界面"留了一条提示**。`MultiplayerRoomScreen`（「陶瓦联机」，93 行）实现了、`AppRoute.room` 存在、`ZL2App` 也接了 `case .room:`，但**全项目没有任何地方 `path.append(.room)`** → 用户永远到不了；它依赖的 EasyTier 隧道还需要 Network Extension（本项目没做）。已在界面顶部加警示：「这个功能还没做完 —— 隧道组件需要 Network Extension，当前版本里连不通」。**这条提示是给它"将来被接上入口"那天准备的** —— 那时用户会真的走进来，而如果底下不通，他会看到一个"能点但连不上"的界面，**比空白更糟**。
- **顺带验证（都干净）**：设置页引用 **180 个 `ZLStrings` 键全部有定义** ✓ · 置灰项有完整说明（区分 `platformOnly` / `notWired` 两类原因）✓ · 朋友的完整路径每一步都有反馈 ✓

- **试了"魔法数字重复"检查，评估后放弃**。想法：同一个 ≥10 的整数字面量在同一文件出现 ≥2 次 → 建议提取常量（承第187轮那个写了三遍的 `40`）。结果：分母 2639 处、报出 **453 组**，真问题只有 **1 个**，误报率 17%。**根因：文本相同 ≠ 语义相同** —— `font(size: 12)` 出现 26 次是"26 个独立的设计选择碰巧都是 12"，而 `prefix(40)`/`> 40`/「前 40 个」是"同一个东西说了三遍"，**正则分不出这两种**。降误报只能堆"字号/间距/圆角"白名单（无穷的知识）→ **这是"做不到"不是"还没做"**。
- **处理**：脚本已删，**放弃理由写进了 `_check-code-hardcoded-counts.js` 的局限段**（相邻主题：都管"数字会腐烂"），防止将来重试。

- **代码文案里也有写死的数量**：`DownloadScreen` 的「下面是内置的 **7 个**常用版本」—— 第180轮那条"会变的数量不手写"当时只做了**文档**检查，代码漏了。已改成 `\(versions.count)`。
- **顺带发现一处魔法数字重复 3 次**：`AssetInfoScreen` 里 `prefix(40)` / `> 40` / 文案「前 40 个」—— 改一处忘另外两处就会出现"列表显示 30 条但提示说 40"。已提取 `private static let maxVersionRows = 40`。
- **新增 `_check-code-hardcoded-counts.js`**：代码文案里「数字 + 量词」且不是插值 → 报。**判据第一版漏了一处**（整串含 `\(e)` 就被跳过，但那个 7 是写死的）→ 改成**先把插值挖掉再查字面量部分**。三向注入验证（含"半插值半硬编码"）都通过。
- **顺带**：全检查的分母审计做完了，**所有检查都有真实分母** ✓。`_check-script-inventory` 又抓到我写死 `D:\ios-zl2`——**这是第 3 次**（183/184/185 各一次），已改用 `_paths`。

- **两个检查的分母是"扫了几个文件"，不是"查了几个对象"**：`_check-dead-types` 和 `_check-dup-decl` 都只报「扫了 68 个文件」—— 那是**输入规模**。如果判据失效（一个类型都没识别），它们仍会输出"68 个文件、0 处问题"，**看起来完全正常**。已补粗数：「粗数顶层类型 **305** 个（不含 extension / @MainActor；判据识别的个数应与它接近）」。
- **顺带做了一次分母对账**：`_check-state-written` 报 344 个 @State，独立粗数 358 —— **差异有解释**（14 个是 `@StateObject` + 注释里的 @State）→ 判据准确 ✓。`_check-empty-button` 241 也对得上。
- **305 的校准过程**：struct 190 + class 22 + enum 93 + actor 17 = 322，但 **17 个 actor 全是 `@MainActor` 误匹配** → 真实 305。

- **新增 `_check-dup-switch-case.js`：同一个 `switch` 内重复 `case`** → 编译错误（case is already handled）。第三类编译检查（前两类：同类型 var/let 重名、enum 内重复 case）。分母 **328 处 `.name` / 83 个 switch → 0 处重复** ✓
- **判据第一版失效了**：v1 从 `switch` 往下用"缩进 + 花括号"找 case，111 个 switch 只匹配到 **5 处**；而全项目实际有 **336 处 `case .x`** —— **分母差两个数量级**（"结果数量级异常先怀疑判据"的又一次应验）。v2 改成**从 `case` 往上找最近的 `switch`**（第162轮 `_check-silent-default` 验证过的方向），现在 328 处、覆盖 98%。
- **局限**：`case .a where cond:` 与 `case .a:` 在 Swift 里是合法的（where 让它们不重叠）→ 本检查会报，需人工确认。

- **新增 `_check-dup-case.js`：enum 内重复 `case`** → 编译错误。补上 `_check-dup-decl.js` 没覆盖的 `case`（它只查 var/let）。分母 **147 个 enum / 483 个 case → 0 处** ✓
- **评估后放弃：`switch` 里 `case .typo` 拼错检查**。做了两版：单文件枚举池误报 **47/291（16%）**（枚举在别的文件）；全局池降到 **17/346（5%）**，但剩下全是 **`URLError.Code`**（`.timedOut`/`.notConnectedToInternet`…）—— 系统枚举，编译器会查、不可能拼错。**真问题 0、误报 17**，要继续只能堆 20 个名字的系统枚举白名单（白名单是"知识"，每加一个新枚举就要维护）。按"分母决定做不做"+"不做检查也是判断力"**放弃**，脚本已删，理由记在 CHANGELOG。

- **发现一个编译阻断**：`HomeScreen.swift` 里有**两个同名 `private var hasInstalledVersion`**（L431 靠显示文案 `hasPrefix("还没有")` 判断的旧版 —— `3b454c8` 加的；L478 用 `listVersions().isEmpty` 的新版 —— `054d6f8`「新手引导」那轮加的）。**Swift 会报 `invalid redeclaration`，编译不过**。两处不同轮次加的，谁都没发现重名；`swift-lint` 只查括号配对照样通过。**这意味着 build-235（11/8）之后加的东西很可能一直编译不过。** 已删掉文案驱动那个、保留真实数据那个，并把 `attemptAutoLaunch` 的 `hasPrefix("还没有")` 一并改成 `hasInstalledVersion`。
- **新增 `_check-dup-decl.js`**：同一类型内重复声明 `var`/`let` → 报。**判据修正三次**：①把函数体内的局部变量也算进了类型 → 限定"缩进 = 类型缩进 + 4" ②弹栈用"行首是 `}`"导致 `body` 的结尾 `}` 把 struct 弹掉、**判据完全空转** → 改成按缩进弹 ③**`func` 允许重载** → 只查 `var`/`let`。
- **顺带**：`_check-script-inventory` 抓到新脚本里写死了 `D:\ios-zl2` → 已改用 `require('./_paths')`。

- **又两个"永远匹配不上"的错误判据**：第181轮修了 `contains("JIT")`，这轮把剩下的逐个核实 —— `contains("返回错误码")/contains("launchJVM")` **有效**（`launchReturned` 的文案就是「launchJVM 返回错误码 N」），但 **`contains("JRE")` 基本失效**（`bootstrapFailed` 的 5 个实参里**一个都不含 "JRE"**，都是"这个版本需要 **Java** 21，但包里只有…"）· **`contains("内存")` 当前不触发**。已把 `JRE` 改成 `Java`；`内存` 那条保留并加注释（将来出现 OOM 错误时能接住）。
- **没做检查**：这 3 处已人工核实，按"先数分母"（分母只有 3）不单开一条 —— `_check-error-locale` 管的是"翻译优先按错误码"，管不了"实参里有没有那个词"。

- **JIT 没开只写日志，用户看不到**：`CoreBridge` 里 `if let jitNote = jitStatusNote() { NSLog(...) }` —— 而 JIT 没开的表现**不是崩溃，是"卡成个位数帧率"**，用户只会觉得"这 App 很卡"。`LaunchScreen` 里那个 JIT 分支判的是 `e.contains("JIT")`，而 `e` 是**翻译后的中文** → **永远进不来**（第145轮那条的又一次违反）。**修法**：①启动前预检加第 8 项 JIT（`warn` 不是 `fail`）②`e.contains("JIT")` 改成 `jitStatusNote() != nil` ③去掉两处"七项"（加项就过时）。
- 顺带印证第180轮那条「会变的数量不手写」：`"七项前置条件全部就位"` 在加第 8 项的那一刻就过时了。

- **脚本清单写着"43 个脚本，但该跑的只有 51 个"** —— 第 47 轮的数字、133 轮没改，而且**自相矛盾**（43 < 51）。实际 107 个脚本。同类的还有 `从这里开始.md` 的「72 个自检脚本」（实际 61/106）和 `交接文档` 的「50 项检查」（实际 84）。三处一律**改成不写数量**。
- **新增 `_check-doc-hardcoded-counts.js`**：只查**承诺性**的会变数量（「N 项检查」「N 个自检脚本」「N 条已知问题」）。**不查**源码规模统计（"115 个设置项"）、历史记录（"补过 20 处差异"）、具体事实（"1 个路由"）、体积（"约 93 MB"）—— 第一版判据误报了后三种，已收窄。
- **我自己的一次事故**：补丁脚本里 `lines.splice(start, count, ...replacement)` 而 `replacement` 是**字符串**（上一行多写了 `.join(nl)`）→ `...` 展开成逐个字符 → **`README-脚本清单.md` 被拆成一行一个字**。发现方式是输出写着"已改（**261 行**）"而 replacement 只有 6 个元素。已 `git checkout --` 恢复并用 `edit` 重做。**教训：`...` 展开字符串是合法的，不报错，只是结果荒谬。**

- **修：备份写失败也往下走，旧布局被覆盖且不可恢复**。`CoreLayoutExport` 里 `try? existing.write(to: backupDir...)` —— 备份没写成也照样继续，紧接着覆盖原文件，**而用户以为"有备份"**。改成 `do/catch` + 日志（「旧布局即将被覆盖，无法恢复」）。
- **修：写库文件失败时 `failedLibs` 不知道**。`LoaderInstaller` 的 `try? d.write(to: dest)` 失败 → 文件不存在，但 `failedLibs` 只记"下载失败"不记"写失败"，后面报"缺库"时列表是空的 → 误导排查。改成失败时 append「（写盘失败）」。
- **修：options.txt 写失败无痕迹**（最低危，只影响性能配置生效）→ 加日志。
- **怎么找到的**：`try?` 有 210 个（大分母）→ 77 个副作用 → 13 个写 → 10 个结果没被检查。**剩下 7 个在诊断打包路径里**（zip 缺文件用户能看出来），评估后不逐个改、也不单开检查。

- **新增 `_check-empty-button.js`：按钮的 action 不许为空**。分母一路缩小：`Button` 出现 **695** 次 → 排除 `Button(action:)`（那种写法里 `{}` 是 **label**）→ **270** → 排除 `role: .cancel`（**alert 里空 action 是标准写法**）→ **241** → 空 action **0 个** ✓。
- **判据第一版误报 11 个**：全是 `Button("取消", role: .cancel) { }` —— SwiftUI alert 的标准写法，关闭由系统处理，一个都不是 bug。排除 `role: .cancel`（往后看 2 行覆盖多行签名）后归零。
- **顺带做了"检查的检查"**：用上一轮那条"定义和使用在文本上长得一样"复查已有检查——扫了 60 个脚本里 9 处赋值类 pattern，7 处本来就该找定义、1 处是刚修的、`_check-dark-mode` 的定义在另一个文件不冲突。**干净**。

- **新增 `_check-state-written.js`：`@State` 必须有写入路径**（分母 **343 个**）。赋值 / `$binding` / `+=` / `.toggle()` / `name[i] =` 都算；只有读 → 那个状态永远停在初值，而 `@State` 的意义是"会变、变了要重绘"。实测 **0 处问题**。
- **判据失效两次（都是注入验证抓出来的）**：①**声明行的 `= 初值` 被当成了写入**（`@State var x = 42` 那行的 `= 42` 是初值，不排除的话每个 @State 都"看起来被写过"，判据完全失效）；②**表达式初值被误报**（`= ZLLoadingTips.random` 每次视图重建都会重新求值，"从不被写入"是设计）。修法：剔除声明行 + 只报字面量初值。
- **三向注入最终都正确**：只读+字面量 → 报 · 只读+表达式 → 不报 · 有写入 → 不报。

- **新增 `_check-error-exhaustive.js`：`errorDescription` 的 switch 不许有 `default:`**。枚举 switch 加 default 会**关掉编译器的穷尽检查**，将来新增的错误 case 会静默显示成兜底文案。实测 **12 个全部穷尽** ✓；注入验证能精确报出。
- **评估后不做的检查**：「重要操作里只记日志、没有 UI 反馈」的 catch。先核了分母 —— 全项目 84 个 catch，其中在"重要操作"函数里的只有 **9 个**，6 个有 UI 反馈、**0 个只有日志**，剩 3 个是第149轮已知的空 catch。**分母太小且已干净，不单开一条**（不含羞于"不做检查也是判断力"）。

- **换行符事故（记录一下，含两次误判）**：`AccountService.swift` 在 a66d8e2 里显示 554/545 行变更，但 `git diff -w` 只有 **13 增 4 删** —— 差异是换行符造成的噪音。过程：①我写的补丁脚本里 `const J = arr => arr.join(crlf ? '\r\n' : '\r\n')` 三元两边一样；②我误以为"同类文件都是 LF"就把它转成了 LF；③查了 `HEAD~1` 才发现**它原本就是 CRLF**（这个仓库是混合换行符），于是转回去，`git status` 恢复干净。**教训：改换行符前必须查那个文件自己的历史版本，不能按"同类文件应该一样"去推断。**

- **错误 case 有没有真的被抛出**：把第174轮那条推广到全部 **12 个错误枚举、58 个 case**，查出 6 个"定义了但从不被创建"。**删 2 个**（`ZLLoaderInstallerError.mergeFailed` —— "合并"走的是系统错误；`libraryFailed` —— 库下载失败走 `failedLibs` 收集，**文案「下载加载器库失败」会骗人**）· **删 1 个重复**（`MSAuthError.slowDown` 与 `.rateLimited` 语义重复）· **标注 4 组**（`unsupportedAccountType` / `storageFailure` / 4 个 Xbox case —— 文案备好但没解析 Xbox 错误码 / `missingAccessToken`）。
- **修一个真静默失败**：`AccountService.persist()` 原来 `if let data = try? encoder.encode(accounts)` —— **编码失败被吞掉**，账号存不进去而用户以为存上了，下次打开就没了。改成 `do/catch` + `NSLog`。
- **新增 `_check-error-case-created.js`**：每个 case 必须有创建点（`throw` / `= Type.c` / `return .c` / 三元）；**只被 `case .c:` 匹配 = 消费，不算创建**；行尾有"未实现"标注的豁免。
- **判据失效两次（都靠注入验证抓到）**：① `[:,(]\s*\.c` 把 `case .c:` 模式匹配当成创建 → 删掉；② 豁免查"前后 6 行"导致相邻 case 标注互相覆盖 → 改成只查本行。
- **顺手修 `_check-atomic-writes` 的老毛病**：注释里的 `out.write(to:)` 被当真代码报错——**第三次"注释被当成代码"**（第143/150轮）。已按"剥注释是默认动作"修掉（22 → 21 处）。

- **微软登录的 403 只给一个数字**：`MicrosoftAuth` 原来对 401/403 一律抛 `.invalidResponse("\(statusCode)")` → 用户看到「响应异常：403」不知所措。而 `MSAuthError` 里明明有 `.expired`（设备码过期，重新获取）· `.ipBlocked`（当前 IP 被禁止登录）· `.rateLimited`（登录过于频繁）三个更合适的 case **没人用**；**429 甚至根本没被拦**，会掉到「非 JSON 响应」。已改成按状态码分别抛对应 case。对照 `ZLUpdate` 的 403 一直是说人话的——**同一个项目里同样的错误码，一个说人话一个甩数字**。
- **顺带**：`真机验证清单` 的验收判据从「只显示「服务器返回 403」」改成「只甩一个数字或英文而没有"怎么办"」——判据要写成**真会出现的样子**，否则朋友照着找找不到。另核实 `docs/真机验证清单.md` 已标"已废弃"并指向新版 ✓。

- **安装指南还写着"仅横屏"**：第165轮把 iPhone 改成允许竖屏，但 `给朋友的安装指南.md` 的属性表没跟着改（`| 方向 | 仅横屏 |`）——**这是我自己的遗留**，正印证"描述和实物各自演化，没人对照"。已改成「**iPhone 竖屏**（启动器）/ iPad 横屏 / 游戏内横屏」；版本号也从 `0.1.0 (build 6.0)` 改成「源码是 **1.0.0 (build 1)**；包里的 ZL2.ipa 是旧包 build-235，装上去会显示 0.1.0」；顶部加旧包警告。
- **新增 `_check-doc-config-sync.js`**：关键认识——`_check-delivery-docs` **只查"副本与仓库同步"，不管内容对不对**，所以"配置改了文档没改"它永远抓不到。新检查把文档属性表的值揪出来跟 `project.yml` 比对：最低系统 ↔ `deploymentTarget` · 包名 ↔ `PRODUCT_BUNDLE_IDENTIFIER` · 方向 ↔ 有没有 `Portrait`。三向注入验证都精确报出。**版本号故意不查**（有两层含义，不能简单比对）。

- **交付包的 IPA 是 6 天前的旧包，文档却说"这就是 App 本体"**：`ZL2.ipa` 是 11/8 的 build-235，源码是 11/14，而 `从这里开始.md` 第 2 步没有任何警告 → 朋友会以为装着的是最新代码。已加「⚠️ **这是 build-235 的旧包**……要最新版请跑一次 `推送并取回IPA.ps1` 重新构建，**别当成最终版本**」；文件数 11 → 12。
- **新增判据（`_check-delivery-docs`）**：IPA 比源码 zip 旧超过 1 天时，`从这里开始.md` 里必须有 `build-数字` 的警告，否则报错。
- **过程中判据失效了一次**：第一版正则 `/旧包|build-\d+|重新构建|…/` 因为文档 L48 别处写着「不覆盖**旧包**」而误判通过；改成只认最独特的 `build-\d+` 后注入验证才精确报出。**教训：正则里用 `|` 时，任何宽泛分支都会让整个判据失效。**
- 顺带审计（干净）：**开发者语言泄漏**（58 个用户页面）12 处全部合理 · **错误提示上下文**大部分天然有 · 诊断页已有"复制报告"+"打包日志"。

- **三条预检建议是"只有开发者能执行"的**：`资源索引` 只说后果（没贴图没声音）没说怎么办 · `Java 运行时` 和 `渲染器` 都写"需要重新构建打包"——**那是开发者的动作，用的人做不到**。已改成：资源索引补「重装这个版本可以补上」；Java/渲染器改成「**不是你操作能修的 —— 联系给你这个 App 的人要新包**」（保留技术细节，但先说清用户能做什么）。
- **顺带判断（不做检查）**：「固定文案 + lineLimit 是否够装」这条候选只有 **1 个**（`"正在登录皮肤站…"` + `lineLimit(2)`，8 字符绰绰有余）→ 永远绿、不产生信息，**不做**（第127轮那条"不做检查也是判断力"）。

- **Fabric 装完也不说下一步**：`ZLTaskCenter` 的完成文案是「已安装 X（N 个库）」，而用户**还停在 Fabric 页**（那页只有 `onBack`，不会自动回首页）→ 不知道该回去启动。改成「已安装 X（N 库）· **回首页启动就是 Fabric 版**」。
- **修我自己第149轮留下的文案截断**：`TaskCenter:209` 的 `Text(t.detail)` 有 **`lineLimit(2)`**（约 40-50 字符），而第149轮写的失败文案约 **70 字符** → **早就被截断了**。压到「X 有 N 个库失败（…）· 可能起不来，重装试试」（45 字符），保留最有用的信息（缺几个 + 哪两个库）。**这是第三次"加文案不看容器"**（165 轮 HomeScreen、169 轮 installMsg、本轮）。

- **装完版本后没人告诉他下一步**：`installMsg` 只说"安装完成"，而首页的三步引导（下载版本 → 选 Fabric → 启动）**只在零版本时显示** —— 装完第 1 步卡片就消失，后两步指引跟着没了。已在安装完成后加一条独立成行的引导：**「接下来：回首页点「启动游戏」就能玩原版。想加模组 / 光影的话，在这个版本上再装一个 Fabric 加载器。」**（`showInstallNextStep` 三态：开始 false / 成功 true / 失败 false）。**为什么不写进 `installMsg`**：它在 `HStack` 里和百分比同行、旁边有 `Spacer()`，长文案会被挤压。
- **离线版本清单的措辞改进**：网络失败时兜底的 7 个版本（1.21.5/1.21.4/1.20.6/1.20.1/1.19.2/1.16.5/1.12.2）**id 和日期都是真的**（1.20.1 → 2023-06-12、1.19.2 → 2022-08-05 都对得上），用户选了能真装上——不是假数据，只是不全。原来说"（显示内置示例）"会让人以为"假的不能装"，改成「下面是内置的 7 个常用版本（都能装），联网后可看全部」，并加了维护注释 + `fixedSize`。

- **首次启动给出耗时预期**：`ZLStrings.splash_screen_installing`（安卓版"请耐心等待"文案）在 iOS 侧**只出现在定义处、从未被引用**，而启动页顶部只有版本名 + 阶段名 + 问候。朋友第一次启动要解压 JRE、校验库，可能几分钟 —— **没有预期提示他很可能会以为卡死而强制退出**，那这次启动就白费了。已在启动页加一条「第一次启动要解压运行环境、校验文件，可能要几分钟 —— 别退出，等它跑完」，**只在 `gameLaunchCount == 0` 时显示**。
- **顺带审计（干净）**：术语一致性 —— "删除/移除/清空/清理"是有意区分（删单个/移除披风/清空列表/清理批量）· "存档/世界"是 MC 社区惯例（管理用"存档"、游戏内实体用"世界"）· 另两处是我的判据重叠计数（"光影包"含"光影"、`modAuthors` 是变量名）。

- **新增 `_check-code-refs.js`：注释里的「本仓库文件:行号」必须仍指得到代码**。项目有 **26 处**这种对照引用（移植时逐行核对用的），重构会让行号漂移而编译器不管。三层判据：①文件存在 ②不越界 ③**该行不是空行/纯注释**（说明已漂移）。实测 26 处全部指向代码；三层注入（越界 / 真空行 / 文件不存在）都验证过。**局限**：抓不到"偏移到另一段代码"（需语义比对）——第一次注入把 448 改成 449 就通过了，因为 449 也是代码。
- **顺带审计（都干净）**：版本号是单一来源（`MARKETING_VERSION` → Info.plist → `ZLUpdate.currentVersion`）· App Group 有 `?? .standard` 回退 · TODO 全仓只剩 2 处（`EasyTierTunnel` 联机占位，与文档一致）。

- **文案教用户"从其他 App 分享进来"，但项目做不到**：`FileManagerScreen` 空状态原写「或者从其他 App 把文件分享到 CraftLauncher 里」，而 `project.yml` **没有 `CFBundleDocumentTypes`**（对方 App 的「用其他应用打开」里不会出现 CraftLauncher）、代码也没有 `onOpenURL` 接收。已改成「用「文件」App 把文件拖进 CraftLauncher 文件夹」（`UIFileSharingEnabled` 已开，这条可行）+ **STATUS 补第 10 条**记下能力边界。
- **新增 `_check-share-claim.js`**："文案教了做不到的操作"的特殊形态——承诺的不是代码能力而是**系统级声明**（`CFBundleDocumentTypes` 在 YAML 里，编译器不管）。注入验证能精确报出。
- **顺带审计（干净）**：`deploymentTarget iOS 16.0` 与代码里 2 处 `@available(iOS 16.0, *)` 一致，没有低版本静默缺失。

- **修：启动器在 iPhone 上会被强制横屏**——`UISupportedInterfaceOrientations` 只声明了横屏，而启动器界面全是 `VStack` 竖排设计（STATUS 第5条讨论"竖屏偏挤"说明意图是竖屏）。`src/Info.plist` 不存在，XcodeGen 从 properties 生成，所以配置就是唯一真相。**改法**：①iPhone 允许竖屏（iPad 保持横屏）②`ZLAppDelegate.orientationLock` + `supportedInterfaceOrientationsFor`（核心启动时把 `SurfaceViewController` 换成 root，只能由 delegate 全局控制）③`CoreBridge` 两处 `launchJVM` 前后切横屏/切回竖屏（放在 `throw` 之前，保证启动失败也恢复）。
- **加 `NSLocalNetworkUsageDescription`**：`LanDiscovery` 用 BSD socket + `IP_ADD_MEMBERSHIP` 加入组播组 `224.0.2.60`，iOS 14+ 会弹本地网络权限提示。不声明也能用（系统默认文案），声明了能说清原因。
- **新增 `_check-orientation.js`**：声明了 Portrait 就必须有切横屏逻辑，且切横屏/切回竖屏**次数配对**。双向注入验证都能精确报出。
- **⚠️ 这条改动真机没验证过**：依赖"root 换成 `SurfaceViewController` 时 UIKit 会重新查询方向"。若游戏画面被裁切/拉伸，说明假设不成立，需补 `windowScene.requestGeometryUpdate`。已写进 STATUS 第 9 条。

- **新增 `_check-fallback-default.js`：兜底值必须等于声明的默认值**。`ZLSettingsStore` 读不到时会用 `defaultValue` 兜底 ✓，但 `CoreBridge` 等处**直接读 `UserDefaults`**、用自己的 `?? `——**两个值之间没有任何机制保证一致**；改了 `defaultValue` 忘了改 `??`，用户没设置过时拿到的就不是声明的默认值，**首启动行为静默变错**。实测 **11 处全一致**（是"碰巧一致"不是"有保障"）。四类判据：`string ?? "X"` / `integer()` 无 `??` / `bool()` 无 `??` / `as? Bool ?? X`。双向注入验证都能精确报出。
- 这是"两端约定清点表"的第六类：type 读写两侧（152+163）· 键名↔定义表（158）· 路由字符串↔消费分支（161）· shortcut↔case（160）· SF Symbol↔真实存在（159）· **兜底值↔声明默认值（164）**。

- **新增 `_check-type-read.js`：type 契约的"读侧"**。`_check-type-control`（152轮）查**写侧**（type ↔ UI 控件），这条查**读侧**（type ↔ `UserDefaults` 读法）。`integer()` 遇 String 给 0 · `bool()` 遇 "true" 给 false · `object() as? Int` 不符给 nil——**用户改了设置但完全不生效，无任何提示**。实测 **17 处全匹配**。
- **过程修正判据两次**：第一版把 `object(forKey:)` 一律当"不匹配"→ 误报 3 处（`as? Bool ?? true` 是标准桥接、`== nil` 是存在性判断，都合法）；第二版改成"`object` 后面的 `as? X` 要和 type 匹配"→ 0 误报。双向注入验证都能精确报出。
- **这是"判据挂保护强度"（162轮）的又一次应用**：`object` 本身不危险，危险的是"转成了错的类型"。

- **新增 `_check-silent-default.js`：字符串 switch 的 `default` 不许静默**。字符串 switch **没有编译器穷尽检查**，`default: break` 会把"漏掉的 case"变成"什么都没发生"——第161轮的 bug 就是这个形态。三层区分：**字符串要报** · 枚举不报（强制穷尽 + "处理少数 case"是正常写法）· 数值不报（值域无界，default 必须有）。实测 **11 个字符串 switch，0 处静默**；注入验证（把 default 的 NSLog 换回 break）能精确报出。
- **过程修正判据**：第一版只看 `default:` 那一行，把"`default:` 换行 + NSLog(...)"也当成静默 → 上一轮刚修的两处被误报。改成取 default 块的**完整内容**后归零。

- **修真 bug：长按图标点「设置」不会跳页**——`ZL2App:34` 写 `setRoute("settings")`，但 `handlePendingAction()` 的转换表只有 `download`/`versionList`/`multiplayer`，`default: break` **静默丢弃**。用户点了 App 会打开但**停在首页、不跳设置页、无任何提示**。已补 `case "settings"`，并把 `default: break` 改成 `default:` + `NSLog`（未知路由至少留日志）。
- **新增 `_check-pending-routes.js`**："字符串当凭据"的第六类，**双向**校验：写侧 `setRoute("xxx")` ↔ 读侧 `switch route` 的 case。注入验证能精确报出「写了但没人消费」。
- **链路现在是查四段**：①声明（project.yml 160轮）②处理（case 160轮）③**路由字符串↔消费分支（本轮）**④用户看到结果。

- **新增 `_check-shortcut-types.js`**：`project.yml` 的 `UIApplicationShortcutItemType` 必须都有对应的 `case`——**跨文件类型（YAML ↔ Swift）**的第五类"字符串当凭据"校验。失效形态：加了快捷项忘了写 case → 长按图标点了**没反应**，`completionHandler(false)` 静默失败。实测 3 个全匹配；注入验证能精确报出。
- **审计快捷项链路（全通）**：URL scheme 无声明无处理（一致，不是 bug）· 三个 shortcut type 配置↔代码全匹配 · 三条消费链完整（`consumeRoute` ← ZL2App:119 · `consumeLaunchFlag` ← :127 · `consumeAutoLaunchPending` ← HomeScreen:439）。
- **顺带记下一段有价值的注释**：`ZLPendingAction.markAutoLaunchPending` 上方解释了为什么从"Notification + 0.8 秒猜"改成"带 2 分钟时效的标志"——0.8 秒不够时首页的 `guard !selectedVersion.isEmpty` 直接 return，**通知是一次性的、启动意图就丢了**，用户会说"用 Siri 启动游戏没反应"。这是「没有报错的 bug」被主动发现并修好的案例。

- **修一个不存在的 SF Symbol**：`folder.fill.badge.person.crop` **在 SF Symbols 里不存在**（只有 `folder.badge.person.crop`，带 `.fill` 的 badge 变体没有）——`VersionManageScreens.swift:92`「当前游戏目录」卡片左侧那个图标**一直是空白的**，因为 `Image(systemName:)` 对无效名**不报错、不崩溃、只渲染空白**。顺带核实 `person.badge.key.fill` 是合法的（iOS 16+）。
- **新增 `_check-symbol-names.js`（基线冻结）**：没有 SF Symbols 完整列表没法自动验证，所以把 **67 个逐个核实过的名字**固化，新增的要人工确认。注入验证（`sparkles`→`sparklez`）能精确抓出。
- **这已经是"用字符串当凭据"的第四类交叉验证**：UserDefaults 键（158轮）· 设置项 key（158轮）· 通知名（129轮）· **SF Symbol 名（本轮）**。

- **新增 `_check-orphan-keys.js`**：`CoreBridge.applyUserSettings()` 用**硬编码键名**读设置——键名拼错或指向已删的设置项，就会**永远读到 nil、设置不生效且无任何提示**（代码看起来完全正常）。判据：所有含 `UserDefaults` 的行里的 `forKey:` 键，必须是 ZLSettings 定义里的一项、或已登记的内部键（6 个，每个写明为什么）。实测 **0 孤儿**；注入验证（`jvmArgs`→`jvmArgz`）能精确抓出。
- **设置集合加"登记必须有效"判据**：`platformOnly`(57)/`notWired`(4)/`renderOnly`(14)/`launcherLook`(10) 共 85 项**全部在 ZLSettings 里**（115 = 85 + 30 对得上）。但这种事会过时（`terracotta` 就是删了 case 忘了删登记），所以这四个集合里登记的 key 必须真实存在，否则报错。注入验证能精确报出。
- **过程修正判据**：第一版把 `host.value(forKey: "ctrlView")` 这种 **KVC** 也当成 UserDefaults 键 → 误报 3 个；改成"只认含 `UserDefaults` 的行"后归零。`control_layout`/`defaultTouchCtrl` 是**核心键的记账本**，归入白名单。

- **修三处过时文档**：①STATUS 第4条原写「**2 个页面还没接入** —— `MultiplayerRoomScreen` 与 `TerracottaScreen`」——实际 `MultiplayerRoomScreen` **已接在 `.room` 路由里**（只是没有导航入口）、`TerracottaScreen` 第132轮就删了（磁盘 0 文件、`AppRoute` 也无 `case terracotta`）。改成「**1 个路由没有入口**」并写清"不是页面没实现"。②改 `_check-dead-routes` 里 `.room` 的理由（"尚未接入"→"已接入路由但无入口按钮"）。③删掉 ALLOW 里多余的 `terracotta` 登记。
- **新增判据：ALLOW 里登记的 case 必须真实存在于 AppRoute** —— `terracotta` 这种事会再发生（删页面忘了删登记），多余的登记会让人以为还有这个路由。注入验证（往 ALLOW 加 `noSuchRoute`）能精确报出。
- **顺带审计（都干净）**：版本占用空间已在列表页显示（`includeSize: true`，`sizeBytes == 0` 时不显示）· 新手引导链完整（只在零版本时显示、文案准确、明确写 Forge 不支持）· 空状态 19 处都有指引。

- **接上 `CoreBridge.gameLaunchCount`**：它第141轮就被发现"存在但全仓没人用"（注释还写着「供 UI 显示」）。现在首页版本描述后面显示「· 已启动 N 次」——对用户是正反馈（第一次成功启动后会看到「已启动 1 次」）。**只在 N > 0 时显示**（"已启动 0 次"是负反馈）；**横排**放在描述后面（首页是固定布局没有 ScrollView，第一版写竖排会多占 13pt）；在 `.task` 路径里赋值、不在 body 里读（`_check-hotpath-cost` 通过）。
- **审计：空状态的可操作性** —— 19 处 `ZLEmptyState`，**17 处自带按钮**，另 2 处用文字给了指引（「打开上面的开关」/ 任务中心的说明性文字），合理。
- **审计：游戏内菜单 40 个键的消费者** —— 全部都有 src 侧读取（2-3 处），没有"没人读"的。

- **手工核实 22 个疑似死方法，删 20 个（约 133 行）**：核实方式是"src 裸名次数 + **core 的 .m/.h 引用**"——`ZLOverlayHost.attach`/`detach` 在 core 有 1/2 处引用，**保留**。
- **连锁清理**：`ZLStaggerIn`（ViewModifier，`.staggerIn()` 删了它就没人用）· `MicrosoftTokenSet.expiresAt`（唯一读者 `isExpired` 删了它就成了死字段）· 删 `isExpired` 留下的空行。`refreshToken` **保留**（`MicrosoftAuth:268` 有赋值链，将来做刷新要用）。
- **三处"看起来该用但被替代"**：①`GameOverlay.recordFrame` → 被 `GameFPSMonitor`（从核心帧计数换算）替代，**FPS 有数据源** ②`MojangAPI.applicableLibraries` → 被 `VersionInstaller` 自己的过滤替代（**跳过 natives + SHA-1 校验**，但不按 `rules` 过滤——natives 已跳过，影响小）③**`MicrosoftAuth.refreshed` 没有替代** → 微软 token 1 小时后过期，**每次都要重新登录**（token 刷新从未接通，这是能力边界）。

- **处理第153轮留的 5 个死字段**：`Account.uuidDashed`（YAGNI）· `Account.hasValidToken`（外置登录不存 token，判断没对象）· `ZLLayer.totalWidgets`（统计字段没人读）· `ZLControlLayout.defaultLayout`（第144轮删假编辑器的遗留）· `ZLAddonSelection.optifine`（OptiFine 是 Forge 系，项目不支持 Forge）。**保留** `CraftLauncherShortcuts.appShortcuts`（`AppShortcutsProvider` 协议要求，已注明）。删前都核实过：`optifine` 剩下 6 处引用全是注释和文案字符串，无字段访问。
- **修一条误导文案**：`DownloadAddonsScreen` 的 OptiFine 卡片原写「需要手动下载并放到 mods 目录（iOS 无法自动安装）」——**错的**：OptiFine 独立版不是 mod，放 mods 没用（要用官方安装器改 jar）；只有 Forge 版才放 mods，而项目不支持 Forge。改成实话。
- **试了"方法级死代码"审计，放弃**：判据要同时躲开三个坑 —— `override func`（网络扩展由系统调）· **不带括号的函数引用**（`onCancel: cancelAddAccount` 是闭包传值）· **@objc 导出 + performSelector**（`activateLayerByPseudoKey:` 在 src 里 0 处调用但 core 天天用）。三版后（37→22）仍需人工核实，性价比不如人工。原因 + 已确认的真死方法（`modCount`/`selfCheck`/`offlineUUID`/`isExpired`/`switchToLayer` 等）都记进 `_check-dead-types` 局限段。

- **对数据模型跑"字段读次数"审计，找到链条式死代码**：`AuthlibSession`（5 字段）被 `Account.init(authlib:)` 当参数类型引用 → `_check-dead-types` 判"有人用"，但那个 init **从没被调用** → 整条链死。这是该检查的**第四个盲区**（单层引用判定，静态算可达性需图分析），已记进局限段。已删 `AuthlibSession` + `init(authlib:)`。
- **删 `acceptedCodeOfConduct`**：只出现 1 次（声明），全仓无读写——安卓抄来的占位字段，服务器准则确认流程没实现。
- **删 `ControlAppearance` 三个冗余计算属性**（`darkBackgroundColor`/`darkContentColor`/`darkBorderColor`）：没人读且重复了 `resolved(dark:)` 的逻辑。**深色配色功能本身是好的**（`resolved` 直接读 `darkBackgroundHex`，ControlModelBridge 双向同步，编辑器有编辑入口）。
- **核实外置登录的真实能力并写进代码**：`login()` 真的调 `/authserver/authenticate` 验密码 ✓，但**只取 id/name、丢弃 accessToken**，游戏内走 `addOffline`（**离线身份，进不了正版服**），皮肤靠 authlib-injector 反查。真要正版会话得补 token 存储 + refresh。
- **审计口径踩了两次坑**：v1 把 SwiftUI View 算进来 → 512 假阳性（属性是隐式 self）；v2 只扫数据模型但用 `\.field` → 仍漏 `self.field` 裸名。v3 用"裸名总次数 ≤1"才得到合理的 11 个。
- **剩余 7 个待判断**：`Account.uuidDashed`/`hasValidToken` · `ZLLayer.totalWidgets` · `ZLControlLayout.defaultLayout` · `ZLAddonSelection.optifine` · `CraftLauncherShortcuts.appShortcuts`（框架实例化，第85轮说不算死）。

- **`ZLSettingDef` 的 `type` 和 `group` 都是 0 次读取**（115 项都声明了，代码一次没读）。`type` 没被读意味着"控件用错类型"没人管——`.int` 的项用 `toggle` 会存成 `Bool`，而 `CoreBridge` 用 `as? Int` 读 → **静默失效**（第151轮那个"分辨率 asInt 读不到"就是这类）。已把 `type` 当**契约**做成 `_check-type-control.js`：`.bool`→toggle · `.int`→slider/number/animateSpeed/blur/keyCode · `.string`→text/picker · `.enumValue`→picker/menu/darkMode。实测 **74 个设置项 · 72 处配对全部匹配**（现有代码是对的，但没有任何东西在守着它）；注入验证（bool 项改用 slider）能精确报出。
- **`group` 保留但注明"代码不读"**：纯文档（render 15 / game 11 / control 29 / gamepad 10 / launcher 44 / other 6），设置页用自己的 `ZLSettingRow` 数组不按组展示。
- `range` 字段补注释：说明"写入路径会 clamp"、"slider / animateSpeed / blurRow 都用它当上下限"。

- **`range` 字段存在 100 多轮但写入路径从不 clamp**：`ZLSettings` 有 **25 项**设了 `range: ClosedRange<Int>?`，但 `store.set(_:_: Int)` 是裸的 `defaults.set(value, forKey:)`——**完全不 clamp**，`range` 只被 slider 的 min/max 用来限制滑杆位置。而分辨率两项（唯一的自由数字输入）**range 还是 nil**：能填 `0`（渲染尺寸 0）/ 负数 / `99999999`（分配巨大缓冲）。已给 `set(Int)` 加统一 clamp（将来新增 int 项自动受保护）+ 分辨率两项补 `range: 0...7680`（0 保留为"跟随 resolutionRule"）。
- **`Int(digits) ?? 0` 会替用户填值**：输入框删空或只输一个 `-` 时存成 0，而 0 在分辨率里语义完全不同 → 改成解析不出来就**不覆盖**。
- **新增 `_check-number-range.js`**：用 `number(...)` 自由输入的项必须有 `range`，注入验证能精确报出。
- **踩了个缩进坑**：第一版补丁的 `anchor` 没带缩进，`includes` 匹配到子串导致插入的 4 行缩进全错（12/4/4/0 混在一起），`_check-indentation` 报出来了——这类错**括号检查查不出**。

- **按"还有谁在做同一件事"扫出三个漏网的下载校验**：`VersionInstaller`/`ModrinthAPI` 第40轮就加了 PK 魔数，但这三个没有——①`ZLYggdrasil.downloadSkin` 只判 `data.count > 100`（HTML 错误页被存成 `skin.png`）②`ZLYggdrasil.ensureDownloaded` 只判 `>100_000`（**>100KB 的错误页会被存成 `authlib-injector.jar` → `isReady` 为 true → `-javaagent` 指向无效 jar → JVM 启动直接失败**，与第31轮 patchjna 同类）③`LoaderInstaller` 无校验且 `failedLibs` 不会记（write 成功了）。已分别加 PNG 魔数 / ZIP 魔数 / PK 魔数；`LoaderInstaller` 顺带加了 `ZLLoaderInstallerError.badContent`（并补 `errorDescription` 分支，**漏了会编译失败**）。
- **新增 `_check-download-magic.js`**：文件里同时有"下载"和"写盘"就必须有内容校验痕迹。`MojangAPI` 在 ALLOW（通用流式下载器，内容类型不定，但**有更强的保障**：非 2xx 抛错 + 下载截断检测 `received < expectedSize` + `.part` 临时文件 + 原子替换）。
- **注入验证暴露我自己的漏洞**：第一版注入仍报 ✓，因为 `MAGIC` 匹配到**注释里的 `0x50`**——与第143轮"注释算引用"同一个坑。加剥注释后可精确抓到。

- **两处"用户以为成功、实际失败"的静默吞错**：①`emptyTrash` 的 `for i in items { try? fm.removeItem(at: i) }`——"清空回收站"是**永久删除**，文件被占用时静默跳过，用户以为空间释放了；`guard let ... else { return }` 读不到目录时也不说话。现在会报「几个、哪几个、它们还在回收站里」。②`LoaderInstaller` 的库下载用**空 `catch`** + `done += 1`（成败都加）+ 返回 `libraryCount: libs.count`（**计划数**），调用方显示「已安装 X（N 个库）」——**缺库也照样说装好了**，而缺库的 Fabric 加载器启动必然 `ClassNotFoundException`。现在 `failedLibs` 记录失败项、文案说「可能起不来，建议重装」、状态标 `.failed`。这与第40轮修的 `VersionInstaller.failedLibs` 同类，当时 `LoaderInstaller` 漏了。
- **空 catch 审计（错误处理的第三个角度）**：3 处 —— `ControlLayoutModel` ×2 是第12轮确认的 Codable 容错解码（合理）+ `LoaderInstaller`（本轮已修）。现在 0 处可疑。
- 顺带：全仓 211 处 `try?` 里跟进"改变数据"操作的 66 处，62 处"完全静默"但逐个看过都合理（`createDirectory` 幂等、临时目录清理）。

- **新增 `_check-settings-entry.js`：可用设置项是否都有 UI 入口**。与 `_check-settings-wiring` 互补——那个查"代码层有没有人消费"（有 UI 没人用=假功能），这个查"用户能不能改到"（有消费没入口=改不到）。实测 **30 项 = 21 UI 控件 + 4 自动写入 + 1 手势 + 4 内部记账 + 没入口 0**。过程修正：第一版漏了 `number(` 控件形态和 `ControlEditor.swift` 文件，误报 10 项，补齐后 0 项。注入验证能把 `menuBallPos` 从"手势"名单拿掉的情况精确报出。
- 顺带审计（承接第147轮"检查承诺 vs 实现"）：15 个成功文案含**全称词**（每个/所有/全部）的检查，逐个看实际输出，**4 个"没有分母"的全都有**（42 个脚本 / 9 个文档 / 26 个键 / 91 个 View）——是我的审计判据漏了"个脚本""个键"这类单位，不是检查说大话。

- **`_check-script-inventory` 说"不许漏同步"，实际只比文件名**：判据 D 只比对文件名集合（`missingInRepo` / `extraInRepo`），两边都有但**内容不同**时不报。实测：`_check-dead-types.js` 改了没同步（166 行 vs 157 行），而这条检查报 ✓。已补**判据 F：内容必须字节一致**（`fs.readFileSync(...).equals(...)`）；加完立刻抓到 2 个——其中一个就是**刚加的判据 F 自己**（第95轮那次也是"检查第一次跑就报自己"，再次证明机制有效）。

- **试做"枚举 case 级死代码"检查，两版判据都放弃**：v1（扫整个枚举体）16 处里 **14 处误报**——Swift 的 `case` 同时是"枚举 case 定义"和"模式匹配"关键字（`switch case` / `case let x`）；v2（只扫定义区）仍误报 **7/18**（空枚举被判成有 case）。误报率 87%/39% 的检查比没有更糟，**不做**，原因已写进 `_check-dead-types` 的局限段防重复尝试。
- **删 `ModrinthProjectType.datapack`**：全仓只出现在定义行，`from(_ kind:)` 没有对应分支、`AssetKind` 也没有此类型。→ **能力边界记录：Modrinth 的 5 类资源本项目只支持 4 类（不含 datapack）**。
- **顺带核对**：`ZLPreflight`（第52轮建，93 轮前）的 7 项检查仍准确 —— `availableKeys` 动态算渲染器、未引用已删的 MobileGlues、布局名走 `coreActiveLayoutName`、Java 判定走 `hasRuntime`/`requiredJavaVersion`。

- **补全 `ZLFriendlyError` 的错误码映射（7 → 14 个 case）**：第145轮改成"错误码优先"后只覆盖 7 个码。补上最常落兜底的 7 个 —— `.badServerResponse`（4xx/5xx，最常见）· `.cannotDecodeRawData`/`.cannotDecodeContentData`/`.cannotParseResponse`（**正是"下载源返回 HTML 错误页"那个场景**）· `.fileDoesNotExist`/`.noPermissionsToReadFile`（**这两个在 `NSURLErrorDomain` 里**，原来那三条 `NSCocoaErrorDomain` 的文件 case 抓不到）· `.resourceUnavailable` · `.dataNotAllowed` · `.userAuthenticationRequired`。
- **删 `CoreLaunchError.missingRuntime`**：全仓 0 处 —— 从没被抛出也没被匹配，死 case 会让人误以为"缺运行时"有专门处理。
- 顺带审计（按第145轮清单）：11 处 `+ "/"` 拼路径在 **iOS 上安全**（分隔符固定）；`String(describing:)` / `.description` 做判断 **0 处**。
- **待做**：枚举里"从没被构造/匹配的 case"也是死代码，`_check-dead-types` 目前只查顶层类型不查 case。

- **错误提示在中文系统上全部失效**：`ZLFriendlyError.text` 的 9 条映射全靠 `localizedDescription` 做文本匹配（`lower.contains("timed out")`），而它在**中文系统上已经是中文**（"请求超时。"）→ 永不匹配 → 全部落兜底，用户看到「请求超时。（错误码 -1001）」而不是「网络超时，请检查网络后重试」。已改成**先按错误码判断**（`NSURLErrorDomain` + `URLError.Code` 7 个 case；`NSCocoaErrorDomain` + code 3 个 case），原有 20 条文本匹配保留作补充。这解释了为什么第51轮加的"三类错误建议"一直没真正生效。
- **新增 `_check-error-locale.js`**：①函数里必须有错误码判断 ②错误码判断必须在**第一个文本匹配之前**（否则文本分支先吃掉）。注入验证能把文本匹配提前的情况精确报出。
- 顺带审计：全仓 19 处 `localizedDescription`，除这一处其余都是"拼进提示/日志"不做逻辑判断，合理。

- **"重命名版本"是个活的假功能**：`VersionActionSheet` 里 `TextField("新名称", text: $newName)` 收集了输入，但"确定"调的是**无参数的 `onRename()`** —— **`newName` 从未被读取**；两个可达入口（`VersionContentScreen` / `VersionListScreen`）的 `onRename` 都只做刷新。**用户点重命名、输入新名字、点确定、版本名不变且无任何提示**。已在 `VersionActionSheet` 内真正执行改名（`performRename()`：空名/同名两个 guard + `renameVersion` + 错误显示），调用方 `onRename` 保持"刷新列表"语义。
- **删 `ModifyVersionScreen.swift`（276 行）**：它的四项功能里"改名"是真实现但已被正主覆盖，"换 MC / 换加载器"是**假的**（只在结果文本里说"将改为 X"，不改任何东西），而它本身从未接线。

- **三处假平台筛选**：`runSearch()` 用了 gameVersion / modLoader / category / platform / sort，**唯一没参与的是 `source`（目标平台）**，而全仓也没有 CurseForge API。删掉 `AssetsScreen` 的「目标平台」filterCard + 平台 chip + `kind.sources`、`SearchIDScreen` 的平台 Menu + `platforms`，文案改成「支持 Modrinth 全站资源」。
- **删 344 行死代码**：`SampleData`（66 行，零引用且里面是**逼真的假 Modrinth 数据**）· `LaunchContract.swift`（213 行 / 7 类型，早期架构骨架，实际用 CoreBridge）· `ErrorScreen`（65 行，被 LaunchScreen 错误区覆盖）。文件数 70 → **69**。
- **修 `_check-dead-types` 的三个盲区**：①**注释算引用**（`SampleData` 因注释里提一次而漏掉）→ 统计前剥整行注释 ②**文件内互相引用**（`LaunchContract` 6 个类型全零外部引用但互引让 count>1）→ 新判据"文件里所有类型都零外部引用 = 死文件" ③**跨语言动态引用**（新判据立刻把 `ZLOverlayHost.swift` 报成死文件，**但它由 ObjC 的 `NSClassFromString` 实例化、负责 FPS 悬浮层**）→ 扫 core 的 `.m` 把动态类名也算引用。**第③条差点造成真实损害。**
- **留 TODO**：`ModifyVersionScreen.swift`（276 行，真功能但从未接线）已加 ALLOW，下一轮决定接线或删。

- **关于页那张「已加载的插件」是纯假的，已删**：卡片写着 `MobileGlues / com.pi.phux.mobileglues · 1.3.4`，三重误导——①项目**没有插件机制**（`ZLStrings` 里那些 plugin 文案是安卓整包提取未引用、两个相关设置项都在置灰集合里）②`MobileGlues` 在仓库里**一个文件都没有**（第103轮确认过，当时只改了 `LicenseScreen`，漏了这里）③包名与版本号是硬编码假数据。删掉整张卡片（17 行）。
- **新增 `_check-hardcoded-versions.js`**：用户可见字符串里不许有硬编码版本号。判据：`Text`/`Label`/`LabeledContent` 等含 `1.20.1` 格式且**不含中文** → 报；含中文的多半是说明文字只提示；许可证名在 ALLOW。用第141/142轮两个真实事故当验收用例，都能精确报出。

- **首页那行版本描述是硬编码的**：`HomeScreen` 里写着 `Text("1.20.1 · Fabric 0.19.2")`——无论装什么版本都显示这一行（第43轮那类"假数据"的漏网之鱼，而且在首页最显眼处）。已新增 `VersionRepository.displayMeta(for:)` 从版本 JSON 真实读取（加载器版→`Fabric · 1.20.1`，纯原版→`原版 · 正式版`，读不到返回 nil 就不显示这行）；首页用 `@State` 存（**不能在 body 里读文件**——第125轮的 `_check-hotpath-cost` 实测拦住了这条思路）。
- 顺带统一：`VersionListScreen.versionMeta` 与首页各写一份"读 JSON 拼描述"且输出格式不一致，现在都走 `displayMeta`，列表页保留自己的缓存层。

- **扫出并修掉 2 处"名单里的文件读不到就静默跳过"**：按"监视对象消失"这个判据扫全部检查——6 个有写死文件名单，4 个没 `existsSync`。核实后 `_check-install-docs` 已正确（`missing` 计入 fail）、`_check-script-inventory` 的 `PATH_EXEMPT` 是豁免名单不用改；`_check-doc-stats`（`catch { continue; }` 静默跳过）与 `_check-path-safety`（GUARDED 少一个只减分母）要改。都加了"名单存在性"保护，报错文案统一说「**读不到就等于没查**」。
- 附带发现：`path-safety` 的 `read()` 没有 try/catch，文件不存在会**抛异常崩掉**而不是走友好提示 → 改成循环里先 `fs.existsSync` 再读。

- **`_check-decode-recovery` 加双层保护（累计 6 个）**：①分母 + 零匹配——输出「扫到 N 处 try? 解码，其中 M 处有备份」，N=0 报错 ②**名单失效保护**（这层是新的）——`WATCH` 里的文件先 `existsSync`，读不到就报「这些文件读不到（改名或删了），它们是这条检查的主要对象，读不到就等于没查」。双层注入验证：正则换成 `/__never_match__/` →「扫到 0 处」报错；WATCH 改成不存在的文件 →「读不到」报错。
- 累计带零匹配保护：`_check-error-hints` / `_check-path-safety` / `_check-setting-defaults` / `_check-a11y` / `_check-destructive-confirm` / `_check-decode-recovery`。

- **零匹配保护再推广两个（累计 5 个）**：①`_check-a11y` 原来只报"无标签按钮 N 处"，现在先报「167 个 Image(systemName:)，其中 **85 个在 Button 里**」——它的判据靠 `labelBlockOf(i)` 判断"图标在不在 Button 里"，**这个函数一失效，所有图标都会被当成装饰性跳过**，"0 处无标签"就是空真 ②`_check-destructive-confirm` 的文件数为 0 也直接报错。验证方式：直接让 `labelBlockOf` 返回 null（模拟识别失效）→「其中 0 个在 Button 里」→ 报错；还原后回到 85。
- 累计带零匹配保护的检查：`_check-error-hints` / `_check-path-safety` / `_check-setting-defaults` / `_check-a11y` / `_check-destructive-confirm`。

- **三个检查补上「零匹配即失败」**：一个"匹配 N 处、然后判断全对"的检查，**N=0 时永远通过**——而 N=0 恰好是"判据过时"的典型信号，两者从输出上看不出区别。已改：①`_check-error-hints` 输出「匹配到 N 条 ZLDiagItem，其中 M 条带 fail/warn」②`_check-path-safety` 输出「匹配到 N 处 appendingPathComponent」③`_check-setting-defaults` 原来连文件数都不输出，现在「扫了 70 个文件、7 个读设置的 helper」。任一项为 0 直接报错，文案说清「**这不是"没问题"，是"没看到东西"**」。注入验证：把 `ZLDiagItem` 两文件全改名 / 把 `helperRe` 换成永不匹配的正则 → 都精确报错，还原后通过。

- **要求每条检查自己写明「我查不到什么」**：新增 `_check-check-metadata.js`——每个 `_check-*.js` 的头部注释必须有「**局限**」段（只认哪些写法、判不了什么、什么时候该来改它）。**存量用基线冻结**（当前 40 条里 29 条未写，只许降不许升）。这轮先补了最典型的 7 个"抓具体写法"的检查：`_check-readme-claims` / `_check-license-page` / `_check-path-safety` / `_check-atomic-writes` / `_check-destructive-confirm` / `_check-error-hints` / `_check-setting-defaults`，各写明"改了哪种写法会失明"。33 → **29**。
- **零发现审计**：跑完整套 63 项，收集每项输出，挑出"输出里没有任何具体数字"的 14 项（其中 2 项是契约测试输出"通过 6/7"，可信）。它们多数是"只做布尔判断"，但正是第135轮那个教训的高危区——**看不见了不会告诉你**。
- 注入验证第一次又踩老坑：判据用裸的 `/局限/`，我的测试探针注释写着"故意没写局限"，**被自己的文案命中**（第108轮同款）。改成只认标题形式后注入能精确报出。

- **`_audit-stores.js` 的方向过时了，补上真正该问的问题**：它报「17 处读了 UserDefaults 但没人写」，逐个查过去**全是误报**——设置项实际写入走 `ZLSettingsStore.set(_:_:)` → `defaults.set(value, forKey: def.key)`，**键是运行时变量**，抓字面量的正则看不见。而核心**不读 UserDefaults**，所以真正该问的是「核心要读的值有没有被桥接过去」。
- **新增 `_check-settings-wiring.js`**：按归属分类 30 个"可用"设置项 —— 核心桥接 **10** / Swift 消费 **16** / 内部状态位 **4** / **无归属 0**。**结论：设置链路完整，没有假功能**。注入一个未接线的设置项会精确报出。
- 顺带修正两个解析错误：①第一版临时脚本把集合里的**注释**当成键（第133轮加的注释含英文双引号，如 `（"这个能力 iOS 上还不行"）`、`setenv("GAME_DIR", …)`），算出"可用 79"；改成**跳过注释 + 按括号深度取集合**后正确值是 88 置灰 / 可用 **30**（与第88轮一致）②`_audit-stores.js` 已补盲区说明。

- **`MultiplayerScreen` 的三节教程在教用户做不到的事**：「房主教程」「房客教程」里"开启「启用多人联机」开关"（该开关在 `notWired` 里置灰）、"通过悬浮窗的联机菜单创建房间"（入口第133轮已删）、"输入邀请码加入房间"（未实现）——而右栏已诚实写着「远程联机（EasyTier）[尚未接入]」，左边教、右边说不行。已加警示组件 `notConnectedNotice`（步骤保留说明设计意图，但事先说清现在走不通、想一起玩用局域网）。
- **`_check-guide-claims.js` 新增判据**：`DISABLED_SETTINGS_CLAIMS`（文案 → 设置键）——教程里出现某句操作、对应设置在 `notWired`/`platformOnly` 里、且附近 30 行既无提示词也无警示组件调用 → 报。注入验证能精确报出两处。
- **挖出跨轮 bug：CRLF 文件的注释一行都剥不掉**。`stripComments` 用 `line.replace(/\/\/.*$/, '')`，而 JS 的 **`.` 不匹配 `\r`**，`ZL2App.swift`（CRLF）的每行都匹配不上 → **这条检查对几十轮来一直是瞎的**。已改为 `/\/\/[^\r\n]*/`；`_test-keynames.js` 同样写法一并修（修后 119 条用例仍全过）。
- 同轮踩的坑：`String.replace(str, str)` 第二个参数里 **`$` 有特殊含义**（`` $` `` = 匹配之前的全部内容），我把注释写成 `// 不能用 \`.*$\`：…` 导致**整个文件被展开、头部重复两遍**。已改为全部用函数式 `replace(re, () => str)`。

- **清掉 Terracotta 残留属性（16 处 / 两文件）**：承接上轮删页面，`GameMenuScreen` 与 `GameOverlay` 里还留着 `enableTerracotta` 与 `onOpenTerracottaMenu` 两个属性 + 一个恒假 if 块 + 未使用的 `terracottaMenuTitle`。核实都是纯死代码（前者恒 false、后者从没被赋值）后删除。
- **故意保留的三个设置项（并写明理由）**：`ZLSettings` / `SettingsScreen` 的 `enableTerracotta` / `enableTerracottaNodes` / `terracottaNodes` **不能删**——它们在设置页显示「尚未接入」，对用户是**有用的说明**，删了用户在设置里就完全看不到 Terracotta 这回事。已按第129轮的教训把这段理由写进 `notWired` 的注释，免得将来有人顺着"页面都删了"一起删掉。

- **删掉 359 行的假联机页 `TerracottaScreen`（整文件 + 死路由）**：按"有反馈的假功能比空白危险"的判据扫出来的——「启用多人联机」Toggle 绑 `@State enabled`，无持久化、无消费者。核实：`.terracotta` 路由**无人导航**（第76轮已确认）、它定义的 3 个类型（`ZLRoomType`/`ZLRoomCode`/`ZLTerracottaState`）**文件外零引用**、Terracotta 需要 Network Extension（本项目基本不可能接入）。删前确认 `GameMenuScreen:279` 的入口是**双重死代码**（`enableTerracotta` 在 `notWired` 里置灰且默认 false；`onOpenTerracottaMenu` 恒 nil），不会造成死链。文件数 71 → **70**，AppRoute 23 → **22**。
  **为什么这次删而第42/76轮保留**：那时把假交互改成说明卡、按"自身声明为界面演示"留着；但一个 359 行的假联机页摆在那里，将来谁接上路由，用户会看到一整套拨了没反应的界面——留着"以后也许有用"的成本高于价值。

- **删掉占着"控制布局"位置的假编辑器**：`AppRoute.controlEditor`（第76轮登记的死路由）指向的 `ControlsScreen` 是个简化假编辑器——7 个写死按键、拖动只改 `@State`、**"完成"只是 `editing.toggle()`、没有任何保存逻辑**；而真编辑器是 `ControlEditorScreen`（1700+ 行，能保存/导出到核心），入口在 `ControlManageScreen`。虽然死路由没人导航（用户到不了），但哪天有人把它接上就会进到拖完不保存的假编辑器。已删 `ControlsScreen` + `ControlKey`（73 行）+ 死路由与目的地分支，`AppRoute` 24 → **23**。
- **手势审计结论**：全仓 7 处长按菜单 + 3 处左滑 + 1 处长按 + 2 处自定义拖动，**都是 iOS 惯例或已有提示**，没有"藏起来用户不知道"的交互。

- **下载时切出去会中断，但用户不知道"已下的不用重来"**：查了生命周期——所有下载都用 `URLSessionConfiguration.default`（非后台会话），`scenePhase` 只在 `ZL2App` 处理快捷指令，全仓**没有 HTTP Range 断点续传**。所以切到微信 → iOS 挂起 App → 下载被取消 → 回来看到"安装失败"。但 `install()` 会跳过「文件已存在且 >1KB」的项，**再点一次会接着装**。已补三处文案：进度区常驻提示 + 失败信息后补一句 + 给朋友的清单第六节加醒目提示。**只改文案不改代码**——真修法（后台会话 / Range 续传）要动下载层，本地无编译器无真机，风险不该冒。

- **审计"默认值兜底"与通知机制，两条都干净**：①`?? 0` / `?? ""` / `?? Date()` / `?? 布尔` 全仓 **119 处**，逐个看过——绝大多数是正确语义；只有 7 处"显示文件大小"在 stat 失败时会显示「0 字节」而非「未知」，**轻微不精确、故意不改**（要改得把 7 个 model 的 `sizeBytes` 改成 Optional，而 0 字节是合法值、不能当哨兵）。②只定义 2 个 `Notification.Name`，post 与 `publisher(for:)` 全部对应、无孤立；`⌘R` 走广播通知、各页面随视图生命周期监听，6 个观察者各刷自己的数据。
- **给 `pingAll()` 加注释说明"必须串行"**：串行 20 个服务器最坏 100 秒，但 `withTaskGroup` 的子任务**不继承 MainActor**，而 `ping` 里改 `loading`/`pings`/`failed` 这些 `@State` → 并发化就是"后台线程改 UI 状态"（第127轮刚审计过这类）。真要提速应把网络请求并行、结果收集完再一次性回主线程写状态。

- **下载前预检磁盘空间**：`VersionInstaller.install()` 原来拿到 metadata 就直接下载，空间不足会"等几分钟 → 装到一半失败 → 留下不完整版本目录（预检报文件不存在，但用户不知道是空间问题）"。现按版本 JSON 的 `downloads.client.size` + `libraries[].downloads.artifact.size` 估算，assets 按前两者 50% 粗估，再留 200MB 余量；不够就抛错并说清"要多少 / 还剩多少 / 现在中止不会留下装了一半的版本"。**条件写死**：`needed > 0` 且 `free != nil` 才拦，任一未知就放行（宁可让下载自然失败，也不把"查不到"误报成"空间不足"）。
- 新增 `src/ZLStorage.swift`（`freeBytes()` / `human(_:)`）—— **一处实现、两处使用**（诊断页显示 + 下载前预检），消掉 `ZLDiagnostics` 里那份重复的 `attributesOfFileSystem` 调用。`freeBytes()` 拿不到时返回 `nil` 而非 0，让调用方能区分"空间是 0"和"查不到"。

- **并发安全扫过一遍：8 个"切到后台"的块全部正确**。`Task.detached` / `DispatchQueue.global` / `concurrentPerform` 共 8 处：4 处 `await Task.detached{}.value`（await 把执行权交回原 actor）· 2 处是 continuation `resume`（可从任意线程调、不改 UI）· 2 处打包块的两个出口都有 `DispatchQueue.main.async`。
- **这类问题不固化成检查**（写清理由）：第一版检测器报 6 处可疑、实际全是误报——不认 `await` 回 actor、不认 continuation resume、窗口太短看不到远处的 `main.async`。按第107轮教训（判据不可信就别留着，6/8 误报会让人以为真有问题），改为把结论写进交接文档「五、已验证、别再重复查」表。同表也补了「性能频率（124–126轮）」一行。

- **高频位置检查从"渲染期"扩到三层**：`_check-hotpath-cost.js` 现在同时守 ①`body`/computed var（每次重绘）②`.onChange`（每次值变）③`ForEach`（每行）。实测 **228 渲染块 + 23 onChange + 98 ForEach，0 处昂贵操作**。合并进同一个检查而不是新开三个脚本——同一套"昂贵操作列表 + 大括号配对"逻辑，拆开会变成三份要同步维护的副本。注入验证：把 `listVersions()` 塞进某个 `.onChange` → 精确报出「…:91（在 L90 起的高频块里）」。
- **性能频率谱系至此扫清**：onAppear（124轮修 1 处）· 渲染期（125轮，0 处）· onChange/ForEach（126轮，0 处）· `.task` 本来就是该放昂贵操作的地方（不查）。这条线收掉。

- **把"渲染期不许有昂贵计算"做成检查**：新增 `_check-hotpath-cost.js` —— `var body` 与 computed var 会在**每次重绘**时求值，里面出现 `listVersions` / `directorySize` / 目录枚举 / JSON 解码 / 读文件就报。**第一次扫出的 2 处是误报**：`FileManagerScreen` 属性页把递归算目录大小放在 `.task { }` 里（正确做法），而检测器把 body 内嵌的 `.task` 也算成渲染期 → 加了豁免（`.task`/`.onAppear`/`.onChange`/`.sheet`/`.alert`/`.refreshable` 等副作用闭包内部不判）。改完重扫 **228 个渲染块，0 处**。注入验证：把 `listVersions()` 塞进某个 body → 精确报出「…:46（在 L45 的渲染块里）」。
- 文件头写明局限：只认这 5 类操作，别的昂贵写法（排序、拼接、正则）不判。

- **首页每次 onAppear 都在主线程递归扫全部版本目录**：`listVersions()` 对每个版本目录调 `directorySize()`（`fm.enumerator` 递归遍历 jar + libraries 数百文件 + mods，逐个 stat），而 `sizeBytes` 全项目**只有版本列表一处显示**。改为 `listVersions(includeSize: Bool = false)`，只有 `VersionListScreen` 传 `true`；UI 里 `sizeBytes == 0` 不显示。新增 `_check-startup-io.js` 静态守住这个默认值（本地没真机，测不了耗时，只能守默认）：断言参数默认 false + `directorySize` 受其门控；注入改成 true 会报。
- **`_run-all.ps1` 加清单结构自检**：第79/124轮各踩一次——插三元组时多留逗号 → `@(...),,` → 数组套数组 → 报 `Join-Path: 无法将 System.Object[] 转换为参数 ChildPath`，**错误信息离病根太远**。现在每项必须是长度 3 的数组，否则直接报出是哪一项并提示原因。

- **把"单跑抽查"固化成工具 `_spot-check.ps1`**：第122轮发现 `_check-links.ps1` 假绿 26 轮（脚本里有 U+FEFF，PowerShell 报错不终止、退出码仍 0，而 `_run-all.ps1` 只看退出码）。人工单跑是一次性动作，不会重复发生，所以做成工具：**绕过执行器逐个单跑清单里的脚本**，判定比执行器严（退出码≠0 **或** 输出里有 ErrorRecord，任一成立即算问题）。
  用它验了一遍：**60 个脚本单跑全部干净**，说明第122轮那批 BOM 清理是彻底的。过程中它自己抓到两件事（新脚本未登记、清单改了但交付包没同步），都证明它在工作。它**不进**必跑清单（会起 60 个子进程拖慢每轮），已登记进 `README-脚本清单.md` 的"抽查工具"。
- 反复踩的坑记档：用 `write` 写 `.ps1` 不带 BOM → PowerShell 5.1 按 GBK 解码中文，`干净通过` 变成 `骞插噣閫氳繃`、引号被吃掉、语法直接崩；`New-Object System.Text.UTF8Encoding($true)` 这次也没写出 BOM，最后用 node 手工拼 `EF BB BF` 才成。

- **12 个 PS1 脚本混进 BOM 脏字符，跑不起来；而 `_run-all.ps1` 一直报绿**：`_check-links.ps1` 第 2 行 `$d = $ZL2Repo` 行首有 U+FEFF（第96轮迁移留下），PowerShell 报「无法将"﻿$d"识别为 cmdlet」。13 个文件已清理并统一保证「以 BOM 开头、内容干净」（另给 `_paths.ps1` 补上缺失的 BOM）。根因在于判定：`_run-all.ps1` 只看 `$LASTEXITCODE`，而 PowerShell 脚本**报错但不终止**时仍返回 0 —— 已改为同时检查输出里的 `ErrorRecord`，记成 `ERR(n)`。验证：注入 `Get-ThisCommandDoesNotExist` → 退出码 0 但 ErrorRecord 9 个 → `run-all` 报 `✗ exit=ERR(9)`，还原后全绿。**文档死链检查从第96轮起一直没真正跑过**。
- 给 `docs/真机验证清单-给朋友.md` 新增「九点七、顺手确认（可选，每项 5 秒）」：覆盖最近 20 轮修好但清单里完全没提的六项（深色模式、开源许可、检查更新、游戏内菜单手柄/陀螺仪应为灰、两个彩蛋、旁白能否念出右上角按钮）。

- **裸调用检查补上了（第120轮说"不做"，第121轮找到了做法）**：第120轮试全查，误报 9 → 加过滤后 94，于是放弃。第121轮换**相反策略——只跳过含 `?` 的调用**（三元 `a ? b : c` 的冒号在顶层、与标签冒号字面相同；数组 `[`、函数 `(`、强制解包 `!` 的标点都在嵌套层，不影响）。结果：**742 个方法 / 静态调用 289 处 / 裸调用 1657 处（跳过含三元 81 处）/ 对不上 0 处**。真实事故验收：把第119轮那个「`enabled:` 插到 `options:` 前面」注回去 → 精确报出「调用 _,key,enabled,options / 声明 _,key,options,enabled」，还原后 0 处。文件头局限说明也已从"不查裸调用"更新为"只查不含三元的裸调用"。

- **参数标签检查的覆盖从 12 个类型扩到全部 367 个**：原来 `WATCH_TYPES` 是手写白名单，`GameMenuScreen.listRow` 不在里面 —— 这正是第119轮「`enabled:` 插错位置」漏掉的原因。改成动态收集全工程类型后，**742 个方法声明 / 289 个调用点，0 处对不上**。顺带修了解析器不跳过字符串字面量的 bug（`ZLClipboard.copy("\(s.address),label: …")` 的逗号被当分隔符，2 处假报）。**裸调用（同类型内部不带前缀，如 `listRow(...)`）试过但放弃**：1736 处里误报 9 处全是三元 `? :` 被当标签，加过滤反而涨到 94 —— 需真正语法分析，按第114轮教训止损。三条局限已写进文件头。

- **游戏内菜单里 4 个模块可调，但核心根本不读**：手柄 / 手势（含快捷栏）/ 陀螺仪三个 tab 共 **21 个偏好键**，实测①全部在 `ZLUnsupportedSettings.platformOnly`（设置页早已置灰写「iOS 不支持此能力」）②核心 `core/` **0 处真实读取**（`gamepadControl` 命中的 3 处是 `gamepadControlList` 文件名列表）③项目里没有 `GCController`/`GCKeyboard`，`CMMotionManager` 只被 `ZLGlass` 视差动效用过。于是出现「设置页说不支持、进游戏却能拨、拨完没反应」。已加 `inputExtrasWired = false` 统一置灰；陀螺仪段那句 `if !usable` 的官方说明因此**终于会显示**（原来 `usable = isGyroAvailable` 在真机恒 true，永远不显示）。
- 踩坑记档：给 `listRow` 加 `enabled:` 时插在了 `options:` 前面（签名顺序是 `title, key, options, enabled`），而 `_check-call-labels` 的覆盖范围只有 12 个类型（`GameMenuScreen.listRow` 不在白名单），所以没拦住。（更正：我最初写成"只比集合不比顺序"，那是错的 —— 它一直比完整序列。第120轮已把白名单换成动态收集全部 367 个类型，742 个方法 / 289 个调用点全部对上。）

- **补上「缩进」这条盲区**：第116轮改代码时 `if` 缩进跑到第 0 列，而 `swift-lint` 报"括号配对正确"、58 项检查全绿——括号检查验的是配对不是排版。新增 `_check-indentation.js`（逐行跟踪大括号深度，缩进小于期望就报，大于不报）。判据第一版报 522 处，逐个看全是漏洞：`case`/`default:`/`@unknown default:` 与 `switch` 同列、行首 `]`/`)` 收尾、**多行字符串内容**（`ZLUpdate` 的崩溃报告模板 7 行文本）；修完第三次跑 0 处。注入第116轮那种错 → 精确报出 `ZLPathSafety.swift:91 实际 0 空格，期望 ≥4`。
- 顺带核实本项目 **0 行 tab 缩进**（全空格），判据可直接按字符数算。

- **「检查更新」会撞 GitHub 限额，而且撞上后只甩一个 403**：`ZL2App` 每次启动都查一次，而 GitHub 未认证 API 限额是**每小时 60 次（按 IP）**。已加节流——**6 小时内只自动查一次**（手动检查不受限）；并把状态码说人话：403/429 →「检查太频繁了…过一会儿再试」、5xx →「GitHub 那边暂时有问题…」。404 仍按"没有 Release = 已是最新"处理。
- 顺带核实：版本比较 `isNewer` 先比 build 号（CI 真实递增号）、退回语义化时逐段数字比较并补零，**没有"字符串比大小"的经典坑**。

- **无障碍欠账清零（20 → 0）**：剩余 20 处一次补完（下载页的按版本号搜索/刷新/安装加载器、模组与存档的详情/删除、编辑器的控件层设置/重置收藏柜、版本管理的刷新/关闭，以及 8 个文件各 1 处）。`_a11y-baseline.json` 从 `{20 处}` 改成 `{}` —— 这条检查从此是**纯回归拦截**，没有任何"允许额度"。
- 累计：`accessibilityLabel` **2 → 49 处**；判据四版演进（`accessibilityLabel` → `Text(` → `Button("标题")` → **结构性判定**）；欠账 **78 → 45 → 33 → 27 → 20 → 0**。

- **无障碍判据改结构性判定，欠账 27 → 20**：抽查发现 `TerracottaScreen` 两处是误报——按钮里其实有 `Text("分享联机核心日志")`，但文字在图标**上方**，超出"往后看 10 行"的窗口。于是不再用行窗口，改为**按大括号取出整个 Button label 块**再判断；改完第一次跑出 30 处（比基线高），抽样发现"往上找 25 行"会跳到无关按钮，补上约束「图片那一行必须在该 Button 块内」后降到 22，再补 4 处标签后到 20。
- 又补的标签：`FileManagerScreen` 返回/更多操作 · `VersionIconPicker` 关闭。剩余 20 处（14 个文件），**只许降**。

- **无障碍欠账 39 → 27**：判据第三次修正 —— `Button(options[i]) { }` / `Button(l) { }` 这类**带标题参数**的按钮本来就有无障碍名（iOS 拿标题当名字），判据补上后真实值再降。又补了 7 处真标签：启动页与微软登录页的关闭、主界面版本设置齿轮、日志复制、收藏、删除布局、重新扫描 Java。剩余 27 处（16 个文件），**只许降**。
- 三次判据修正的共同点：**有名字的方式不止一种**（`Text("…")` / `Button("标题")` / `accessibilityLabel`），只认一种就会把其余全误判成缺失。

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
