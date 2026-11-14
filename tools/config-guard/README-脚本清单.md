# 脚本清单（config-guard）

> 最后更新：2026-11-08（ios-zl2 第 47 轮）
>
> 这个目录里有 **43 个脚本**，但当前真正该跑的只有 **51 个**。
> 剩下的是一次性调查脚本、被替代的旧版本，**以及两个在测「已删除算法」的测试**——
> 后者最危险：它们会安静地输出 ✅，但验证的东西早就不存在了。

---

## 〇、一键跑完（推荐入口）

```powershell
cd C:\Users\21793\.dsh\config-guard
.\_run-all.ps1                  # 跑 35 个快速检查（约 9 秒）
.\_run-all.ps1 -IncludeSimulate # 连 CI 装配模拟一起（50 项，约 13 秒）
.\_run-all.ps1 -Quiet           # 只输出失败的
```

退出码：全通过 0，有失败 1。它内置了下面这份清单，所以「该跑哪些」只有一处权威定义。

---
| `run-checks.js` | **跨平台执行器（不是检查）**：解析 `_run-all.ps1` 里的清单并逐个执行，供 macOS CI 用。清单只有一份来源，避免两份漂移。`node run-checks.js [--with-tests] [--quiet]` |
| `_spot-check.ps1` | **抽查工具（不是检查，手动跑）**：绕过 `_run-all.ps1`，**逐个单跑**清单里的脚本，判定「退出码≠0 **或** 输出里有 ErrorRecord」。存在理由见第122轮：`_check-links.ps1` 因第 2 行有 U+FEFF 而跑不起来，但 PowerShell 报错不终止、退出码仍是 0，`_run-all.ps1` 只看退出码 → **假绿 26 轮**。改过执行器判定、批量改过脚本、或每隔一阵抽查时跑它 |



## 一、当前必跑（每轮改完代码后跑；条数以 `_run-all.ps1` 的输出为准）

