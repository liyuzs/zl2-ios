# EasyTier 集成设计（骨架）

> 前置事实：`docs/联机方案.md` 附录 A 已实测确认 —— EasyTier 的 Rust 核心能编译成
> `aarch64-apple-ios` 静态库（139 MB，3m32s）。本文档定义**怎么把它接进 ZL2-iOS**。

## 一、目标架构

```
ZL2.app
├── ZL2（主 App，SwiftUI）
│   └── 调 NE 扩展控制联机
├── PlugIns/
│   └── EasyTierTunnel.appex（Network Extension）
│       ├── PacketTunnelProvider.swift   ← 创建 utun，注入 fd 给 Rust
│       └── libeasytier_ios.a            ← Rust 核心（静态链接）
└── java_runtimes / Frameworks / ...     ← 已有
```

**为什么拆 NE 扩展**：iOS 上创建 TUN 设备只能由 NE 进程做，主 App 没有这个权限。
这也是为什么 EasyTier 官方 iOS 客户端必须有 `EasyTierNetworkExtension` target。

## 二、需要的东西

### 1. 权限（entitlements）

```xml
<!-- ZL2.entitlements（主 App） -->
<key>com.apple.developer.networking.networkextension</key>
<array><string>packet-tunnel-provider</string></array>

<!-- EasyTierTunnel.entitlements（扩展） -->
<key>com.apple.developer.networking.networkextension</key>
<array><string>packet-tunnel-provider</string></array>
<!-- 如需局域网发现 -->
<key>com.apple.developer.networking.multicast</key>
<true/>
```

**这是 iOS 26.5 上最大的不确定项**：未签名 IPA（TrollStore/AltStore）能否携带
`packet-tunnel-provider`。必须在真机验证 —— 拿不到就整条路线归零。

### 2. Rust 静态库

CI 已有 `easytier-probe.yml` 能产出 `libeasytier_ios.a`。集成时把它并进主 workflow：

```yaml
- name: 编译 EasyTier
  run: |
    brew install protobuf
    rustup target add aarch64-apple-ios
    git clone --depth 1 https://github.com/EasyTier/EasyTier-iOS.git /tmp/et
    cd /tmp/et/Core
    cargo build --release --target aarch64-apple-ios
    strip -x target/aarch64-apple-ios/release/libeasytier_ios.a
    cp target/aarch64-apple-ios/release/libeasytier_ios.a "$GITHUB_WORKSPACE/core/"
```

### 3. C 接口（从 EasyTier-iOS 仓库取得）

已知入口（需以仓库头文件为准，当前未取得完整声明）：

```c
// 把 NE 创建的 utun fd 交给 Rust 核心
int32_t set_instance_tun_fd(uint64_t generation, int32_t fd);

// 其余（起停网络、回调）需从 EasyTier-iOS/Core/src 导出检查
```

**待办**：探路工作流里加一步，把 `Core/src/lib.rs` 的 `#[no_mangle] extern "C"` 函数列表 dump 出来，
作为桥接头文件的依据。这是集成前必须补的最后一块信息。

## 三、分阶段实施

| 阶段 | 内容 | 验证方式 | 依赖 |
|---|---|---|---|
| **M0** | 真机验证 entitlement 能否生效 | 装一个最小 NE App，看 `set_instance_tun_fd` 返回 0 | 需要真机 |
| **M1** | CI 产出 strip 后的静态库并入主构建 | CI 绿 + IPA 体积增量可接受 | 无 |
| **M2** | NE target + PacketTunnelProvider 骨架 | CI 绿 + 模拟器能起 tunnel（会失败但可看到错误） | M1 |
| **M3** | 房间码解析 + Scaffolding 协议 | 单元测试（纯逻辑，CI 可验） | M2 |
| **M4** | 完整联机流程 | **真机双设备** | M3 |

**当前进度**：M1 的前置（编译验证）已完成；M0 卡在真机；M2/M3 可以在 CI 里推进。

## 四、替代方案（已实现，零依赖）

**局域网联机**（`src/LanDiscovery.swift`）：监听 `224.0.2.60:4445` 组播，自动发现
同一 WiFi 下的 Minecraft 局域网游戏。这是路线 D，作为永远可用的兜底。

- 优点：零 entitlement、零服务端、代码已写完
- 限制：只能同一局域网；iOS 需要 `multicast` entitlement 才能收组播（待真机验证）
- 已接入联机页「局域网游戏」卡片

## 五、风险再确认

| 风险 | 状态 |
|---|---|
| Rust 能否编 iOS | ✅ 已消除（实测 139MB 静态库） |
| protoc 缺失 | ✅ 已解决（brew install protobuf） |
| NE entitlement 在未签名 IPA 下是否生效 | ❓ **未知，M0 必须真机验** |
| 139MB 静态库对体积的影响 | ❓ 需 strip + 链接后实测 |
| 大陆区 App Store 上不了架 | ✅ 已知（本项目本来就走未签名 IPA） |
| NE 内存与 JVM 共存 | ❓ 需真机（jetsam） |
