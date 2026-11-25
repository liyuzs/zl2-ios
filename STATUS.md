# CraftLauncher 项目状态（诚实版）

> 最后更新：2026-11-08 · 提交数请现查（`git rev-list --count HEAD`）
> 代码：**68 个 Swift 文件** + 核心侧 69 个**自研** `.m`（`core/external/` 第三方不计） + 13 个 jar（5.2 MB）
> 文档：`docs/` 若干篇 + 根目录 6 篇 · 自动化检查：数量与项数以 `_run-all.ps1` 输出为准
> （**第192轮**：原来这里写「`docs/` 31 篇」—— 每次加一篇文档就过时，所以不写篇数了。）

---

## 一、这是什么

把安卓的 **Zalith Launcher 2**（Minecraft Java 版启动器）移植到 iOS。
界面用 SwiftUI 原创重写，启动核心用 **Amethyst-iOS**。

---

## 二、功能状态

> ⚠️ **下面所有"已完成"都是"代码侧完成、逻辑自洽、静态检查通过"，
> 不是"在 iPhone 上跑通了"。这个 App 至今没有任何真机验证。**
> 早期版本这里写「✅ 端到端真实可用」，那是不诚实的——后来在下载链路上
> 一次查出三处静默失败（0 字节文件永不重下、HTML 错误页存成 jar、不校验 SHA-1）。

### 2.1 启动链路（2026-11-08 重点修复）

| 环节 | 状态 |
|---|---|
| Java 侧启动器 jar | ✅ 已补齐（13 个 jar，来自上游 PojavLauncher_iOS 2.2，核对过包名与 JNI 符号） |
| JRE 17 / 21 / 25 | ✅ 三套已打包，按 MC 版本自动选（1.20.5+ 用 21，26+ 用 25） |
| JNI 类 / native 方法 | ✅ 该由本工程实现的全部导出（自动审计） |
| 环境变量 | ✅ `GAME_DIR`/`AME_HOME` 及其 `POJAV_*` 别名都设 |
| 游戏目录 | ✅ 与核心自己算出的路径对齐（`instances/<实例>/.minecraft`） |
| 控制布局 | ✅ `version: 8` + 三个列表齐全，键名表覆盖核心全部 108 个键名 |
| 默认控制布局 | ✅ 首启自动生成（原来那个生成函数从未被调用） |
| **能不能真的启动** | ❓ **未知** —— 必须真机跑 |

### 2.2 下载与安装

| 功能 | 状态 |
|---|---|
| 版本下载 | ✅ 版本 JSON 原样保存 + client.jar（校验 SHA-1）+ libraries（校验 SHA-1）+ assets |
| Fabric 安装 | ✅ 原版先装 → 加载器（`inheritsFrom` 指回原版）→ 可选 Fabric API |
| Quilt 安装 | ✅ 同流程 |
| 模组 / 资源包 / 光影下载 | ✅ 落盘前校验 PK 魔数，识别 HTML 错误页 |
| 模组管理 | ✅ 扫描 `mods/`、解析 jar 元数据 |
| 存档管理 | ✅ NBT + gzip 解析 `level.dat` |
| 服务器列表 | ✅ 真实 Minecraft 状态协议 ping |
| 微软登录 | ✅ 设备码 → XBL → XSTS → MC 档案 |
| 导出整合包 | ⚠️ 只能导出**普通 zip**（把选中文件夹原样打包 + 说明文件）。**不是** CurseForge / Modrinth / MCBBS 清单格式 —— 那几种要联网查 projectID，本地做不到 |

### 2.3 界面与文案

| 项 | 状态 |
|---|---|
| 主题系统 | ✅ 490 个色值（35 角色 × 7 主题 × 亮暗） |
| 中文文案 | ✅ 1536 条（与安卓版一致） |
| 控制布局编辑器 | ✅ 完整实现 + 与 ZL2 JSON 双向互通，真机未测 |
| 环境诊断 | ✅ 五类检查 + 一键复制报告（含"当前用哪个渲染器"） |
| **启动前预检** | ✅ 点启动前逐项查必崩条件（版本配置 / 游戏本体 jar / 依赖库 / 资源索引 / Java 运行时 / 渲染器 / 控制布局 / **JIT 未启用**），**只提示不阻止** |
| **打包日志分享** | ✅ 诊断页与启动失败页各一个入口，一键打包 诊断报告 + ame.log + latest.log + 崩溃报告 + 目录清单 |
| 假交互清理 | ✅ 已系统扫过一遍：无"绑了控件却没人读"的项 |

### 2.3.1 数据安全

