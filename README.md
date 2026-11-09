# CraftLauncher · 在 iPhone / iPad 上玩 Minecraft Java 版

> **非官方 iOS 移植版**，基于 [Zalith Launcher 2](https://github.com/ZalithLauncher/ZalithLauncher2) 重新实现的 SwiftUI 界面 + [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) 启动核心。

**作者：liyuzs** · 界面代码为原创重写（**69 个 Swift 文件**），交互与布局参照 ZL2

> **想快速了解项目现状？** 读 [STATUS.md](STATUS.md)（诚实版功能状态）和
> [HANDOFF-20261108.md](HANDOFF-20261108.md)（交接文档：改了什么、验证了什么、下一步）。
> **一句话**：代码侧已修掉 19 项致命缺陷，但**从未在任何 iPhone 上跑通过**，真机验证是下一步。

---

## 声明

本项目是 **社区非官方修改版**，与 Zalith Launcher 官方**没有任何关系**，不代表官方立场。

依据 Zalith Launcher 2 的 GPLv3 附加条款（第 7 条）：

- ✅ 本项目**不以** `ZalithLauncher` 或其缩写 `ZL` 作为名称
- ✅ 主界面已标注「非官方 iOS 移植版」
- ✅ 完整保留原作者版权声明（见 `LICENSE` 与「关于」页）

---

## 它能做什么

| 功能 | 状态 |
|---|---|
| 下载游戏版本（**1.12 ~ 26+**） | ✅ 1.11 及更早需要 Java 8，包里没带，下载页会标灰 |
| 启动游戏 | ✅ 需配合 JIT |
| Fabric / Quilt 模组加载器 | ✅ |
| 模组 / 资源包 / 光影管理 | ✅ |
| 存档管理、服务器列表 | ✅ |
| **键位编辑器**（对齐 ZL2 的 JSON 格式） | ✅ |
| 游戏内菜单（双栏布局，照源码重写） | ✅ |
| 微软账号登录 / 离线账号 | ✅ |
| **局域网联机**（同一 WiFi 自动发现） | ✅ |
| 7 套主题换肤 | ✅ |
| 远程联机（EasyTier） | 🚧 待接入 |

## 性能

核心层真实生效的优化：

- 渲染器走 **Metal / ANGLE**（iOS 上最快的路径）
- **G1GC** + `-XX:MaxGCPauseMillis=20`
- **JIT 常驻**（避免反复挂载卡顿）
- 首次启动写入低画质 `options.txt`（视距 4、粒子最少、快速画质）
- **内存默认按物理内存 25% 自动分配**（核心的默认值）；如果你手动指定，上限会压到 50% 防止 OOM

> **必须开 JIT**：用 **StikDebug** 给本应用启用 JIT 后再启动游戏，否则帧率个位数。

---

## 怎么装（免费，7 天续签）

**需要**：iPhone（iOS 16+）、一台电脑（只用一次）、一个免费 Apple ID

先下载 IPA：[Actions](https://github.com/liyuzs/zl2-ios/actions) → 最新的 `ZL2.ipa`。

三条安装路线，按省事程度排（**完整截图步骤见 [安装教程-超详细](docs/安装教程-超详细.md)**）：

| 路线 | 适合 | 代价 |
|---|---|---|
| **TrollStore** | iOS 14 – 17.0 | 装一次永久可用，JIT 自动开（最省事） |
| **SideStore** | iOS 16+ | 第一次要电脑配合，之后手机上就能续签 |
| **Sideloadly** | 都行 | 最简单，但每 7 天要连电脑重签 |

**装完必做**：用 [StikDebug](https://stikdebug.xyz/) 给本应用启用 JIT，否则帧率个位数。

> 免费签名 7 天过期（TrollStore 除外）。装 SideStore 后可以自动续签，不用手动管。

---

## 已知限制

- **Forge / NeoForge 装不了**：需要跑 installer.jar，iOS 做不到。请用 Fabric 或 Quilt
- **性能天花板**：iOS 的 JIT 权限比安卓严，原版 1.20 约 25-40 FPS
- **远程联机**需要 Network Extension 权限，等付费开发者账号才能接

---

## 文档导航

这个项目的文档比较多，按用途分三类：

| 你是 | 从这看 |
|---|---|
| **想装来玩** | [安装教程-超详细](docs/安装教程-超详细.md) → [真机验证清单](docs/真机验证清单-给朋友.md) |
| **想接手开发** | [体检报告](docs/体检报告-20261108.md) → [STATUS](STATUS.md) → [文档索引](docs/README-文档索引.md) |
| **遇到具体问题** | [文档索引的「按问题找文档」表](docs/README-文档索引.md#五按问题找文档) |

**完整索引**：[docs/README-文档索引.md](docs/README-文档索引.md)（24 篇文档的分组导航）

---

## 当前状态（2026-11-08）

| 项目 | 状态 |
|---|---|
| 代码规模 | **69 个 Swift 文件** + 核心侧 69 个 `.m` + 13 个 jar |
| 设置项 | 115 项中 36 项真正生效，75 项明确标注不可用 |
| 已修缺陷 | **19 项致命/高危**（缺 Java 启动器 jar、控制布局格式、JNI 未导出、下载静默失败等） |
| 自动化检查 | **25 个脚本**（语法 / JNI 契约 / 偏好键 / 假交互 / 资源完整性 / 文档死链…） |
| 构建 | 装配流程本地验证 15/15；CI 已修复 JRE 源问题 |
| **真机验证** | ⚠️ **尚未在任何 iPhone 上跑通过** |

最后一条最重要 —— 这个 App 能编译、结构完整、静态检查全绿，
但**游戏能不能真的启动仍然是未知的**。差的就是推上去构建一次、在真机上跑一次。

如果你试了，欢迎反馈：App 内「设置 → 环境诊断」可以一键复制报告，
`Documents/ame.log` 里有详细日志（对照 [真机验证清单](docs/真机验证清单-给朋友.md) 里那张表能直接看出是哪一层的问题）。

---

## 许可证与致谢

**GPL-3.0**（继承上游）。可以自由使用、修改、分发，但必须：

1. 保留原作者署名
2. 同样以 GPL-3.0 开源
3. 遵守上游的附加条款（改名 + 标注非官方）

**致谢**：

- [Zalith Launcher 2](https://github.com/ZalithLauncher/ZalithLauncher2) —— MovTery 及贡献者，界面与交互的参考来源
- [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) —— Angel Aura MC，iOS 上的 Java 运行环境
- [PojavLauncher](https://github.com/PojavLauncherTeam/PojavLauncher) —— 移动端启动器的鼻祖
- MC 百科社区