| 脚本 | 查什么 |
|---|---|
| `swift-lint.js` | Swift 括号配对（字符串/注释感知） |
| `_check-indentation.js` | 缩进体检：**块内却贴行首**这类排版错（第116轮踩过 —— `if` 缩进跑到第 0 列，而 swift-lint 只验括号配对、照样报绿）。已排除 `case`/`default:`/`@unknown default:`、`]`/`)` 收尾行、多行字符串内容 |
| `_check-interpolation.js` | 字符串插值里拼错的变量名（编译错误，括号检查查不出） |
| `_check-imports.js` | 用了某框架符号却没 import 对应框架（UIKit / CryptoKit / Compression / PhotosUI / AVFoundation） |
| `_check-call-labels.js` | 调工程内类型的方法时参数标签与声明对不上（如 `requiredJavaVersion(for:)` vs `(_:)`）—— 没有编译器时的编译前置检查 |
| `_check-error-hints.js` | 面向用户的失败提示必须带「怎么办」：`ZLPreflight` / `ZLDiagnostics` 里每条 `level: .fail` / `.warn` 的 `ZLDiagItem` 都要有非空 `advice:`（界面会把它显示在红字下方） |
| `_check-error-locale.js` | 错误翻译必须**优先按错误码**判断（`NSURLErrorDomain` / `URLError.Code`），`localizedDescription` 的文本匹配只能作补充。第145轮发现 `ZLFriendlyError` 原来全靠文本匹配，而中文系统上它已经是中文（"请求超时。"）→ **9 条映射全部失效**，用户看到"请求超时。（错误码 -1001）" |
| `_check-guide-claims.js` | 引导/提示里**教的操作必须有实现**：一张「说法 → 代码证据」表（长按卡片提起、长按空白新建、预览、收藏柜、新建控件层…），文案提到但代码里找不到就报。⚠️ 只覆盖表内条目，不是完备证明 |
| `_check-duplicates.js` | 顶层类型重复声明（Invalid redeclaration）。按花括号深度只查顶层，嵌套的 `CodingKeys` / `Kind` 不误报 |
| `_audit-ui-affordance.js` | 假交互：绑了控件却没人读的 `@State`、常量+空 set 的 Binding |
| `_check-orphan-views.js` | 写了没挂载：`struct X: View` 在整个 src 里只出现 1 次（从没被实例化） |
| `_check-dead-types.js` | 零使用的顶层类型：标识符在整个 src 只出现 1 次（连自己文件都没用）。**排除框架隐式实例化的**（`@main` App / `AppShortcutsProvider` / `NEPacketTunnelProvider` / `UIApplicationDelegate` / SceneDelegate），否则会把 App 入口当死代码 |
| `_check-dead-routes.js` | 死路由：`AppRoute` 的 case 没有任何导航调用（append / onOpen / NavigationLink）。① 新增死路由判失败；② 已知的登记在 ALLOW；③ **对每个已知死路由，还会打印它的目的地上挂了什么**（修饰符 `xxx(...)` / 内部 `path.append` / `onOpen`）——因为挂在没人走的路由上的东西也永远不生效（第78轮实例：`.zlGuide(.controlEditor)` 编辑器首导挂错地方） |
| `_check-pending-action.js` | 快捷指令待处理动作的结构完整性：唯一写入口 setRoute、consumeRoute 有过期判断、除 setRoute 外不许直接写 zl.pendingRoute、RootView 同时有冷启动与前台两条消费路径 |
| `_check-fixed-widths.js` | 布局溢出：`.frame(width: N)` 里 N ≥ 280 必然超出手机竖屏（最窄 320pt − 两侧 18pt） |
| `_check-startup-io.js` | 首屏性能：断言 `listVersions` 默认 `includeSize: false`、且 `directorySize` 受它门控。第124轮发现首页 `onAppear` 会**递归扫全部版本目录算大小**（而大小只有版本列表一处显示）。本地没真机测不了耗时，只能静态守住默认值 |
| `_check-hotpath-cost.js` | 高频位置开销，覆盖**三层**：①`body`/computed var（每次重绘）②`.onChange`（每次值变）③`ForEach`（每行）—— 里面不许出现 `listVersions` / `directorySize` / 目录枚举 / JSON 解码 / 读文件。**豁免** `.task`/`.onAppear`/`.sheet` 等副作用闭包内部（那是正确写法）。实测 228 渲染块 + 23 onChange + 98 ForEach，0 处 |
| `_check-a11y.js` | 图标按钮无障碍：统计"Button 里只有 Image、又没有 accessibilityLabel"的数量，**只许降不许升**（基线在 `_a11y-baseline.json`）。第110轮补了顶栏 5 个 + 主界面 4 个导航入口的标签，其余 78 处记为已知欠账 |
| `_check-hstack-budget.js` | 横向预算：同一 `HStack` **直接子层**多个固定宽度之和 ≥288pt（375pt 屏可用 339pt 的 85%）就报。⚠️ 只看内联块，写在 computed property 里的宽度追不到（已在文件头写明） |
| `_check-dark-mode.js` | 深色模式链路：`ZLPalette.color` 必须会按 darkMode 把 `…Light` 换成 `…Dark`；RootView 必须把系统 colorScheme 同步给 ThemeManager；色板 Light/Dark 两组键必须成对 |
| `_check-trademark-strings.js` | 命名合规：界面字符串不得把 App 自称 `ZL2` / `ZalithLauncher`（README 声明的 GPLv3 第 7 条）；上游署名、格式名、Bonjour 服务名等例外逐条登记理由 |
| `_check-license-page.js` | 许可页 ↔ 实际打包内容：`Frameworks/`、`libs/*.jar`、`jre/` 里每个第三方都要在「关于与开源许可」页有署名；页面里列了但仓库没文件的也要报（第103轮：漏了 AltKit / FreeType / shaderc / Gson / jsr305 与 Java 21/25，还错列了不存在的 MobileGlues） |
| `_check-readme-claims.js` | README 里能机器验证的声明（内存比例 / 视距 / GC 参数 / 支持版本区间）必须与代码实现一致 |
| `_check-settings-audit.js` | 设置项审计文档 ↔ 代码集合：`docs/设置项审计.md` 总览表三个数字与 `设置项接线进度.md` 的「现在 N 项」，必须等于 `ZLSettings` 115 项对撞 `ZLUnsupportedSettings` 的结果 |
| `_check-settings-wiring.js` | 设置项落地归属：115 项里"可用"的 30 项，每项必须有归属（核心桥接 / Swift 消费 / 内部状态位白名单）。第135轮实测 10 桥接 + 16 消费 + 4 内部位，0 项无归属。**这条替代了 `_audit-stores.js` 的方向**——后者抓字面量键，而设置实际走 `ZLSettingsStore.set` 的**动态键**，抓不到 |
| `_check-settings-entry.js` | 可用设置项是否有**UI 入口**（与 `_check-settings-wiring` 互补：那个查代码层消费，这个查用户能不能改）。第148轮实测：30 项 = 21 UI 控件 + 4 自动写入 + 1 手势 + 4 内部记账 + **没入口 0** |
| `_check-number-range.js` | 用 `number(...)` 自由输入的设置项**必须有 `range`**。第151轮发现 `range` 字段只被 slider 的 min/max 用过，写入路径 `store.set(_:_: Int)` **完全不 clamp** → 分辨率宽高能存 0 / 负数 / 99999999（传给 JVM 是"渲染尺寸 0"或"分配巨大缓冲"）。已给 `set(Int)` 加统一 clamp + 分辨率两项补 `range: 0...7680` |
| `_check-setting-defaults.js` | 设置项默认值只有一处来源：全仓不许出现 `defaultWhenUnset`；`boolValue/intValue/stringValue(_ key:)` 必须委托给 `store.xxx(`（由 ZLSettings 的 `defaultValue` 兜底） |
| `_check-path-safety.js` | 路径拼接安全：处理远端数据/用户输入的 5 个文件里，用变量拼路径的那一行必须用到 `ZLPathSafety` 校验后的变量（或内联调用）；已知安全例外登记理由 |
| `_check-download-magic.js` | "下载后写盘"必须校验内容（魔数或哈希）。第150轮补三个漏网的：`ZLYggdrasil.downloadSkin`（PNG 只判 >100 字节）· `ZLYggdrasil.ensureDownloaded`（authlib jar 只判 >100KB，HTML 错误页会被存成 jar → `-javaagent` 指向无效 jar → JVM 起不来）· `LoaderInstaller`（库 jar 直接写盘）。`MojangAPI` 在 ALLOW（通用流式下载器，有更强的 size 截断检测） |
| `_check-decode-recovery.js` | 解码失败必须备份：4 个持久化文件有 `try? 解码` 就必须调 `ZLRecovery.preserveRawData`；全仓兜底扫"从 UserDefaults 取 data 再 try? 解码但没备份"的写法（判据前先剥注释，否则助手文件自己的注释会误报） |
| `_check-install-docs.js` | 三份安装文档一致性：都必须提 JIT 与 StikDebug；只在一份里出现的工具名（孤例）会被报出来 |
| `_check-layout-keys.js` | 布局导出键 ↔ 核心读取：`d["键"]=` 里每个键都要在 core 源码里出现；核心不认的必须登记理由（现有 4 个：textSize / joystickColor / joystickSize / pressedBgColor） |
| `_check-destructive-confirm.js` | 数据安全：`role: .destructive` 的按钮不得直接调用执行 `removeItem` 的函数，必须由确认弹窗接手 |
| `_check-atomic-writes.js` | 数据完整性：写持久化文件必须原子（`.atomic` / `atomically:`），否则中途被杀会留下截断文件；临时/暂存目录除外 |
| `_audit-jni-natives.js` | Java 声明的 native vs 核心导出的符号（真解析 class 取 ACC_NATIVE） |
| `_audit-jni-classes.js` | 核心 `FindClass` 找的类在不在 jar 里（缺失又没判空 = 必崩） |
| `_audit-env.js` | Java 侧引用的环境变量 vs 我们 `setenv` 的 |
| `_audit-prefkeys.js` | `setPref*` 的键在不在 PLPreferences 默认字典里（未定义会静默失败） |
| `_audit-stores.js` | 三套存储**双向**对撞：①写了 UserDefaults 但核心在别处读 ②从 UserDefaults 读了核心拥有的键（永远拿到默认值） |
| `_check-runtime-assets.js` | jar / JRE / js / 动态库齐不齐 |
| `_audit-orphan-core.js` | 核心零引用的初始化类函数（写了没人调） |
| `_audit3.ps1` | 设置项读写审计（115 项分类） |
| `_check-workflow.js` | GitHub Actions YAML 结构 |
| `_check-ci-contract.js` | 推送脚本 ↔ CI workflow 的契约：脚本等待时间不得短于 CI 的 `timeout-minutes`；脚本必须认识 CI 上传的 artifact 名；CI 必须真的产出 `.ipa`；CI 有静态检查时脚本的失败提示要提到它 |
| `_check-links.ps1` | 文档内部死链 |
| `_check-checklist-logs.js` | 验证清单里让用户搜的日志文案，在代码里是否真的存在（改了文案会静默失效） |
| `_check-doc-stats.js` | README / STATUS 的规模数字（Swift 文件数 / 核心 `.m` 数 / jar 数）是否等于实际；行数与体积是假精度不查 |
| `_check-hardcoded-stats.js` | 界面文案不许写死系统规模数字（「N 个 Swift 文件」这类一定会过时）。第102轮从彩蛋里抓出一句"这个启动器用了 55 个 Swift 文件"（实际 70） |
| `_check-hardcoded-versions.js` | 用户可见字符串里不许有**硬编码版本号**。第141轮首页 `Text("1.20.1 · Fabric 0.19.2")`、第142轮关于页 `Text("com.pi.phux.mobileglues · 1.3.4")` 都是这类——装什么版本都显示同一行。判据：`Text`/`Label`/`LabeledContent` 等可见字符串含 `1.20.1` 格式且**不含中文** → 报；含中文的多半是说明文字，只提示。许可证名（GPL-3.0 等）在 ALLOW |
| `_check-script-inventory.js` | 脚本清单完整性（双向）：磁盘上每个脚本都要在清单里出现；清单与仓库文档里提到的脚本必须真的存在 |
| `_check-check-metadata.js` | **检查自己的元数据**：每个 `_check-*.js` 的头部注释里必须写明「**局限**」（只认哪些写法、判不了什么、什么时候该来改它）。第135轮的教训是 `_audit-stores.js` 因代码改成动态键而悄悄失明、却一直报绿 110 多轮。存量用**基线冻结**（当前 29/40 未写，只许降不许升） |
| `_paths.js` / `_paths.ps1` | **路径解析助手（不是检查）**：让脚本不写死 `D:\ios-zl2`。解析顺序：环境变量 `ZL2_REPO` → 从脚本位置向上找 `project.yml` → 本机默认值。JS 用 `require('./_paths')`，PS1 用 `. "$PSScriptRoot\_paths.ps1"` |
| `_check-delivery-docs.js` | 交付包里的文档必须在仓库有来源（不许"孤本"），且副本内容必须与仓库一致（漏同步会报） |
| `_check-delivery-index.js` | 交付包入口说明的完整性（双向）：交付包里每个文件都要在「从这里开始.md」里出现；说明里提到的文件必须真的存在 |