| 项 | 状态 |
|---|---|
| 删除操作 | ✅ 存档 / 资源包 / 模组 / 版本 / 游戏目录 / 清空回收站，全部二次确认 |
| 回收站 | ✅ 删除先移到 `.trash/`；占用大小在菜单里可见；**不自动清理** |
| 写入原子性 | ✅ 持久化文件一律 `.atomic`（中途被杀不会留截断文件） |
| 布局覆盖 | ✅ 内容有变化时先备份到 `controlmap/.backup/` |

### 2.4 iOS 硬限制（不是没做，是做不了）

| 功能 | 为什么 |
|---|---|
| Forge / NeoForge | 需运行 `installer.jar`，iOS 禁止 fork 子进程 |
| **MC 1.11 及更早** | 需要 Java 8，而包里只带 17 / 21 / 25。下载页会把这类版本标灰并禁用下载（`CoreBridge.needsUnbundledJava8`） |
| Terracotta 远程联机 | 需 EasyTier P2P 内核 + Network Extension（付费开发者账号）。界面已如实标注「尚未接入」，只保留可用的局域网发现 |
| 按版本隔离游戏目录 | 核心启动时自己算游戏目录、忽略 `GAME_DIR`，改了版本反而找不到。已置灰并写明原因 |
| 上架 App Store | 大陆区不允许此类应用 |

---

## 三、与 ZL2 的数据互通

| 文件 / 概念 | 格式 | 互通 |
|---|---|---|
| 控制布局 JSON | `editorVersion 12` | ✅ 双向导入导出 |
| 坐标系统 | 0~10000 整数千分比 | ✅ 完全对齐 |
| 按钮样式 | light / dark 双套 | ✅ 完全对齐 |
| 点击事件 | 6 种 type | ✅ 完全对齐 |

玩家可以从 ZL2 导出布局，直接导进本 App；反之亦然。

---

## 四、关键文件

```
src/
  ├─ CoreBridge.swift          与 Amethyst 核心的桥（bootstrap / launchVersion / 偏好同步）
  ├─ CoreLayoutExport.swift    ZL2 → Pojav 布局格式转换
  ├─ ZLRenderers.swift         渲染器可用性探测与净化
  ├─ VersionInstaller.swift    版本下载安装
  ├─ LoaderInstaller.swift     Fabric / Quilt 安装
  ├─ ModrinthAPI.swift         Modrinth 搜索下载 + Fabric API 安装
  ├─ VersionRepository.swift   版本仓库 + 目录结构
  ├─ ControlEditor.swift       控制布局编辑器
  ├─ SettingsScreen.swift      设置页（含置灰逻辑）
  ├─ ZLDiagnostics.swift       环境诊断
  ├─ ZLStrings.swift           1536 条文案（安卓源码提取）
  ├─ ZLSettings.swift          115 个设置项（源码提取）
  └─ …（共 70 个文件）

core/                          Amethyst 核心（ObjC/C），69 个自研 .m（+ `external/` 第三方）
core/resources/libs/           Java 侧启动器 jar（主类在 launcher.jar）
core/resources/libs_caciocavallo17/   Java 17+ 的 AWT 工具包
jre/jre{17,21,25}-ios-aarch64.tar.xz  三套运行时（67 MB）
```

---

## 五、构建

```bash
# 本地（需要 macOS + Xcode）
brew install xcodegen && xcodegen generate
xcodebuild -scheme ZL2iOS -configuration Release

# 或推送到 GitHub 自动构建（Actions 会跑 macOS runner）
git push   # 本地分支 master → 线上 main
```

本地可以先用 `_simulate-ci.ps1` 验证装配（JRE + Frameworks + js + log4j + libs + 15 项断言）。

---

## 六、已知问题

1. **真机零验证** —— 所有功能只在编译与静态检查层面通过，没在 iPhone 上跑过
2. **能不能启动未知** —— 启动链路已补齐 19 项致命缺陷，但 `UnsatisfiedLinkError` / 版本 JSON 处理 / 渲染管线只有真机日志能回答
3. **UI 还原度** —— 对照录屏补过 20 处差异，26 个页面做了合并简化
4. **1 个路由没有入口** —— `.room`（`MultiplayerRoomScreen` **已实现并接在路由里**，只是界面没有导航到它的按钮：远程联机需要 Network Extension，等付费开发者账号）。
   **第189轮已在该界面顶部加警示**（「这个功能还没做完 —— 隧道组件需要 Network Extension，当前版本里连不通」）——
   因为将来真有人把它接上入口时，最容易忘的就是"底下还没通"，而用户会看到一个"能点但连不上"的界面。
   **不是"页面没实现"**。第75轮发现过 7 个不可达页面：`ServerListScreen` / `SearchIDScreen` 已接上入口，
   `ExportScreen` / `CrashLogScreen` / `SelectGameVersionScreen` 已删除，`TerracottaScreen`（359 行假页面）第132轮删除，
   其余不可达页面与冗余死路由已清理 —— **现在 `_check-dead-routes.js` 里只剩 `.room` 一个登记**（跑一次看它的输出就知道，别信这里写的数字）。
