# CraftLauncher 项目状态（诚实版）

> 最后更新：2026-11-08 · 57 个提交
> 代码：**71 个 Swift 文件** + 核心侧 69 个 `.m` + 13 个 jar（5.2 MB）
> 文档：`docs/` 28 篇 + 根目录 6 篇 · 自动化检查 25 个脚本

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
| 假交互清理 | ✅ 已系统扫过一遍：无"绑了控件却没人读"的项 |

### 2.4 iOS 硬限制（不是没做，是做不了）

| 功能 | 为什么 |
|---|---|
| Forge / NeoForge | 需运行 `installer.jar`，iOS 禁止 fork 子进程 |
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

core/                          Amethyst 核心（ObjC/C），69 个 .m
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
4. **`patchjna_agent.jar` 与 `libjnidispatch.dylib` 没放** —— 它们只服务 Forge/NeoForge，而 iOS 不支持 Forge（详见 `docs/缺失组件-Java启动器jar.md`）
5. **`TerracottaScreen.swift` 是不可达的重复页面** —— 路由没人导航过去，自身已声明为界面演示

---

## 七、下一步

| 优先级 | 任务 |
|---|---|
| **P0** | 拿到 GitHub token → 推送 → 等 Actions 构建 |
| **P0** | 下载新 IPA，替换交付包里那个旧的 `build-235` |
| **P0** | 朋友真机安装 + 启动实测（按 `docs/真机验证清单-给朋友.md`，把 `ame.log` 带回来） |
| P1 | 根据真机日志修剩余问题（最可能是 JNI 接口代际不匹配） |
| P2 | 对齐 ZL2 2.8.2 的新特性（玩家模型渲染、样式柜、拉取刷新） |

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
| **11-08** | **补 Java 侧启动器 jar、修 19 项致命缺陷、建 25 个自动化检查** |

---

## 九、致谢

- **Zalith Launcher 2** — MovTery 与贡献者（GPL-3.0）
- **Amethyst** — Angel Aura（GPL-3.0）
- **PojavLauncher / PojavLauncher_iOS** — 启动器 Java 侧与 cacio（GPL-3.0）
- **Terracotta** — BurningTNT（GPL-3.0）
- **EasyTier** — 开源 P2P 组网
- **LayerController** — 控件系统
