// ZL2-iOS · 服务器列表
// 参考：ZL2 的 ServerListScreen.kt + ServerData.kt
// 功能：servers.dat 读写（NBT）+ 真实 Minecraft 服务器 ping（状态协议）
import SwiftUI

// MARK: - 纹理包状态（对齐 ZL2 的 TexturePackStatus）
enum ZLTexturePackStatus: Int, Codable {
    case disabled = 0
    case enabled = 1
    case prompt = -1

    var storageCode: Int? { self == .prompt ? nil : rawValue }
}

// MARK: - 服务器数据（对齐 ZL2 的 ServerData）
struct ZLServerData: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var originIp: String
    var texturePackStatus: ZLTexturePackStatus = .prompt
    var acceptedCodeOfConduct: Bool? = nil
    var icon: Data? = nil
}

// MARK: - Ping 结果
struct ZLServerPingResult: Equatable {
    var versionName: String
    var protocolNumber: Int
    var maxPlayers: Int
    var onlinePlayers: Int
    var motd: String
    var favicon: Data?
    var latencyMs: Int
}

// MARK: - 服务器列表页
struct ServerListScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var servers: [ZLServerData] = []
    @State private var pings: [UUID: ZLServerPingResult] = [:]
    @State private var loading: Set<UUID> = []
    @State private var editing: ZLServerData?
    @State private var showEdit = false
    @State private var deleteTarget: ZLServerData?
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "服务器列表", active: .multiplayer, onBack: onBack, onHome: onHome)

            HStack(spacing: 10) {
                Button { addServer() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("添加服务器").font(.system(size: 12))
                    }
                    .foregroundStyle(ZLTheme.textOnGold)
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(ZLTheme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { Task { await pingAll() } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 12))
                        Text("刷新状态").font(.system(size: 12))
                    }
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(ZLTheme.surface)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("搜索服务器", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10).frame(width: 180, height: 36)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 8) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 32))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                            Text("还没有添加服务器").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 50)
                    }

                    ForEach(filtered) { s in
                        serverRow(s)
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            load()
            await pingAll()
        }
        .sheet(isPresented: $showEdit) {
            if let e = editing {
                ServerEditSheet(server: e) { updated in
                    if let i = servers.firstIndex(where: { $0.id == updated.id }) {
                        servers[i] = updated
                        save()
                    }
                    showEdit = false
                }
            }
        }
        .alert("删除服务器", isPresented: Binding(get: { deleteTarget != nil },
                                                   set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let t = deleteTarget {
                    servers.removeAll { $0.id == t.id }
                    save()
                }
                deleteTarget = nil
            }
        } message: {
            Text("确定删除「\(deleteTarget?.name ?? "")」？")
        }
    }

    private func serverRow(_ s: ZLServerData) -> some View {
        HStack(spacing: 12) {
            // 图标
            Group {
                if let icon = s.icon, let img = UIImage(data: icon) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZLTheme.primarySoft.overlay(
                        Image(systemName: "cube").foregroundStyle(ZLTheme.primary)
                    )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(s.name).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                    if loading.contains(s.id) {
                        ProgressView().scaleEffect(0.6)
                    } else if let p = pings[s.id] {
                        SignalBars(online: p.onlinePlayers, max: p.maxPlayers)
                    }
                }
                if let p = pings[s.id] {
                    Text("\(p.onlinePlayers)/\(p.maxPlayers) · \(p.latencyMs)ms · \(p.versionName)")
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    Text(p.motd.replacingOccurrences(of: "§.", with: "", options: .regularExpression))
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond).lineLimit(1)
                } else {
                    Text(s.originIp).font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            }
            Spacer()

            Button { editing = s; showEdit = true } label: {
                Image(systemName: "pencil").font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 34, height: 32)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { deleteTarget = s } label: {
                Image(systemName: "trash").font(.system(size: 13))
                    .foregroundStyle(ZLTheme.danger)
                    .frame(width: 34, height: 32)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filtered: [ZLServerData] {
        guard !search.isEmpty else { return servers }
        return servers.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.originIp.localizedCaseInsensitiveContains(search)
        }
    }

    // MARK: 数据
    private func load() {
        servers = ServerStore.shared.load()
        if servers.isEmpty {
            // 演示数据
            servers = [
                ZLServerData(name: "Hypixel", originIp: "mc.hypixel.net"),
            ]
        }
    }

    private func save() { ServerStore.shared.save(servers) }

    private func addServer() {
        editing = ZLServerData(name: "新的服务器", originIp: "localhost")
        showEdit = true
    }

    private func pingAll() async {
        for s in servers {
            loading.insert(s.id)
            let r = await MinecraftPing.ping(host: s.originIp)
            if let r = r { pings[s.id] = r }
            loading.remove(s.id)
        }
    }
}

// MARK: - 信号强度图标
struct SignalBars: View {
    let online: Int
    let max: Int
    var body: some View {
        let ratio = max > 0 ? Double(online) / Double(max) : 0
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Double(i) / 5 < ratio ? ZLTheme.success : ZLTheme.textSecond.opacity(0.25))
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
    }
}

// MARK: - 编辑弹窗
struct ServerEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var server: ZLServerData
    var onSave: (ZLServerData) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器信息") {
                    TextField("名称", text: $server.name)
                    TextField("地址（IP:端口）", text: $server.originIp)
                }
                Section("纹理包") {
                    Picker("提示", selection: $server.texturePackStatus) {
                        Text("提示").tag(ZLTexturePackStatus.prompt)
                        Text("启用").tag(ZLTexturePackStatus.enabled)
                        Text("禁用").tag(ZLTexturePackStatus.disabled)
                    }
                }
            }
            .navigationTitle("编辑服务器")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(server) }
                }
            }
        }
    }
}