## 二、契约测试（改了对应模块才需要跑）

| 脚本 | 覆盖 |
|---|---|
| `_test-keynames.js` | 核心 108 个键名 vs `GLFWKeyNames`（119 条） |
| `_test-layout-contract.js` | 布局格式契约：version / 三个列表（13 条） |
| `_test-gamedir.js` | 我们装的路径 vs 核心算的 gameDir（6 条） |
| `_test-java-version.js` | MC 版本 → Java 大版本（50 条，含 1.20.5 分界） |
| `_test-jre-select.js` | 完整仿真「MC 版本 → minJava → 最终 JRE」（47 条） |
| `_test-version.js` | 版本号比较（21 条） |
| `_test-renderers.js` | 渲染器净化（58 条，含「输出必定在包内」不变量） |
| `_test-pseudo-v2.js` | **现行**伪键码方案（`threshold - action*1000 - (index+1)`） |
| `_check-picker.js` | 各处 `picker(...)` 调用的参数个数 |
| `_test-glfw.js` | GLFW 键名用例（23 条） |
| `_test-joystick.js` | 摇杆方向键码 32 槽位 |
| `_test-preflight.js` | 启动前预检的契约：布局名必须从核心偏好读、jar 检查要考虑 inheritsFrom、只提示不阻止（11 条） |
| `_test-msauth-poll.js` | 微软设备码轮询契约：slow_down 必须提高间隔、间隔必须可变、必须有 deadline、未知错误要留痕（7 条） |
| `_test-motd.js` | MOTD 三种形态（纯字符串 / text 对象 / text+extra）都能解析出文本（11 条） |

