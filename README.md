# ZL2-iOS：把 Zalith Launcher 2 的界面搬上 iPhone

> **界面原型。能编译成 App、能看能点，但还不能启动游戏。**
> 启动核心要接 Amethyst，那是下一阶段的事。

## 这是什么

用 SwiftUI 照着 ZL2（安卓）重画的一套界面。ZL2 的界面是 Jetpack Compose 写的，iOS 上跑不了，**所以这是重画，不是移植**——视觉还原度约 95%，代码一行都没复用。

## 文件清单

```
.github/workflows/build.yml   ← GitHub 云端编译（不用 Mac）
project.yml                   ← XcodeGen 工程定义（iOS 16+）
scripts/check_project.py      ← 静态体检脚本（没编译器时先抓低级错误）

src/  ── 界面层（SwiftUI）
  Theme.swift                 ← 配色、卡片、按钮
  HomeScreen.swift            ← 首页：账户条 + 版本卡片 + 启动键
  AccountScreen.swift         ← 账户：微软/离线/外置认证
  SettingsScreen.swift        ← 设置：渲染器/分辨率/内存/下载源
  DownloadScreen.swift        ← 下载中心：版本列表 + 搜索
  ModsScreen.swift            ← 模组管理 + 前置依赖提示
  LaunchScreen.swift          ← 启动进度页
  ZL2App.swift                ← 入口 + 抽屉 + 控制布局 + 关于

src/  ── 服务层（纯 Foundation，无 UI 依赖）
  AccountService.swift        ← 账户模型、离线 UUID(MD5)、持久化、OAuth 协议
  LaunchContract.swift        ← 启动状态/进度/错误/LaunchService 协议 + Mock 实现
  MojangAPI.swift             ← Mojang 版本清单、版本详情、文件下载（async/await）

docs/
  周末操作手册.md              ← 从注册 GitHub 到装机的完整步骤
  核心集成方案.md              ← 怎么接 Amethyst 启动核心（700 行调研，含源码路径）
STATUS.md                     ← 已完成/未验证/已知问题
```

## 怎么用

**有 Mac**（最快看到效果）：
```bash
brew install xcodegen
cd ios-zl2
xcodegen generate
open ZL2iOS.xcodeproj    # 选模拟器，Cmd+R
```

**只有 Windows**（推荐这条路）：
照 `docs/周末操作手册.md` 走——注册 GitHub → 上传 → Actions 点一下 → 下载 `.ipa` → 发给朋友的 iPhone 装。

## 现在能做什么 / 不能做什么

| 能 | 不能 |
|---|---|
| 看到 ZL2 风格的首页、设置、下载、模组页 | 启动 Minecraft（核心没接） |
| 切换离线账号、改渲染器和内存设置 | 真的下载游戏版本 |
| 拖动控制布局的按键 | 真正连上服务器联机 |
| 编译出可安装的 ipa | 微软正版登录 |

## 许可

界面代码为本项目新写。接入 Amethyst（GPL-3.0）后**整个项目必须 GPL-3.0 开源**，且**不得沿用 "ZalithLauncher" / "ZL" 名称**（Zalith 的 GPL 附加条款要求修改版改名）。


---

## 许可证

本项目遵循 **GNU General Public License v3.0**，见 [LICENSE](LICENSE)。

基于 [Zalith Launcher 2](https://github.com/ZalithLauncher/ZalithLauncher2)（GPL-3.0）
与 [Amethyst](https://github.com/AngelAuraMC/Amethyst-Android)（GPL-3.0）开发。
