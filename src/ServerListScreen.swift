// ZL2-iOS · 服务器列表
// 参考：ZL2 的 ServerListScreen.kt + ServerData.kt
// 功能：servers.dat 读写（NBT）+ 真实 Minecraft 服务器 ping（状态协议）
import SwiftUI
import UIKit
import Combine

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
    /// ping 不通的服务器，单独给「重试」，不影响其他行
    @State private var failed: Set<UUID> = []
    // 轻提示（连接 / 复制地址）
    @State private var toast: String?

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

            // 用 List 才能拿到 iOS 原生的 swipeActions（左滑删除）
            List {
                if servers.isEmpty {
                    ZLEmptyState(
                        icon: "server.rack",
                        title: "还没有服务器",
                        detail: "点上方「添加服务器」填一个地址\n或者让朋友在游戏里「对局域网开放」，用局域网联机",
                        actionTitle: "添加服务器",
                        action: { addServer() })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: ZLTheme.screenPadding,
                                                  bottom: 5, trailing: ZLTheme.screenPadding))
                } else if filtered.isEmpty {
                    ZLEmptyState(
                        icon: "magnifyingglass",
                        title: "没有匹配的服务器",
                        detail: "换个名字或地址关键词试试",
                        actionTitle: "清空搜索",
                        action: { search = "" })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: ZLTheme.screenPadding,
                                                  bottom: 5, trailing: ZLTheme.screenPadding))
                } else {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, s in
                        serverRow(s)
                            .popIn(delay: Double(min(idx, 10)) * 0.035)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: ZLTheme.screenPadding,
                                                      bottom: 4, trailing: ZLTheme.screenPadding))
                            // 左滑删除 / 刷新状态
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteServer(s)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    Task { await ping(s) }
                                } label: {
                                    Label("刷新", systemImage: "arrow.clockwise")
                                }
                                .tint(ZLTheme.primary)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            // iOS 原生下拉刷新：重新 ping 所有服务器
            .refreshable {
                load()
                await pingAll()
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
                    } else {
                        // 新服务器：原来只有 if 分支，导致新加的永远存不进去
                        servers.append(updated)
                    }
                    save()
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
                    pings.removeValue(forKey: t.id)
                    failed.remove(t.id)
                    loading.remove(t.id)
                    save()
                }
                deleteTarget = nil
            }
        } message: {
            Text("确定删除「\(deleteTarget?.name ?? "")」？")
        }
        .overlay(alignment: .top) { toastView }
        // ⌘R（iPad 键盘）重新 ping
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            Task { await pingAll() }
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
                    if let p = pings[s.id], !loading.contains(s.id) {
                        SignalBars(online: p.onlinePlayers, max: p.maxPlayers)
                    }
                }
                if loading.contains(s.id) {
                    // 状态没回来之前用骨架条占位，比转圈更稳，行高也不会抖
                    VStack(alignment: .leading, spacing: 4) {
                        ZLSkeletonRow(height: 8, corner: 4).frame(width: 118)
                        ZLSkeletonRow(height: 8, corner: 4).frame(width: 172)
                    }
                    .padding(.top, 2)
                } else if let p = pings[s.id] {
                    Text("\(p.onlinePlayers)/\(p.maxPlayers) · \(p.latencyMs)ms · \(p.versionName)")
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    Text(p.motd.replacingOccurrences(of: "§.", with: "", options: .regularExpression))
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond).lineLimit(1)
                } else if failed.contains(s.id) {
                    HStack(spacing: 8) {
                        Text("连不上，检查地址或网络").font(.system(size: 11))
                            .foregroundStyle(ZLTheme.danger)
                        Button {
                            ZLHaptic.light()
                            Task { await ping(s) }
                        } label: {
                            Text("重试").font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ZLTheme.primaryDeep)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(ZLTheme.primarySoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
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
        .contentShape(Rectangle())
        // iOS 长按菜单
        .contextMenu {
            Button { connect(s) } label: {
                Label("连接", systemImage: "play.fill")
            }
            Button { editing = s; showEdit = true } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button { copyAddress(s) } label: {
                Label("复制地址", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) { deleteTarget = s } label: {
                Label("删除", systemImage: "trash")
            }
        }
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
        // 不再塞演示数据：空列表交给空状态，告诉用户怎么加第一个服务器
        servers = ServerStore.shared.load()
    }

    private func save() { ServerStore.shared.save(servers) }

    private func addServer() {
        editing = ZLServerData(name: "新的服务器", originIp: "localhost")
        showEdit = true
    }

    private func pingAll() async {
        for s in servers { await ping(s) }
    }

    /// 单个服务器的状态刷新：失败也记下来，行内可以单独重试
    private func ping(_ s: ZLServerData) async {
        loading.insert(s.id)
        failed.remove(s.id)
        let r = await MinecraftPing.ping(host: s.originIp)
        if let r = r {
            pings[s.id] = r
            failed.remove(s.id)
        } else {
            pings[s.id] = nil
            failed.insert(s.id)
        }
        loading.remove(s.id)
    }

    // MARK: - iOS 交互动作

    /// 连接：把地址放进剪贴板 + 顺手刷新状态。
    /// iOS 上没法直接拉起游戏去连服务器，所以给一句明确的后续操作提示。
    private func connect(_ s: ZLServerData) {
        ZLInteraction.haptic(.medium)
        ZLInteraction.copy(s.originIp)
        showToast("已复制地址，游戏里「多人游戏 → 直接连接」即可加入")
        Task { await ping(s) }
    }

    private func copyAddress(_ s: ZLServerData) {
        ZLInteraction.haptic(.light)
        ZLInteraction.copy(s.originIp)
        showToast("已复制地址：\(s.originIp)")
    }

    /// 左滑删除（滑动删除是 iOS 的原生快捷动作，不再二次确认）
    private func deleteServer(_ s: ZLServerData) {
        ZLInteraction.haptic(.rigid)
        servers.removeAll { $0.id == s.id }
        pings.removeValue(forKey: s.id)
        failed.remove(s.id)
        loading.remove(s.id)
        deleteTarget = nil
        save()
        showToast("已删除「\(s.name)」")
    }

    // MARK: - 轻提示

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ZLTheme.primaryDeep))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard toast == text else { return }
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
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
        // 空地址会让 parts 为空数组，直接取 [0] 会闪退
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", maxSplits: 1)
        guard let first = parts.first else { return nil }
        let hostname = String(first)
        let port = parts.count > 1 ? (UInt16(parts[1]) ?? 25565) : 25565

        // ⚠️ 用 withTaskGroup 做 race 是错的：body 返回后会隐式等待所有子任务，
        // cancelAll() 只是置取消标记，而 CFStream 的 read 根本不可取消 —— ping 依然永不返回。
        // 正确做法：continuation + 两个 GCD 任务抢先 resume（加锁保证只 resume 一次）。
        return await withCheckedContinuation { (cont: CheckedContinuation<ZLServerPingResult?, Never>) in
            let lock = NSLock()
            var finished = false

            func finish(_ v: ZLServerPingResult?) {
                lock.lock()
                if finished { lock.unlock(); return }
                finished = true
                lock.unlock()
                cont.resume(returning: v)   // 只有第一个到的人能 resume
            }

            // 真正的网络探测（可能永远卡住，但不影响 UI）
            DispatchQueue.global(qos: .utility).async {
                finish(syncPing(host: hostname, port: port, timeout: timeout))
            }
            // 到点强制返回 nil
            let safe = max(0.5, timeout)
            DispatchQueue.global().asyncAfter(deadline: .now() + safe) {
                finish(nil)
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