5. **部分三列布局在手机竖屏上偏挤** —— 如「下载-模组/资源」页（左栏 92pt + 筛选栏 ≤210pt + 结果列表自适应）、「游戏目录」页（左栏 ≤258pt），在 375pt 宽的手机上结果区会偏窄。app 最初按 iPad 设计；**没有视觉反馈的情况下不做盲改**，已把必然溢出的固定宽度（≥280pt）全部改成 `maxWidth`。
6. **`patchjna_agent.jar` 与 `libjnidispatch.dylib` 没放** —— 它们只服务 Forge/NeoForge，而 iOS 不支持 Forge（详见 `docs/缺失组件-Java启动器jar.md`）
7. **没有桌面小组件** —— 项目里有 `ZLSharedStore`（App Group 写入 `widget.version` / `widget.count` / `widget.lastPlayed`），首页每次刷新版本列表时都会写；但**没有 Widget 扩展 target**，所以现在没有任何东西读它。这是为将来加小组件留的骨架，不是已实现的功能。
8. **MC 1.11 及更早不支持** —— 需要 Java 8，包里只带 17/21/25；下载页已把这类版本标灰并禁用
9. **屏幕方向待真机验证** —— 第165轮改了方向配置：**iPhone 允许竖屏**（启动器界面是 `VStack` 竖排设计，
   只给横屏的话用户得横着拿手机操作），游戏内由 `ZLAppDelegate.orientationLock` 在 `launchJVM` 前后切横屏。
   依赖「核心把 root 换成 `SurfaceViewController` 时 UIKit 会重新查询方向」这个行为 —— **真机没验证过**。
   如果游戏画面被裁切/拉伸，就是这个假设不成立，需要补 `windowScene.requestGeometryUpdate`。
   （iPad 仍保持横屏，不受影响。）
10. **"从其他 App 直接分享文件进来"未实现** —— 没声明 `CFBundleDocumentTypes`、也没有 `onOpenURL` 接收，
    所以对方 App 的「用其他应用打开」里不出现 CraftLauncher。
    **能用的路**：`UIFileSharingEnabled` 已开，用「文件」App 把文件拖进 CraftLauncher 的 Documents 文件夹 ✓
    （文件管理器空状态里的提示已按这个事实改过，不再教做不到的操作。）
11. **外置登录（皮肤站）只做了一半 —— 游戏内是离线身份，进不了正版验证的服务器**
    · 会真的调 `/authserver/authenticate` 并**验证邮箱密码** ✓
    · 但只取角色的 `id`/`name`，**丢弃了 accessToken**（拿不到 refresh token）
    · 游戏内仍走 `addOffline` → **离线身份**，进不了需要正版验证的服务器
    · **皮肤能显示**，靠 `authlib-injector`（`-javaagent:...=<server>` 反查皮肤站）
    · 真要支持正版会话，得补 token 存储 + refresh（`Account` 已有 `accessToken`/`refreshToken` 字段，但没被用上）
    （**第190轮已把这一点写进 UI**：登录成功的提示改成「皮肤会显示；但游戏内是离线身份，进不了需要正版验证的服务器」，
    账号列表里的类型标签也从「外置认证」改成「外置认证（离线）」。）

---

## 七、下一步

| 优先级 | 任务 |
|---|---|
| ~~P0~~ | ~~拿到 GitHub token → 推送 → 等 Actions 构建~~ → **已完成（build-243，2026-11-15；token 已存在凭据管理器里，2026-11-23 复核仍有效）** |
| ~~P0~~ | ~~下载新 IPA，替换交付包里那个旧的 `build-235`~~ → **已完成（build-243，2026-11-15）** |
| **P0** | 朋友真机安装 + 启动实测（按 `docs/真机验证清单-给朋友.md`，把 `ame.log` 带回来） |
| P1 | 根据真机日志修剩余问题（最可能是 JNI 接口代际不匹配） |
| P2 | 对齐 ZL2 2.8.2 的新特性（玩家模型渲染、样式柜、拉取刷新） |

---

## 七点五、⚠️ GitHub Actions 的 macOS 额度（2026-11-23 撞上的，症状很骗人）

11 月跑了 **249 次 run**，累计约 **811 分钟真实 macOS**。而 macOS runner 按 **10 倍计费** → **约 8112 计费分钟**，是免费账号 **2000 分钟/月** 额度的 **4 倍**。

**所以 #245 被取消了，但这跟代码没关系。** 辨认方法（记牢，别再为此去查 Swift）：

