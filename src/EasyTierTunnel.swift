// ZL2-iOS · EasyTier P2P 联机（Network Extension）
// 参考：docs/联机方案.md（已实测的 riscv 方案）
// 原理：iOS 沙盒不能开 /dev/net/tun，唯一合法路径是 NEPacketTunnelProvider
//      拿到系统分配的 utun fd 后注入给 EasyTier Rust 核心
//
// ⚠️ 前置条件：
//   1. 需要 Network Extension target（不是主 App）
//   2. 需要 entitlement: com.apple.developer.networking.networkextension = packet-tunnel-provider
//   3. 需要编译 libeasytier_ios.a（CI 的 easytier-probe.yml 已实测成功，139MB）
//   4. 没有付费开发者账号 + 真机签名，无法测试
//
// 本文件提供：房间码 → EasyTier 配置的转换 + Provider 骨架
import Foundation
import NetworkExtension

// MARK: - 房间码 → EasyTier 配置
/// 房间码 `U/NNNN-NNNN-SSSS-SSSS` 编码了网络名与密钥
///  - NNNN-NNNN = 网络编号（公开可见，用于节点发现）
///  - SSSS-SSSS = 密钥（用于加密）
struct ZLEasyTierRoom {
    var networkName: String
    var secret: String
    var raw: String

    /// 解析房间码
    /// 格式：U/NNNN-NNNN-SSSS-SSSS
    static func parse(_ code: String) -> ZLEasyTierRoom? {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // 去掉可能的 U/ 前缀
        let body = t.hasPrefix("U/") ? String(t.dropFirst(2)) : t
        let parts = body.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts.allSatisfy({ $0.count == 4 && $0.allSatisfy { $0.isHexDigit } }) else {
            return nil
        }
        // 前两组是网络名，后两组是密钥（按 EasyTier 官方客户端的约定）
        let net = "\(parts[0])-\(parts[1])"
        let secret = "\(parts[2])-\(parts[3])"
        return ZLEasyTierRoom(networkName: net, secret: secret, raw: body)
    }

