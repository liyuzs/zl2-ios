# 项目状态（2026-11-03）

## 一句话

**界面 + 服务层代码已全部写完，静态检查通过，编译和真机效果仍未验证。** 周末在 GitHub 上跑一次就知道。

---

## ✅ 已完成

### 界面层（SwiftUI，8 个文件）
| 文件 | 内容 |
|---|---|
| `src/Theme.swift` | ZL2 风格配色、卡片、主按钮 |
| `src/HomeScreen.swift` | 首页：账户条、版本卡片、悬浮启动键 |
| `src/AccountScreen.swift` | 账户：微软 / 离线 / 外置认证（已接 AccountStore） |
| `src/SettingsScreen.swift` | 设置：渲染器、分辨率、内存、下载源 |
| `src/DownloadScreen.swift` | 下载中心：版本列表 + 搜索 + 分类 |
| `src/ModsScreen.swift` | 模组管理、前置依赖提醒、启停开关 |
| `src/LaunchScreen.swift` | 启动进度：环形进度 + 滚动日志 |
| `src/ZL2App.swift` | 入口 + 侧边抽屉 + 控制布局（可拖按键）+ 关于 |

### 服务层（纯 Foundation，无 UI 依赖，3 个文件）
| 文件 | 内容 | 验证情况 |
|---|---|---|
| `src/AccountService.swift` | 账户模型、离线 UUID、持久化、微软/外置认证协议；自带纯 Swift MD5 | ✅ MD5 四组测试向量全部通过；`OfflinePlayer:Notch` → `b50ad385-829d-3141-a216-7e7d7539ba7f`，与官方离线 UUID 一致 |
| `src/LaunchContract.swift` | 启动状态/进度/错误枚举、`LaunchService` 协议、`MockLaunchService` | ✅ 静态结构检查通过 |
| `src/MojangAPI.swift` | 版本清单、版本详情、文件下载（async/await，原子写入） | ✅ 用真实上游数据核对：manifest 921 条字段齐全、26.3/1.8.9 新旧格式都兼容 |

### 工程与文档
| 文件 | 内容 |
|---|---|
| `project.yml` | XcodeGen 配置（iOS 16+），`src/` 下新增文件自动纳入 |
| `.github/workflows/build.yml` | 云端编译，产出 `ZL2.ipa` + 模拟器包 |
| `docs/周末操作手册.md` | 从注册 GitHub 到装机的完整步骤 + 报错排查表 |
| `docs/核心集成方案.md` | **700 行调研**：怎么接 Amethyst 启动核心（含源码行号、体积实测、entitlements 对照） |
| `scripts/check_project.py` | 静态体检（括号平衡、类型重复、@main 数量、YAML 引用） |

---

## ⚠️ 未验证（没有环境，谁都替不了）

| 项 | 为什么 | 谁能验证 |
|---|---|---|
| **能否编译通过** | 本机无 swiftc / Xcode / macOS | 周末 GitHub Actions |
| **界面实际观感** | 跑不起来就没有截图 | Mac 模拟器 / 朋友 iPhone |
| **SwiftUI API 在 iOS 16 的兼容性** | 只能靠静态经验 | 编译器会直接指出 |
| **XcodeGen 配置是否正确** | 本机无法运行 `xcodegen generate` | Actions 的 Generate 步骤 |
| **MojangAPI 的运行时行为** | 只做了字段级核对，没跑过真实下载 | 接核心后联调 |

---

## 🔌 明确没做（下一阶段）

- **接入 Amethyst 启动核心**：方案已写在 `docs/核心集成方案.md`，但代码没动。集成的第一步（最小验证）是 `launchJVM(nil, jarPath, w, h, 8)`，不需要版本下载器。
- **真实的版本下载落盘**：`DownloadScreen` 仍是演示数据，`MojangAPI` 已具备能力，还没接线。
- **微软 OAuth 真实登录**：只有协议定义，没有实现。
- **联机**：ZL2 的邀请码机制 iOS 用不了，要另做。

---

## 🧩 已知脆弱点（周末最可能卡在这）

1. **XcodeGen 与 Info.plist 配合**：若报 plist 冲突，删掉 `project.yml` 里 `GENERATE_INFOPLIST_FILE: NO` 再试
2. **`UILaunchScreen: {}`**：若被解析成 null，改成 `UILaunchScreen: { UIColorName: "" }`
3. **未签名 build**：若被 entitlements 卡住，加 `-allowProvisioningUpdates` 或去掉 `CODE_SIGN_IDENTITY=""`
4. **两个智能体并行写代码时曾出现类型重名**（`VersionSummary`），已把 MojangAPI 里的改名为 `ManifestVersionEntry`，静态检查已确认无重复
5. **AppIcon 是空壳**：只会警告不会失败

---

## 📦 交付物

- `/root/workspace/ios-zl2/` —— 完整项目目录（11 个 Swift 文件 + 文档 + CI）
- `/sdcard/Download/DSH-Go/ios-zl2-周末版.tar.gz` —— 打包好的压缩包

## 下一步（按优先级）

1. **周末先编译一次**，Actions 报错发我 → 大概率调 1–2 轮
2. 编译通过后在模拟器/朋友手机上**看界面**，反馈哪里不像 ZL2
3. 界面定稿后再决定是否投入「接核心」（`docs/核心集成方案.md` 已给出路线，工作量以周计）

## 许可提醒

接入 Amethyst（GPL-3.0）后**整个 App 必须 GPL-3.0 开源**，且**不得沿用 "ZalithLauncher" / "ZL"**（其 GPL 附加条款要求改版改名）。建议改成 `Beryl Launcher` 之类。

---

## 🆕 2026-11-03 晚：核心集成完成（run #18）

| 项 | 状态 |
|---|---|
| Amethyst 核心静态库 | ✅ 1.0 MB，编译通过 |
| 动态依赖（AFNetworking/awt/tinygl4angle） | ✅ 已链接并打包 |
| JRE 17 | ✅ java_runtimes/java-17-openjdk（含 libjli.dylib） |
| Frameworks（19 个 dylib/framework） | ✅ 已打包 |
| 启动调用链 | ✅ LaunchScreen → CoreBridge → launchJVM |
| **最终 IPA** | ✅ **50.92 MB**，解压 158.2 MB |

**仍未验证**：App 能否安装、界面观感、JVM 能否真启动、能否进世界——全部需要真机。

详见 `docs/核心集成进度.md`。

## 🆕 2026-11-03 深夜：功能闭环（run #35）

- 下载中心 6 类资源页 + 版本管理 7 页 + 设置 6 类
- 真实 Mojang 版本清单已接入下载页
- 版本安装器：client.jar + libraries + assets 索引
- 启动页读已安装版本 JSON → 真正调用 launchJVM
- 新增：搜索/导出/引导/崩溃日志/联机房间

**覆盖率约 90%**；剩余为真机验证（安装、JVM 启动、渲染）。