## 三、模拟（改 CI 之后跑）

| 脚本 | 覆盖 |
|---|---|
| `_simulate-ci.ps1` | 完整装配：JRE 17/21/25 + Frameworks + js + log4j + libs 三目录 + 15 项断言 |

## 三、五、生成器（不是检查，手动跑）

| 脚本 | 作用 |
|---|---|
| `_gen-settings-audit.js` | 读 `ZLSettings` 的 115 项与 `ZLUnsupportedSettings` 的四个集合，**重新生成 `docs/设置项审计.md`**。改完集合跑一遍，`_check-settings-audit.js` 会核对文档数字有没有跟上 |

> 生成器和检查要成对存在：检查保证"文档没落后于代码"，生成器保证"落后了能一键追上"。

---

## 四、⚠️ 已退役 —— **别跑，跑了会有误导**

### 4.1 在测「已删除的设计」（最危险）

| 脚本 | 为什么不能跑 |
|---|---|
| `_test-pseudokey.js` | 测的是**已废弃的 FNV 哈希**方案（`encode(uuid)` → `hash % 900000`）。现行实现是顺序编号 `encode(index:action:)`，完全不哈希。跑了会输出一堆 ✅，但验证的东西不存在 |
| `_test-hash-compare.js` | 对比几种哈希方案的碰撞率 —— 那个决策早做完了，结论是「根本不该用哈希」 |

