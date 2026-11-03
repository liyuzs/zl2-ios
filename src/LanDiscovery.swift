// ZL2-iOS · 局域网联机发现
// 原理：Minecraft 局域网游戏会向 224.0.2.60:4445 组播
// 报文格式：[MOTD]<motd>[/MOTD][AD]<port>[/AD]
// 这是零依赖、不越狱也能用的联机方式（同一 WiFi 下）
import Foundation
import Network

struct LanServer: Identifiable, Equatable {
    let id = UUID()
    var address: String
    var port: UInt16
    var motd: String
    var lastSeen: Date

    var displayMOTD: String {
        motd.replacingOccurrences(of: "§", with: "")
            .replacingOccurrences(of: "[0-9a-fk-orA-FK-OR]", with: "", options: .regularExpression)
    }
}

enum LanDiscoveryError: LocalizedError {
    case socket(String)

    var errorDescription: String? {
        switch self {
        case .socket(let m): return "局域网监听失败：\(m)"
        }
    }
}

/// 监听 Minecraft 局域网广播
@MainActor
final class LanDiscovery: ObservableObject {
    @Published private(set) var servers: [LanServer] = []
    @Published private(set) var running = false

    private var listener: NWListener?
    private var cleaner: Timer?
    private let port: NWEndpoint.Port = 4445

    func start() {
        guard !running else { return }
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        // 加入组播组
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: port)

        do {
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            l.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.running = true
                    case .failed, .cancelled: self?.running = false
                    default: break
                    }
                }
            }
            l.start(queue: .global(qos: .userInitiated))
            listener = l
            running = true

            // 5 秒没再收到就移除
            cleaner = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let now = Date()
                    self.servers.removeAll { now.timeIntervalSince($0.lastSeen) > 12 }
                }
            }
        } catch {
            running = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        cleaner?.invalidate()
        cleaner = nil
        running = false
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .userInitiated))
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data, !data.isEmpty,
               let text = String(data: data, encoding: .utf8) {
                let remote = conn.currentPath?.remoteEndpoint
                let host: String
                switch remote {
                case .hostPort(let h, _): host = "\(h)"
                default: host = "未知"
                }
                Task { @MainActor in
                    self?.ingest(text: text, host: host)
                }
            }
            if error == nil {
                self?.receive(conn)
            } else {
                conn.cancel()
            }
        }
    }

    private func ingest(text: String, host: String) {
        guard let motd = Self.extract(text, tag: "MOTD"),
              let portStr = Self.extract(text, tag: "AD"),
              let port = UInt16(portStr) else { return }

        if let idx = servers.firstIndex(where: { $0.address == host && $0.port == port }) {
            servers[idx].motd = motd
            servers[idx].lastSeen = Date()
        } else {
            servers.append(LanServer(address: host, port: port, motd: motd, lastSeen: Date()))
        }
    }

    private static func extract(_ text: String, tag: String) -> String? {
        guard let s = text.range(of: "[\(tag)]"),
              let e = text.range(of: "[/\(tag)]") else { return nil }
        return String(text[s.upperBound..<e.lowerBound])
    }
}
