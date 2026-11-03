// ZL2-iOS · 存档管理
// 参考：ZL2 的 SavesManagerScreen.kt
// 功能：扫描 saves 目录、解析 level.dat（gzip+NBT）、显示世界信息
import SwiftUI
import Compression

// MARK: - 存档信息
struct ZLWorldInfo: Identifiable, Equatable {
    var id = UUID()
    var folderName: String
    var path: URL
    var levelName: String?
    var gameMode: String?
    var versionName: String?
    var lastPlayed: Date?
    var sizeBytes: Int64
    var iconData: Data?
    var seed: Int64?
}

struct SavesManagerScreen: View {
    var versionID: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var worlds: [ZLWorldInfo] = []
    @State private var search = ""
    @State private var deleteTarget: ZLWorldInfo?
    @State private var detail: ZLWorldInfo?

    private var savesDir: URL {
        VersionRepository.shared.mcRoot.appendingPathComponent("saves", isDirectory: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "存档管理 · \(versionID)", onBack: onBack, onHome: onHome)

            HStack(spacing: 10) {
                Button { reload() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                        Text("刷新").font(.system(size: 12))
                    }
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 10).frame(height: 32)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("共 \(filtered.count) 个世界")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)

                Spacer()

                TextField("搜索世界", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10).frame(width: 160, height: 32)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 8) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "map")
                                .font(.system(size: 34))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                            Text("还没有存档").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textSecond)
                            Text("在游戏里创建世界后，这里会自动出现")
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    ForEach(filtered) { w in
                        worldRow(w)
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { reload() }
        .alert("删除存档", isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let t = deleteTarget { try? FileManager.default.removeItem(at: t.path) }
                deleteTarget = nil
                reload()
            }
        } message: {
            Text("确定删除「\(deleteTarget?.levelName ?? deleteTarget?.folderName ?? "")」？此操作不可恢复。")
        }
        .sheet(item: $detail) { w in
            WorldDetailSheet(world: w) { detail = nil }
        }
    }

    private func worldRow(_ w: ZLWorldInfo) -> some View {
        HStack(spacing: 12) {
            // 世界图标（level.dat 里的 icon）
            Group {
                if let d = w.iconData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .overlay(Image(systemName: "map.fill")
                            .foregroundStyle(ZLTheme.primary))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(w.levelName ?? w.folderName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                HStack(spacing: 8) {
                    if let g = w.gameMode { Text(g).font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond) }
                    if let v = w.versionName { Text(v).font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond) }
                    Text(ByteCountFormatter.string(fromByteCount: w.sizeBytes, countStyle: .file))
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                }
                if let t = w.lastPlayed {
                    Text("最后游玩：\(t.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond.opacity(0.8))
                }
            }
            Spacer()

            Button { detail = w } label: {
                Image(systemName: "info.circle").font(.system(size: 14))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Button { deleteTarget = w } label: {
                Image(systemName: "trash").font(.system(size: 13))
                    .foregroundStyle(ZLTheme.danger)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var filtered: [ZLWorldInfo] {
        guard !search.isEmpty else { return worlds }
        return worlds.filter {
            ($0.levelName ?? "").localizedCaseInsensitiveContains(search) ||
            $0.folderName.localizedCaseInsensitiveContains(search)
        }
    }

    private func reload() {
        let fm = FileManager.default
        try? fm.createDirectory(at: savesDir, withIntermediateDirectories: true)
        guard let dirs = try? fm.contentsOfDirectory(at: savesDir,
                                                     includingPropertiesForKeys: [.isDirectoryKey]) else {
            worlds = []
            return
        }
        worlds = dirs.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.compactMap { dir in
            let levelDat = dir.appendingPathComponent("level.dat")
            let info = LevelDatParser.parse(levelDat)
            let size = directorySize(dir)
            return ZLWorldInfo(folderName: dir.lastPathComponent,
                               path: dir,
                               levelName: info?.levelName,
                               gameMode: info?.gameMode,
                               versionName: info?.versionName,
                               lastPlayed: info?.lastPlayed,
                               sizeBytes: size,
                               iconData: info?.icon,
                               seed: info?.seed)
        }
        .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    private func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in en {
            if let s = try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(s)
            }
        }
        return total
    }
}

// MARK: - 世界详情
struct WorldDetailSheet: View {
    let world: ZLWorldInfo
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("世界") {
                    row("名称", world.levelName ?? "—")
                    row("文件夹", world.folderName)
                    row("游戏模式", world.gameMode ?? "—")
                    row("版本", world.versionName ?? "—")
                    row("大小", ByteCountFormatter.string(fromByteCount: world.sizeBytes, countStyle: .file))
                    if let s = world.seed { row("种子", "\(s)") }
                    if let t = world.lastPlayed {
                        row("最后游玩", t.formatted(date: .long, time: .shortened))
                    }
                }
            }
            .navigationTitle("存档详情")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { onClose() }
                }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - level.dat 解析（gzip + NBT）
struct LevelDatInfo {
    var levelName: String?
    var gameMode: String?
    var versionName: String?
    var lastPlayed: Date?
    var seed: Int64?
    var icon: Data?
}

enum LevelDatParser {
    static func parse(_ url: URL) -> LevelDatInfo? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        // level.dat 是 gzip 压缩的
        let nbt: Data
        if raw.count > 2 && raw[0] == 0x1F && raw[1] == 0x8B {
            guard let d = gunzip(raw) else { return nil }
            nbt = d
        } else {
            nbt = raw
        }
        let root = NBTReader.parse(nbt)
        return root.flatMap(makeInfo)
    }

    private static func makeInfo(_ root: [String: Any]) -> LevelDatInfo? {
        // root: { "": { Data: { ... } } }
        guard let dataDict = (root[""] as? [String: Any])?["Data"] as? [String: Any] else { return nil }
        var info = LevelDatInfo()
        info.levelName = dataDict["LevelName"] as? String
        if let gm = dataDict["GameType"] as? Int32 {
            info.gameMode = ["生存", "创造", "冒险", "旁观"][safe: Int(gm)]
        }
        if let v = dataDict["Version"] as? [String: Any] {
            info.versionName = v["Name"] as? String
        }
        if let t = dataDict["LastPlayed"] as? Int64 {
            info.lastPlayed = Date(timeIntervalSince1970: Double(t) / 1000)
        }
        info.seed = dataDict["RandomSeed"] as? Int64
        if let iconStr = dataDict["icon"] as? String,
           let comma = iconStr.firstIndex(of: ",") {
            info.icon = Data(base64Encoded: String(iconStr[iconStr.index(after: comma)...]))
        }
        return info
    }

    /// gzip 解压（用 Compression framework 的 zlib，跳过 10 字节头）
    private static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }
        // 解析 gzip 头长度
        var offset = 10
        let flg = data[3]
        if flg & 0x04 != 0 {  // FEXTRA
            guard offset + 2 <= data.count else { return nil }
            let xlen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flg & 0x08 != 0 {  // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x10 != 0 {  // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x02 != 0 { offset += 2 }  // FHCRC
        guard offset < data.count - 8 else { return nil }

        let deflated = data.subdata(in: offset..<(data.count - 8))
        // 估算解压大小（按 10 倍）
        var size = max(deflated.count * 10, 4096)
        for _ in 0..<3 {
            var out = Data(count: size)
            let n: Int = out.withUnsafeMutableBytes { dst in
                guard let dp = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return deflated.withUnsafeBytes { src in
                    guard let sp = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(dp, size, sp, deflated.count, nil, COMPRESSION_ZLIB)
                }
            }
            if n > 0 && n < size { return out.prefix(n) }
            size *= 4
        }
        return nil
    }
}