### 4.2 被新版本替代

| 退役脚本 | 替代者 |
|---|---|
| `_audit2.ps1` | `_audit3.ps1`（补了六种读取模式，LEAK 从 12 降到 4） |
| `_audit-settings.ps1` | `_audit3.ps1` |
| `_audit-flags.ps1` | `_audit-ui-affordance.js`（结构探针，覆盖面更广） |
| `_lint.ps1` | `swift-lint.js`（`_lint.ps1` 是正则版，会被字符串里的 `{` `(` 误报） |

### 4.3 一次性调查（结论已落地，脚本不必再跑）

| 脚本 | 当时查什么 |
|---|---|
| `_check.ps1` | ZLStrings 文案一致性 |
| `_check-props.ps1` | `ControlLayoutModel` / `CoreLayoutExport` 属性存在性 |
| `_check-flag-detail.ps1` | 逐个确认哪些「设了标志没人监听」 |
| `_verify-chain.ps1` | FPS 链路八环节完整性 |
| `_verify-r6.ps1` / `_verify-r7.ps1` | 第 6 / 7 轮的接线验证 |
| `classify.js` | 分析 78 个未标注 key 在 iOS 上是否适用（结论已写进 `ZLUnsupportedSettings`） |
| `_test-convert.js` | 早期验证布局换算；现在由 `_test-layout-contract.js` 覆盖契约层 |

## 五、与本项目无关

| 脚本 | 说明 |
|---|---|
| `dsh-config-guard.ps1` | **DSH 自己的配置守护进程**（每 20 秒检查 `cordis.patch.yml`），与 ios-zl2 无关。不要在这个目录里顺手跑它 |

---

## 六、加新脚本的约定

1. 放进这个目录，命名带前缀：`_check-` 检查 / `_audit-` 审计 / `_test-` 契约测试 / `_simulate-` 模拟
2. **头部第一行写清它查什么、判据是什么、什么时候该跑**
3. 有豁免/白名单的，必须写明"为什么可以豁免"——否则未来的你（或别人）会当它是遗漏
4. 退役时在本文档登记，并在脚本头部加一行「⚠️ 已退役：<原因>，替代者：<脚本名>」
5. `.ps1` 必须存成 **UTF-8 带 BOM**（PowerShell 5.1 无 BOM 时按 GBK 解码，中文乱码且吃掉引号）
