# ZL2-iOS 交接文档

> 生成时间：2026-11-04
> 用途：本会话上下文过长导致输出退化，新会话请先读这份文档

---

## 一、项目是什么

把安卓的 **Zalith Launcher 2**（Minecraft Java 版启动器）完整复刻到 iOS。

- 仓库：`/root/workspace/ios-zl2`（git，远程 `github.com/liyuzs/zl2-ios`，已**公开**，GPL-3.0）
- 源码参考：`/tmp/zl2`（ZL2 安卓源码的稀疏检出）
- 当前代码量：**50 个 Swift 文件 / 约 20,600 行**
- 最近提交：`7a2b8f0`

## 二、已经完成什么

### 数据层（100% 从源码提取）
| 内容 | 数量 | 文件 |
|---|---|---|
| Material3 主题色 | 490 个色值（35 角色 × 7 主题 × 明暗） | `ZLPalette.swift` |
| 中文文案 | 1,536 条 | `ZLStrings.swift` |
| 启动器设置 | 115 项（含默认值与范围） | `ZLSettings.swift` |
| 键位表 | 101 个 GLFW keycode + 116 个按键规格 | `ZLKeycode.swift` |
| 控件模型 | LayerController 全部字段 | `ControlLayoutModel.swift` |

### 功能层（真实可用）
- 版本下载安装（Mojang manifest → jar → libraries → assets，8 并发）
- Fabric / Quilt 安装（真实 maven 解析）
- 模组管理（自写 ZIP 解析 + jar 元数据）
- 存档管理（gzip + NBT 解析 level.dat）
- 服务器列表（真实 Minecraft 握手/状态协议）
- 资源包 / 光影 / 截图管理
- 联机（房间码 3 种格式解析 + 状态机 + EasyTier 骨架）
- 游戏覆盖层（性能球、FPS 图、控制按钮）
- 控件编辑器（拖拽、属性面板、图层、导入导出 ZL2 JSON）

### 已修的关键 bug
1. **GAME_DIR 路径不一致** → 装好的版本找不到，启动必失败
2. **launchJVM 用户名传 nil** → argv 中间插 NULL，崩溃
3. **按键事件退化成"发送文本"** → 导入 ZL2 布局后所有按键变哑
4. **版本 JSON 只存 5 个字段** → 丢 arguments/javaVersion，启动必失败
5. **JIT 脚本没打包** → iOS 26 启动必崩
6. **assets 只下索引** → 游戏没声没语言
7. **进度条按阶段归零** → 来回跳
8. **java.java_homes 每次覆盖** → 抹掉用户的 JRE 选择

## 三、当前的阻塞

### GitHub Actions 不可用
- 账户欠费 **$19.11**（macOS runner $0.08/分钟，跑了 129 次构建）
- 报错原文：`The job was not started because recent account payments have failed or your spending limit needs to be increased`
- **解决**：要么绑卡付钱，要么改用 Codemagic

### Codemagic（已配置，未验证）
- `codemagic.yaml` 已经写好并推送
- 免费额度：个人账号每月 **500 分钟** macOS M2
- 需要用户在 codemagic.io 上手动触发第一次构建
- **风险**：`xcode: latest` 可能不兼容，可能需要指定 `xcode: 16.0`

## 四、待办（按优先级）

### P0 — 真机验证
- [ ] 用 Codemagic 构建出 IPA
- [ ] 装进 iPhone（SideStore / Sideloadly 签名）
- [ ] 验证游戏能否启动（`launchJVM` + JRE + JIT 脚本三者配合从未在真机跑过）

### P1 — 剩余功能
- [ ] 26 个源页面还没实现（大多是 SearchXxx 变体，已合并成通用页）
- [ ] EasyTier Rust 静态库未真正链接（`libeasytier_ios.a`）
- [ ] P2P utun fd 获取返回 -1（需要真机调试）
- [ ] Network Extension target 还没建

### P2 — UI 细节
- [ ] 逐页对齐真机录屏（首页/版本列表/下载页/设置页/联机页已核过）
- [ ] 还有：模组管理、存档管理、控制管理、关于页

## 五、关键信息

### 环境
- 工作目录：`/root/workspace`（proot Ubuntu，无沙箱后端，bash 一律用 `danger-full-access`）
- 仓库：`/root/workspace/ios-zl2`
- 真机录屏抽帧：`/root/workspace/zl2-frames/f_*.jpg`（27 帧 + 9 段视频）
- ZL2 安卓源码：`/tmp/zl2`

### 凭据
- GitHub token：`【已移除：请自行在 GitHub 设置里生成新 token】`
  - ⚠️ 用户尚未确认撤销，公开仓库后更要小心
  - 推送命令：`git push "https://liyuzs:<你的token>@github.com/liyuzs/zl2-ios.git" HEAD:main`

### 构建
- GitHub Actions：`.github/workflows/build.yml`（macOS-15，JRE17 从 assets.angelauramc.dev 下）
- Codemagic：`codemagic.yaml`（mac_mini_m2，逻辑同上）
- 产物：`out/ZL2.ipa`（未签名）

### 用户情况
- 学生，预算紧（¥70/月）
- 讨厌被反复问问题，喜欢直接动手
- 睡觉时希望我持续推进
- 用中文交流，回复要简洁

## 六、工作方式建议

1. **不要再输出"执行/时间紧/写"这种碎词**——那是上一轮模型退化的表现
2. 每轮做一件具体的事，然后验证
3. 改 SwiftUI 嵌套结构时**整段重写**，不要用字符串替换（上一轮两次把结构改坏）
4. 大改动前先 `git show HEAD:文件` 备份能编译的版本
5. 推送前跑 `python3 scripts/check_project.py`（只是静态检查，不等于能编译）
