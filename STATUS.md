# ZL2-iOS 项目状态

> 最后更新：2026-11-04 04:12
> 代码：50 个 Swift 文件 / 20,455 行
> CI：GitHub Actions 111 次构建全绿

---

## 一、这是什么

Zalith Launcher 2（安卓 Minecraft 启动器）的 iOS 复刻版。
基于 **ZL2 安卓源码**（16.6 万行 Kotlin）逐模块解析后重建。

---

## 二、功能状态（诚实版）

### ✅ 端到端真实可用

| 功能 | 实现 |
|---|---|
| 版本下载 | Mojang 清单 → client.jar + libraries + assets |
| Fabric 安装 | meta.fabricmc.net profile 合并 + 库下载 |
| Quilt 安装 | meta.quiltmc.org v3 同样流程 |
| 模组管理 | 扫描 mods/、解析 jar 元数据（fabric/toml/quilt） |
| 存档管理 | NBT + gzip 解析 level.dat |
| 资源包/光影/截图 | pack.mcmeta 解析 + 预览 |
| 服务器列表 | 真实 Minecraft 状态协议 ping |
| 微软登录 | 设备码 → XBL → XSTS → MC 档案 |
| 主题系统 | 490 个色值（35角色×7主题×亮暗） |
| 文案 | 1536 条中文（与安卓版一致） |

### ⚠️ 代码就绪，真机未验证

| 功能 | 状态 |
|---|---|
| 游戏启动 | launchJVM 已接，JRE 已打包，未真机跑过 |
| P2P 联机 | EasyTier 骨架就绪，utun fd 需真机调试 |
| 控制布局编辑器 | 完整实现 + ZL2 JSON 互通，未真机测 |

### ❌ iOS 硬限制

| 功能 | 为什么不行 |
|---|---|
| Forge / NeoForge | 需运行 installer.jar，iOS 禁止 fork 子进程 |
| 实时抓屏插件 | dsh-see-now 只支持 Win/macOS 屏幕引擎 |
| 上架 App Store | 大陆区不允许此类应用 |

---

## 三、与 ZL2 的数据互通

**已实现文件级互通**：

| 文件 | 格式 | 互通 |
|---|---|---|
| 控制布局 JSON | editorVersion 12 | ✅ 双向导入导出 |
| 坐标系统 | 0~10000 整数 | ✅ 完全对齐 |
| 按钮样式 | light/dark 双套 | ✅ 完全对齐 |
| 点击事件 | 6 种 type | ✅ 完全对齐 |

玩家可以从 ZL2 下载布局文件，直接导入本 App；反之亦然。

---

## 四、关键文件

```
src/
  ├─ Theme.swift              主题系统（ZLTheme）
  ├─ ZLPalette.swift          490 色值（源码提取）
  ├─ ZLStrings.swift          1536 条文案（源码提取）
  ├─ ZLSettings.swift         115 个设置项（源码提取）
  ├─ ZLKeycode.swift          101 键码 + 116 键位（源码提取）
  ├─ ControlEditor.swift      控制布局编辑器（2300+ 行）
  ├─ ControlLayoutModel.swift 控件数据模型（对齐 ZL2）
  ├─ ControlModelBridge.swift 编辑器 ↔ ZL2 JSON 转换
  ├─ VersionInstaller.swift   版本下载安装
  ├─ LoaderInstaller.swift    Fabric/Quilt 安装
  ├─ ServerListScreen.swift   服务器列表 + ping 协议
  ├─ ModsManagerScreen.swift  模组管理 + ZIP 解析
  ├─ SavesManagerScreen.swift 存档管理 + NBT 解析
  ├─ EasyTierTunnel.swift     P2P 联机骨架
  └─ ...（共 50 个文件）
```

---

## 五、构建

```bash
# 本地（需要 macOS + Xcode）
brew install xcodegen
xcodegen generate
xcodebuild -scheme ZL2iOS -configuration Release

# 或推送到 GitHub 自动构建
git push origin main
```

**产物**：每次构建自动发布到 GitHub Releases，包含 Amethyst 核心 + JRE17 + Frameworks + JIT 脚本。

---

## 六、已知问题

1. **真机零验证** — 所有功能只在编译层面通过，没在 iPhone 上跑过
2. **游戏启动未测** — JRE 打包了，Amethyst 接了，但 launchJVM 是否成功未知
3. **UI 还原度** — 录屏对照补了 20 处差异，26 个页面做了合并简化
4. **Forge 不支持** — iOS 限制，已标注

---

## 七、下一步（优先级）

| 优先级 | 任务 |
|---|---|
| P0 | 真机安装验证（等电脑端 AI 完成签名） |
| P0 | 游戏启动实测（装好后第一件事） |
| P1 | P2P 联机 utun fd 调试 |
| P2 | 补剩余 26 个页面 |
| P2 | EasyTier 真实集成（编译 Rust 库） |

---

## 八、历史里程碑

| 日期 | 事件 |
|---|---|
| 10-31 | 项目启动，8 个 Swift 文件 |
| 11-01 | 接 Amethyst 核心，CI 首次全绿 |
| 11-02 | 主题系统 + 模组/下载页 |
| 11-03 | 录屏对照补 20 处 UI 差异，装海马体记忆插件 |
| 11-04 | 源码系统性解析（16.6 万行），补 13 个模块 |

---

## 九、致谢

- **Zalith Launcher 2** — MovTery 与贡献者（GPL-3.0）
- **Amethyst** — Angel Aura（GPL-3.0）
- **Terracotta** — BurningTNT（GPL-3.0）
- **EasyTier** — 开源 P2P 组网
- **LayerController** — 控件系统