// MARK: - 最小 NBT 读取器（支持 gzip 解压后的二进制 NBT）
enum NBTReader {
    static func parse(_ data: Data) -> [String: Any]? {
        var r = Reader(data: data, offset: 0)
        guard let tag = r.u8() else { return nil }
        guard tag == 10 else { return nil }   // TAG_Compound
        _ = r.string()                        // 根名字
        return r.compound()
    }

    struct Reader {
        let data: Data
        var offset: Int

        mutating func u8() -> UInt8? {
            guard offset < data.count else { return nil }
            let v = data[offset]; offset += 1
            return v
        }

        mutating func i16() -> Int16? {
            guard offset + 2 <= data.count else { return nil }
            let v = Int16(bitPattern: UInt16(data[offset]) << 8 | UInt16(data[offset + 1]))
            offset += 2
            return v
        }

        mutating func i32() -> Int32? {
            guard offset + 4 <= data.count else { return nil }
            var v: UInt32 = 0
            for i in 0..<4 { v = (v << 8) | UInt32(data[offset + i]) }
            offset += 4
            return Int32(bitPattern: v)
        }

        mutating func i64() -> Int64? {
            guard offset + 8 <= data.count else { return nil }
            var v: UInt64 = 0
            for i in 0..<8 { v = (v << 8) | UInt64(data[offset + i]) }
            offset += 8
            return Int64(bitPattern: v)
        }

        mutating func f32() -> Float? {
            guard let i = i32() else { return nil }
            return Float(bitPattern: UInt32(bitPattern: i))
        }

        mutating func f64() -> Double? {
            guard let i = i64() else { return nil }
            return Double(bitPattern: UInt64(bitPattern: i))
        }

        mutating func string() -> String? {
            guard let len = i16(), len >= 0 else { return nil }
            let n = Int(len)
            guard offset + n <= data.count else { return nil }
            let s = String(data: data.subdata(in: offset..<(offset + n)), encoding: .utf8)
            offset += n
            return s
        }

        mutating func compound() -> [String: Any] {
            var dict: [String: Any] = [:]
            while let tag = u8() {
                if tag == 0 { break }     // TAG_End
                guard let name = string() else { break }
                guard let value = payload(tag: tag) else { break }
                dict[name] = value
            }
            return dict
        }

        mutating func payload(tag: UInt8) -> Any? {
            switch tag {
            case 1: return u8().map { Int8(bitPattern: $0) }
            case 2: return i16()
            case 3: return i32()
            case 4: return i64()
            case 5: return f32()
            case 6: return f64()
            case 7:
                guard let len = i32(), len >= 0 else { return nil }
                let n = Int(len)
                guard offset + n <= data.count else { return nil }
                let arr = [UInt8](data.subdata(in: offset..<(offset + n)))
                offset += n
                return arr
            case 8: return string()
            case 9:
                guard let itemType = u8(), let len = i32(), len >= 0 else { return nil }
                var arr: [Any] = []
                for _ in 0..<Int(len) {
                    guard let v = payload(tag: itemType) else { break }
                    arr.append(v)
                }
                return arr
            case 10: return compound()
            case 11:
                guard let len = i32(), len >= 0 else { return nil }
                let n = Int(len)
                guard offset + n * 4 <= data.count else { return nil }
                var arr: [Int32] = []
                for _ in 0..<n { if let v = i32() { arr.append(v) } }
                return arr
            case 12:
                guard let len = i32(), len >= 0 else { return nil }
                let n = Int(len)
                guard offset + n * 8 <= data.count else { return nil }
                var arr: [Int64] = []
                for _ in 0..<n { if let v = i64() { arr.append(v) } }
                return arr
            default:
                return nil
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