| 现象 | 说明 |
|---|---|
| run 的 `conclusion` 先是 `cancelled`、过一会儿变 `failure` | 两种状态都见过，别被它带偏 |
| **job 的 `steps` 数是 0** | **一个步骤都没跑** |
| **job 的 `runner_name` 是空** | **没有任何机器领取过它** |
| 拉日志得到 `BlobNotFound` | 日志从来没产生过 |
| 存活时间恰好 ~15 分钟 | 排队超时被系统清掉 |

**看到这五条同时出现 → 是额度/队列问题，不是编译失败。**

**两条出路**：

1. **等到 12 月 1 日**（额度按月刷新）—— 最省事，`master` 上的改动都在。
   **先跑只读的核对脚本**（约 10 秒，不推不建），它会 dry-run 一次推送并打印最近三次 run 的状态：
   ```powershell
   .\scripts\核对推送链路.ps1
   ```
   它说「额度正常」再跑这条真正重建：
   ```powershell
   .\scripts\推送并取回IPA.ps1 -Token "<token>"
   ```
2. **改用 Codemagic**（`codemagic.yaml` 已经写好、11-06 曾成功产出未签名 IPA，免费额度 500 分钟/月）。它比 GitHub Actions **还多两件事**：**模拟器编译 + 截图**、上传到 GitHub Releases。启用需要在 codemagic.io 用 GitHub 登录并授权一次本仓库。

   **第 259 轮已经把它补齐**：这份配置原来**缺版本注入**（产出的包会自称 `1.0.0(1)`，和 build-243 分不清）也**没跑静态检查**。现在步骤顺序是 **静态检查 → 编译核心 → 注入版本号 → 生成工程 → 编译**，注入用 `sed -f > tmp && mv`（BSD sed 不碰 `-i`）。**第 260 轮又补了两道**：`_check-workflow.js` 改成**默认校验全部三条通道**（`build.yml` / `easytier-probe.yml` / `codemagic.yaml` —— 后两条以前从没被看过），并加了**顺序判据**（版本注入必须排在「生成 Xcode 工程」之前，否则改了 `project.yml` 也没用）；`_check-ci-contract.js` 会对比"磁盘上的通道"与"被校验到的通道"，新加一条通道忘了纳入检查会立刻报错。

**没有设备时看界面：这条路当前不通。** CI 里有个「Run in simulator & screenshot」步骤，但 App 在模拟器上
**装不上** —— Amethyst 核心的 4 个 dylib（`AFNetworking` / `AmethystAccountJNI` / `awt_headless` / `tinygl4angle`）
在 `iPhoneSimulator` SDK 下 `linker command failed`，产出的 `ZL2.app` 没有可执行文件（`simctl install` 报
`missing its bundle executable`）。第 563 轮试过删 `OTHER_LDFLAGS`、又试过用 Simulator SDK 单独编核心库，
两种都不行；最终**止损**，只在产物里附一份 `SIMULATOR-READ-ME.txt` 说明那张图是模拟器主屏。
**所以 UI 还原度只能靠真机看** —— 这也是为什么它一直挂在"真机零验证"里。

**当前状态**：交付包里的 `ZL2.ipa` 是 **build-275**（2026-11-25 编译成功，run #275），包含全部 506 个提交的代码。第 259 轮加的"启动次数里程碑彩蛋 / 加载提示扩到 20 条"**还没进任何 IPA** —— 只在本仓库里。

---

## 八、历史里程碑

| 日期 | 事件 |
|---|---|
| 10-31 | 项目启动，8 个 Swift 文件 |
| 11-01 | 接 Amethyst 核心，CI 首次全绿 |
| 11-02 | 主题系统 + 模组/下载页 |
| 11-03 | 对照录屏补 20 处 UI 差异 |
| 11-04 | 系统解析安卓源码（16.6 万行），补 13 个模块 |
| 11-05 | build-235 成功产出 IPA（132 MB） |
| **11-25** | **build-275 成功产出 IPA（137.3 MB，18 步全过）** —— 第 259 轮之后的改动第一次编进包里；真机仍未验证 |
| **11-15** | **build-243 成功产出 IPA（137 MB）—— build-235 之后第一次真正编译，修掉 28 个编译错误 / 4 个检查在无交付包环境的失败** |
| **11-08** | **补 Java 侧启动器 jar、修 19 项致命缺陷、建 25 个自动化检查** |

---

## 九、致谢

- **Zalith Launcher 2** — MovTery 与贡献者（GPL-3.0）
- **Amethyst** — Angel Aura（GPL-3.0）
- **PojavLauncher / PojavLauncher_iOS** — 启动器 Java 侧与 cacio（GPL-3.0）
- **Terracotta** — BurningTNT（GPL-3.0）
- **EasyTier** — 开源 P2P 组网
- **LayerController** — 控件系统