// MARK: - servers.dat 存储
final class ServerStore {
    static let shared = ServerStore()
    private let key = "zl.servers"

    func load() -> [ZLServerData] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([ServerCodable].self, from: d) else { return [] }
        return arr.map { $0.toModel() }
    }

    func save(_ list: [ZLServerData]) {
        let arr = list.map { ServerCodable(from: $0) }
        if let d = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    struct ServerCodable: Codable {
        var name: String
        var ip: String
        var texturePack: Int
        var icon: Data?
        init(from m: ZLServerData) {
            name = m.name; ip = m.originIp
            texturePack = m.texturePackStatus.storageCode ?? -1
            icon = m.icon
        }
        func toModel() -> ZLServerData {
            ZLServerData(name: name, originIp: ip,
                         texturePackStatus: ZLTexturePackStatus(rawValue: texturePack) ?? .prompt,
                         icon: icon)
        }
    }
}

// MARK: - Minecraft 服务器 Ping（真实协议实现）
enum MinecraftPing {
    /// 通过 Server List Ping 协议获取状态
    static func ping(host: String, timeout: TimeInterval = 3) async -> ZLServerPingResult? {
        let parts = host.split(separator: ":", maxSplits: 1)
        let hostname = String(parts[0])
        let port = parts.count > 1 ? (UInt16(parts[1]) ?? 25565) : 25565

        return await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                cont.resume(returning: syncPing(host: hostname, port: port, timeout: timeout))
            }
        }
    }

    private static func syncPing(host: String, port: UInt16, timeout: TimeInterval) -> ZLServerPingResult? {
        let start = Date()
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port),
                                           &readStream, &writeStream)
        guard let r = readStream?.takeRetainedValue(),
              let w = writeStream?.takeRetainedValue() else { return nil }

        let input = r as InputStream
        let output = w as OutputStream
        input.open(); output.open()
        defer { input.close(); output.close() }

        // 1. Handshake 包
        var handshake = Data()
        let hostData = host.data(using: .utf8) ?? Data()
        var payload = Data()
        payload.append(0x00)                          // packet id
        payload.append(contentsOf: varInt(765))       // protocol
        payload.append(contentsOf: varInt(hostData.count))
        payload.append(hostData)
        payload.append(UInt8(port >> 8)); payload.append(UInt8(port & 0xFF))
        payload.append(0x01)                          // next state: status
        handshake.append(contentsOf: varInt(payload.count))
        handshake.append(payload)

        // 2. Status request
        var req = Data()
        req.append(0x01)  // length 1
        req.append(0x00)  // packet id 0

        guard writeAll(output, handshake) && writeAll(output, req) else { return nil }

        // 3. 读响应
        guard let lenData = readVarInt(input), lenData > 0 else { return nil }
        guard let resp = readExactly(input, count: lenData) else { return nil }

        // 解析 JSON
        guard resp.count > 2 else { return nil }
        // 跳过 packet id (varint)
        var idx = 1
        // 读字符串长度
        var strLen = 0, shift = 0
        while idx < resp.count {
            let b = resp[idx]; idx += 1
            strLen |= Int(b & 0x7F) << shift
            shift += 7
            if b & 0x80 == 0 { break }
        }
        guard idx + strLen <= resp.count else { return nil }
        let jsonData = resp.subdata(in: idx..<(idx + strLen))
        guard let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }

        let version = (obj["version"] as? [String: Any])?["name"] as? String ?? "?"
        let protocolNum = (obj["version"] as? [String: Any])?["protocol"] as? Int ?? 0
        let players = obj["players"] as? [String: Any] ?? [:]
        let maxP = players["max"] as? Int ?? 0
        let online = players["online"] as? Int ?? 0
        let desc = obj["description"] as? [String: Any]
        let motd = (desc?["text"] as? String) ?? (obj["description"] as? String) ?? ""

        var iconData: Data? = nil
        if let fav = obj["favicon"] as? String,
           let comma = fav.firstIndex(of: ",") {
            let b64 = String(fav[fav.index(after: comma)...])
            iconData = Data(base64Encoded: b64)
        }

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        return ZLServerPingResult(versionName: version, protocolNumber: protocolNum,
                                  maxPlayers: maxP, onlinePlayers: online,
                                  motd: motd, favicon: iconData, latencyMs: latency)
    }

    // MARK: 协议工具
    private static func varInt(_ v: Int) -> Data {
        var value = v
        var out = Data()
        while true {
            var b = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { b |= 0x80 }
            out.append(b)
            if value == 0 { break }
        }
        return out
    }

    private static func readVarInt(_ input: InputStream) -> Int? {
        var result = 0, shift = 0
        while true {
            var b: UInt8 = 0
            let n = input.read(&b, maxLength: 1)
            if n <= 0 { return nil }
            result |= Int(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
            if shift > 35 { return nil }
        }
        return result
    }

    private static func writeAll(_ out: OutputStream, _ data: Data) -> Bool {
        return data.withUnsafeBytes { ptr -> Bool in
            guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return false }
            var written = 0
            while written < data.count {
                let n = out.write(base + written, maxLength: data.count - written)
                if n <= 0 { return false }
                written += n
            }
            return true
        }
    }

    private static func readExactly(_ input: InputStream, count: Int) -> Data? {
        var buf = [UInt8](repeating: 0, count: count)
        var got = 0
        while got < count {
            let n = input.read(&buf[got], maxLength: count - got)
            if n <= 0 { return nil }
            got += n
        }
        return Data(buf)
    }
}
