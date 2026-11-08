# CraftLauncher · 在 iPhone / iPad 上玩 Minecraft Java 版

> **非官方 iOS 移植版**，基于 [Zalith Launcher 2](https://github.com/ZalithLauncher/ZalithLauncher2) 重新实现的 SwiftUI 界面 + [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) 启动核心。

**作者：liyuzs** · 界面代码为原创重写（55 个 Swift 文件），交互与布局参照 ZL2

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
| 下载任意游戏版本（1.8 ~ 26+） | ✅ |
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
- 首次启动写入低画质 `options.txt`（视距 4、关粒子阴影）
- 内存按物理内存 1/3 自适应

> **必须开 JIT**：用 **StikDebug** 给本应用启用 JIT 后再启动游戏，否则帧率个位数。

---

## 怎么装（免费，7 天续签）

**需要**：iPhone（iOS 16+）、一台电脑（只用一次）、一个免费 Apple ID

1. **下载 IPA** —— 到 [Actions](https://github.com/liyuzs/zl2-ios/actions) 下载最新的 `ZL2.ipa`
2. **电脑签名** —— NB 全能助手（中文，推荐）或 iLoader
3. **手机信任** —— 设置 → 通用 → VPN与设备管理 → 信任证书
4. **开 JIT** —— 装 StikDebug，选中本应用 → 启用 JIT
5. **玩**

> 免费签名 7 天过期。装 SideStore 后自动续签，不用手动管。

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

经过九轮系统改造：

| 项目 | 状态 |
|---|---|
| 代码规模 | 67 个 Swift 文件 / 33,198 行 |
| 设置项 | 115 项中 36 项真正生效，75 项明确标注不可用 |
| 已修 Bug | 4 个致命 + 数十个功能缺陷 |
| CI | 已修复 JRE 源问题，可正常构建 |
| **真机验证** | ⚠️ **尚未在任何 iPhone 上跑通过** |

最后一条最重要——这个 App 能编译、结构完整，但**游戏能不能真的启动还是未知的**。
如果你试了，欢迎反馈（App 内「设置 → 环境诊断」可以一键复制报告）。

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
