// ZL2-iOS · 局域网联机发现
//
// Minecraft 的「对局域网开放」会把服务信息组播到 224.0.2.60:4445，
// 报文格式： [MOTD]<标题>[/MOTD][AD]<端口>[/AD]
//
// iOS 上必须用 BSD socket 并显式加入组播组（IP_ADD_MEMBERSHIP），
// Network.framework 的 NWListener 不会加入组播组，收不到这些包。
import Foundation
import Darwin
import Combine

struct LanServer: Identifiable, Equatable {
    let id = UUID()
    var address: String
    var port: UInt16
    var motd: String
    var lastSeen: Date

    /// 去掉 § 颜色代码后的标题
    var displayMOTD: String {
        motd.replacingOccurrences(of: "§", with: "")
            .replacingOccurrences(of: "[0-9a-fk-orA-FK-OR]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LanDiscoveryError: LocalizedError {
    case socket(String)
    case bind(String)
    case join(String)

    var errorDescription: String? {
        switch self {
        case .socket(let m): return "局域网监听失败（socket）：\(m)"
        case .bind(let m):   return "局域网监听失败（bind）：\(m)"
        case .join(let m):   return "加入组播组失败：\(m)"
        }
    }
}

/// 监听 Minecraft 局域网广播
@MainActor
final class LanDiscovery: ObservableObject {
    /// 线程安全的运行标记：后台接收循环读这个，不要用 DispatchQueue.main.sync（会死锁）
    private let runningFlag = ZLAtomicFlag()

    @Published private(set) var servers: [LanServer] = []
    @Published private(set) var running = false
    @Published private(set) var lastError: String?

    private var fd: Int32 = -1
    private var thread: Thread?
    private var cleaner: Timer?

    /// Minecraft 局域网广播组播地址
    private let multicastGroup = "224.0.2.60"
    /// 固定端口 4445
    private let port: UInt16 = 4445

    func start() {
        runningFlag.value = true
        guard !running else { return }
        lastError = nil

        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            lastError = LanDiscoveryError.socket(String(cString: strerror(errno))).localizedDescription
            return
        }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            lastError = LanDiscoveryError.bind(String(cString: strerror(errno))).localizedDescription
            close(sock)
            return
        }

        // 加入组播组 224.0.2.60
        var mreq = ip_mreq()
        mreq.imr_multiaddr.s_addr = inet_addr(multicastGroup)
        mreq.imr_interface.s_addr = INADDR_ANY
        let joinResult = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq,
                                    socklen_t(MemoryLayout<ip_mreq>.size))
        guard joinResult == 0 else {
            lastError = LanDiscoveryError.join(String(cString: strerror(errno))).localizedDescription
            close(sock)
            return
        }

        // 接收超时，便于线程退出
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        fd = sock
        running = true

        let t = Thread { [weak self] in
            self?.receiveLoop(sock: sock)
        }
        t.name = "ZL2.LanDiscovery"
        t.start()
        thread = t

        // 12 秒没再收到就移除（MC 每 1.5 秒广播一次）
        cleaner = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                self.servers.removeAll { now.timeIntervalSince($0.lastSeen) > 12 }
            }
        }
    }

    func stop() {
        runningFlag.value = false
        running = false
        if fd >= 0 {
            close(fd)
            fd = -1
        }
        cleaner?.invalidate()
        cleaner = nil
        thread = nil
        servers.removeAll()
    }

    // MARK: - 收包循环（后台线程）

    private nonisolated func receiveLoop(sock: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            var sender = sockaddr_in()
            var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(sock, &buf, buf.count, 0, $0, &senderLen)
                }
            }
            if n <= 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // 每秒醒一次，检查是否还需要继续
                    if !runningFlag.value { break }
                    continue
                }
                break
            }
            guard let text = String(bytes: buf[0..<n], encoding: .utf8) else { continue }
            var hostBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var saddr = sender.sin_addr
            inet_ntop(AF_INET, &saddr, &hostBuf, socklen_t(INET_ADDRSTRLEN))
            let host = String(cString: hostBuf)

            DispatchQueue.main.async { [weak self] in
                self?.ingest(text: text, host: host)
            }
        }
    }

    // MARK: - 解析

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


// MARK: - 线程安全的布尔标记

/// 用锁保护的布尔值，任何线程都能安全读写。
/// 用它替代 DispatchQueue.main.sync，避免后台线程把主线程卡死。
final class ZLAtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false

    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