    /// 生成 EasyTier 的 TOML 配置
    func tomlConfig(peers: [String] = []) -> String {
        var lines: [String] = []
        lines.append("[network_identity]")
        lines.append("network_name = \"\(networkName)\"")
        lines.append("network_secret = \"\(secret)\"")
        lines.append("")
        lines.append("[peer]")
        for p in peers {
            lines.append("[[peer.uri]]")
            lines.append("uri = \"tcp://\(p)\"")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 隧道状态
enum ZLTunnelState: String {
    case idle = "未连接"
    case starting = "正在启动"
    case running = "已连接"
    case stopped = "已断开"
    case failed = "连接失败"
}

// MARK: - Network Extension Provider 骨架
/// 在独立的 Network Extension target 里使用：
/// NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel
@available(iOS 16.0, *)
final class ZLEasyTierPacketTunnelProvider: NEPacketTunnelProvider {

    private var state: ZLTunnelState = .idle
    private var generation: UInt64 = 0

    /// 启动隧道
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        state = .starting
        generation += 1
        let currentGen = generation

        // 1. 从 providerConfiguration 读房间码
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let roomCode = proto.providerConfiguration?["roomCode"] as? String,
              let room = ZLEasyTierRoom.parse(roomCode) else {
            completionHandler(makeError("无效的房间码"))
            return
        }

        // 2. 配置 TUN 网络参数
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.144.144.1")
        settings.mtu = 1400
        let ipv4 = NEIPv4Settings(addresses: ["10.144.144.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["10.144.144.1"])

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.state = .failed
                completionHandler(error)
                return
            }

            // 3. 拿到 utun fd，注入给 EasyTier 核心
            //    调用 numpy C 接口：set_instance_tun_fd(generation, fd, &err)
            let fd = self.tunnelFileDescriptor()
            if fd < 0 {
                self.state = .failed
                completionHandler(self.makeError("获取 utun fd 失败"))
                return
            }

            // TODO: 调用 EasyTier Rust 核心
            // easytier_ios_set_tun_fd(currentGen, fd)  ← 由 libeasytier_ios.a 导出
            _ = room.tomlConfig()

            self.state = .running
            self.generation = currentGen
            completionHandler(nil)
        }
    }

    /// 停止隧道
    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        state = .stopped
        generation += 1   // 代际号 +1，让旧回调作废
        // TODO: easytier_ios_stop()
        completionHandler()
    }

    /// 处理 App 发来的消息（房间创建/加入）
    override func handleAppMessage(_ messageData: Data,
                                   completionHandler: ((Data?) -> Void)?) {
        guard let cmd = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
        // 指令格式："create:房间码" / "join:房间码" / "stop"
        var reply = "ok"
        if cmd.hasPrefix("create:") || cmd.hasPrefix("join:") {
            let code = String(cmd.split(separator: ":", maxSplits: 1).last ?? "")
            if ZLEasyTierRoom.parse(code) == nil {
                reply = "invalid_room"
            }
        } else if cmd == "stop" {
            state = .stopped
        }
        completionHandler?(reply.data(using: .utf8))
    }

    // MARK: 工具
    /// 拿到底层 utun 文件描述符
    /// iOS 上 `packetFlow` 是 NEPacketTunnelFlow，无法直接取 fd，
    /// 需要通过 socket 遍历或者私有 API。官方 EasyTier 客户端用的是
    /// `NEPacketTunnelProvider.packetFlow.value(forKey: "socket")` 之类的方式。
    private func tunnelFileDescriptor() -> Int32 {
        // 方案 A：遍历进程 fd，找 AF_SYSTEM 的 utun socket（官方客户端做法）
        // 方案 B：通过 KVC 取 packetFlow 的 socket（不稳定）
        // 这里返回 -1 表示未实现，需要真机调试
        return -1
    }

    private func makeError(_ msg: String) -> NSError {
        NSError(domain: "ZL2EasyTier", code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - EasyTier C 接口声明（来自 libeasytier_ios.a）
// 编译时链接该静态库后，这些符号才可用
enum EasyTierBridge {
    /// 初始化实例
    /// int easytier_ios_start(const char *toml_config, uint64_t generation, const char **err);
    static func start(config: String, generation: UInt64) -> Int32 {
        // return easytier_ios_start(config, generation, nil)
        return -1
    }

    /// 注入 utun fd
    /// int easytier_ios_set_tun_fd(uint64_t generation, int fd, const char **err);
    static func setTunFD(generation: UInt64, fd: Int32) -> Int32 {
        // return easytier_ios_set_tun_fd(generation, fd, nil)
        return -1
    }

    /// 停止实例
    /// int easytier_ios_stop(uint64_t generation);
    static func stop(generation: UInt64) -> Int32 {
        return -1
    }

    /// 查询节点数
    /// int easytier_ios_peer_count(uint64_t generation);
    static func peerCount(generation: UInt64) -> Int32 {
        return 0
    }
}

// MARK: - 主 App 侧的隧道管理（通过 NETunnelProviderManager）
@available(iOS 16.0, *)
final class ZLTunnelManager {
    static let shared = ZLTunnelManager()
    private var manager: NETunnelProviderManager?

    /// 安装/加载配置
    func loadOrInstall() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let m = managers.first {
            manager = m
            return m
        }
        let m = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.zl2.ios.tunnel"   // ← 需与 NE target 一致
        proto.serverAddress = "EasyTier"
        m.protocolConfiguration = proto
        m.localizedDescription = "ZL2 联机"
        m.isEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        manager = m
        return m
    }

    /// 创建房间
    func createRoom(code: String) async throws {
        let m = try await loadOrInstall()
        m.protocolConfiguration?.providerConfiguration = ["roomCode": code]
        try await m.saveToPreferences()
        try m.connection.startVPNTunnel()
    }

    /// 加入房间
    func joinRoom(code: String) async throws {
        try await createRoom(code: code)
    }

    /// 断开
    func stop() {
        manager?.connection.stopVPNTunnel()
    }
}
