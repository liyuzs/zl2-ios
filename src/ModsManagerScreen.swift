// ZL2-iOS · 模组管理
// 参考：ZL2 的 ModsManagerScreen.kt（1536 行）
// 功能：扫描 mods 目录、真实 jar 解析、排序、启用/禁用、删除
import SwiftUI
import Compression

// MARK: - 模组信息
struct ZLModInfo: Identifiable, Equatable {
    var id = UUID()
    var fileName: String
    var path: URL
    var sizeBytes: Int64
    var modified: Date
    var enabled: Bool
    // 从 fabric.mod.json / mods.toml 解析
    var modName: String?
    var modVersion: String?
    var modAuthors: [String] = []
    var modDescription: String?
    var modId: String?
    var loader: String? = nil
}

enum ZLModsSort: String, CaseIterable {
    case fileName = "文件名"
    case modified = "修改时间"
}

// MARK: - 模组管理页
struct ModsManagerScreen: View {
    var versionID: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var mods: [ZLModInfo] = []
    /// 有更新的模组：modId → 最新版本号
    @State private var updates: [String: String] = [:]
    @State private var updating = false
    @State private var sort: ZLModsSort = .fileName
    @State private var ascending = true
    @State private var search = ""
    @State private var deleteTarget: ZLModInfo?
    @State private var detail: ZLModInfo?
    @State private var toast = ""
    @State private var showImporter = false
    @State private var isLoading = true
    @State private var loadError: String?

    private var modsDir: URL {
        VersionRepository.shared.mcRoot
            .appendingPathComponent("mods", isDirectory: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "模组管理 · \(versionID)", onBack: onBack, onHome: onHome)

            // 工具栏
            HStack(spacing: 8) {
                Button { reload() } label: { toolChip("刷新", "arrow.clockwise") }
                Button {
                    ZLHaptic.light()
                    checkUpdates()
                } label: {
                    toolChip(updating ? "检查中…" : "查更新", "arrow.triangle.2.circlepath")
                }
                .disabled(updating)
                    .buttonStyle(.plain)
                Button { sort = sort == .fileName ? .modified : .fileName } label: {
                    toolChip("排序：\(sort.rawValue)", "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                Button { ascending.toggle() } label: {
                    toolChip(ascending ? "升序" : "降序", ascending ? "arrow.up" : "arrow.down")
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showImporter = true } label: {
                    toolChip("导入模组", "square.and.arrow.down")
                }
                .buttonStyle(.plain)

                ZLSearchField(placeholder: "搜索模组", text: $search, width: 190)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)

            // 统计
            HStack {
                Text("共 \(filtered.count) 个模组 · \(enabledCount) 个已启用")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                Spacer()
                if !toast.isEmpty {
                    Text(toast).font(.system(size: 11)).foregroundStyle(ZLTheme.success)
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    if isLoading {
                        // 首屏骨架：扫目录 + 解析 jar 需要一点时间，先别闪空状态
                        ZLSkeletonList(count: 4, height: 86)
                    } else if let e = loadError {
                        errorState(e)
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, m in
                            modRow(m)
                                .popIn(delay: Double(min(idx, 10)) * 0.035)
                        }
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { reload() }
        .alert("删除模组", isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let t = deleteTarget { delete(t) }
                deleteTarget = nil
            }
        } message: {
            Text("确定删除「\(deleteTarget?.fileName ?? "")」？")
        }
        .sheet(item: $detail) { m in
            ModDetailSheet(mod: m) { detail = nil }
        }
        .sheet(isPresented: $showImporter) {
            FileSelectorScreen(
                startURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                mode: .file(extensions: ["jar"]),
                title: "导入模组",
                onBack: { showImporter = false },
                onHome: { showImporter = false },
                onSelect: { url in
                    showImporter = false
                    importMod(url)
                })
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if search.isEmpty {
            ZLEmptyState(
                icon: "puzzlepiece.extension",
                title: "还没有模组",
                detail: "mods 目录现在是空的。\n可以导入 .jar，或者去下载中心挑一个装",
                actionTitle: "从文件导入 .jar",
                action: { showImporter = true })
        } else {
            ZLEmptyState(
                icon: "magnifyingglass",
                title: "没有找到相关模组",
                detail: "换个关键词试试，或者清空搜索看全部 \(mods.count) 个",
                actionTitle: "清空搜索",
                action: { search = "" })
        }
    }

    /// 读不了目录时的提示（之前这里会静默当成"没有模组"）
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ZLTheme.warning)
            Text("模组列表没能读出来")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                ZLHaptic.light()
                reload()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium))
                    Text("重试").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ZLTheme.primaryDeep)
                .padding(.horizontal, 14).frame(height: 34)
                .background(ZLTheme.primarySoft)
                .clipShape(Capsule())
            }
            .buttonStyle(ZLPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private func modRow(_ m: ZLModInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧方形图标（对齐真机 44×44）
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(m.enabled ? ZLTheme.primarySoft : ZLTheme.surfaceAlt)
                Image(systemName: m.enabled ? "puzzlepiece.fill" : "puzzlepiece")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(m.enabled ? ZLTheme.primaryDeep : ZLTheme.textSecond)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(m.modName ?? m.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(m.enabled ? ZLTheme.textPrimary : ZLTheme.textSecond)
                        .lineLimit(1)
                    if !m.modAuthors.isEmpty {
                        Text("作者: \(m.modAuthors.prefix(2).joined(separator: "、"))")
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let id = m.modId, let latest = updates[id] {
                        Text("新版 \(latest)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(ZLTheme.primary))
                    }
                    ZLCardStatusBadge(enabled: m.enabled)
                }

                if let d = m.modDescription, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 底部标签 + 右侧真实元数据（大小 / 修改时间）
                HStack(spacing: 5) {
                    ForEach(modTags(m), id: \.self) { ZLCardTag(text: $0) }
                    Spacer(minLength: 8)
                    ZLCardMeta(icon: "internaldrive",
                               text: ByteCountFormatter.string(fromByteCount: m.sizeBytes,
                                                              countStyle: .file))
                    ZLCardMeta(icon: "clock",
                               text: m.modified.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(.top, 1)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { m.enabled },
                    set: { toggle(m, $0) }
                ))
                .labelsHidden()
                .tint(ZLTheme.primary)
                .scaleEffect(0.78)
                .frame(width: 44, height: 24)

                HStack(spacing: 2) {
                    Button { detail = m } label: {
                        Image(systemName: "info.circle").font(.system(size: 13))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button { deleteTarget = m } label: {
                        Image(systemName: "trash").font(.system(size: 12))
                            .foregroundStyle(ZLTheme.danger)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .zlCardSurface()
    }

    private func modTags(_ m: ZLModInfo) -> [String] {
        var tags: [String] = []
        if let l = m.loader, !l.isEmpty { tags.append(l) }
        if let v = m.modVersion, !v.isEmpty { tags.append("v\(v)") }
        if !m.enabled { tags.append("已禁用") }
        if tags.isEmpty { tags.append("JAR") }
        return Array(tags.prefix(3))
    }

    private func toolChip(_ t: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(t).font(.system(size: 11))
        }
        .foregroundStyle(ZLTheme.textSecond)
        .padding(.horizontal, 10).frame(height: 32)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(ZLTheme.cardStroke.opacity(0.22), lineWidth: 0.8))
    }

    // MARK: 数据
    private var enabledCount: Int { mods.filter { $0.enabled }.count }

    private var filtered: [ZLModInfo] {
        var list = mods
        if !search.isEmpty {
            list = list.filter {
                ($0.modName ?? "").localizedCaseInsensitiveContains(search) ||
                $0.fileName.localizedCaseInsensitiveContains(search)
            }
        }
        // 排序（对齐 ZL2：文件名忽略大小写 / 修改时间倒序）
        switch sort {
        case .fileName:
            list.sort { a, b in
                let r = a.fileName.lowercased().compare(b.fileName.lowercased())
                return ascending ? r == .orderedAscending : r == .orderedDescending
            }
        case .modified:
            list.sort { a, b in
                ascending ? a.modified < b.modified : a.modified > b.modified
            }
        }
        return list
    }

    private func reload() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
            let files = try fm.contentsOfDirectory(at: modsDir,
                                                   includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            // 注意：禁用的模组会被改名成 xxx.jar.disabled，扩展名变成 disabled，
            // 所以要用完整文件名判断，否则禁用后模组会从列表里消失。
            mods = files.filter { f in
                let n = f.lastPathComponent.lowercased()
                return n.hasSuffix(".jar") || n.hasSuffix(".jar.disabled")
            }.map { url in
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let enabled = !url.lastPathComponent.hasSuffix(".disabled")
                let info = ModJarParser.parse(url)
                return ZLModInfo(fileName: url.lastPathComponent,
                                 path: url,
                                 sizeBytes: Int64(attrs?.fileSize ?? 0),
                                 modified: attrs?.contentModificationDate ?? Date.distantPast,
                                 enabled: enabled,
                                 modName: info?.name,
                                 modVersion: info?.version,
                                 modAuthors: info?.authors ?? [],
                                 modDescription: info?.description,
                                 modId: info?.id,
                                 loader: info?.loader)
            }
            loadError = nil
        } catch {
            mods = []
            loadError = "读不了 mods 目录：\(ZLFriendlyError.text(error))"
        }
        isLoading = false
    }

    private func toggle(_ m: ZLModInfo, _ on: Bool) {
        let fm = FileManager.default
        let src = m.path
        if on {
            // .jar.disabled → .jar
            if src.lastPathComponent.hasSuffix(".disabled") {
                let dst = src.deletingPathExtension()
                try? fm.moveItem(at: src, to: dst)
            }
        } else {
            // .jar → .jar.disabled
            let dst = src.appendingPathExtension("disabled")
            try? fm.moveItem(at: src, to: dst)
        }
        reload()
    }

    private func delete(_ m: ZLModInfo) {
        try? FileManager.default.removeItem(at: m.path)
        toast = "已删除 \(m.fileName)"
        reload()
    }

    private func importMod(_ src: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        let dst0 = modsDir.appendingPathComponent(src.lastPathComponent)
        if src.standardizedFileURL == dst0.standardizedFileURL {
            toast = "这个文件已经在 mods 目录里"
            return
        }
        // 同名时自动加序号，不覆盖已有模组
        let base = src.deletingPathExtension().lastPathComponent
        var name = src.lastPathComponent
        var index = 1
        while fm.fileExists(atPath: modsDir.appendingPathComponent(name).path), index < 100 {
            name = "\(base)-\(index).jar"
            index += 1
        }
        do {
            try fm.copyItem(at: src, to: modsDir.appendingPathComponent(name))
            // iOS 兼容性检查（来自 Amethyst 社区实践）
            let lower = name.lowercased()
            if lower.contains("sodium") {
                // sodium 用了 iOS 不支持的优化指令，必须配 podium 才能启动
                let hasPodium = (try? fm.contentsOfDirectory(atPath: modsDir.path))?
                    .contains { $0.lowercased().contains("podium") } ?? false
                if hasPodium {
                    toast = "已导入 \(name)（已检测到 podium，兼容）"
                } else {
                    toast = "已导入 \(name)⚠️ sodium 在 iOS 上必须搭配 podium 才能启动，否则会闪退"
                }
            } else if lower.contains("iris") {
                toast = "已导入 \(name)（光影需要搭配 sodium/podium）"
            } else {
                toast = "已导入 \(name)"
            }
            reload()
        } catch {
            toast = "导入失败：\(ZLFriendlyError.text(error))"
        }
    }
}

// MARK: - 模组详情
struct ModDetailSheet: View {
    let mod: ZLModInfo
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    row("文件名", mod.fileName)
                    if let n = mod.modName { row("名称", n) }
                    if let v = mod.modVersion { row("版本", v) }
                    if let i = mod.modId { row("Mod ID", i) }
                    row("大小", ByteCountFormatter.string(fromByteCount: mod.sizeBytes, countStyle: .file))
                    row("修改时间", mod.modified.formatted(date: .numeric, time: .shortened))
                    row("状态", mod.enabled ? "已启用" : "已禁用")
                }
                if !mod.modAuthors.isEmpty {
                    Section("作者") {
                        ForEach(mod.modAuthors, id: \.self) { Text($0) }
                    }
                }
                if let d = mod.modDescription, !d.isEmpty {
                    Section("描述") { Text(d) }
                }
            }
            .navigationTitle(mod.modName ?? mod.fileName)
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

// MARK: - JAR 元数据解析（fabric.mod.json / mods.toml / META-INF）
struct ModJarInfo {
    var id: String?
    var name: String?
    var version: String?
    var authors: [String]
    var description: String?
    var loader: String? = nil
}

enum ModJarParser {
    /// 解析 fabric.mod.json 或 META-INF/mods.toml
    static func parse(_ url: URL) -> ModJarInfo? {
        // 尝试 fabric.mod.json
        if let data = readEntry(url, "fabric.mod.json"),
           let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let id = o["id"] as? String
            let name = o["name"] as? String
            let version = o["version"] as? String
            let desc = o["description"] as? String
            var authors: [String] = []
            if let arr = o["authors"] as? [[String: Any]] {
                authors = arr.compactMap { $0["name"] as? String }
            } else if let arr = o["authors"] as? [String] {
                authors = arr
            }
            return ModJarInfo(id: id, name: name, version: version,
                              authors: authors, description: desc, loader: "Fabric")
        }

        // 尝试 META-INF/mods.toml（Forge/NeoForge）
        if let data = readEntry(url, "META-INF/mods.toml"),
           let text = String(data: data, encoding: .utf8),
           var info = parseToml(text) {
            info.loader = "Forge"
            return info
        }

        // 尝试 quilt.mod.json
        if let data = readEntry(url, "quilt.mod.json"),
           let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loader = o["quilt_loader"] as? [String: Any] {
            let meta = loader["metadata"] as? [String: Any]
            return ModJarInfo(id: loader["id"] as? String,
                              name: meta?["name"] as? String,
                              version: loader["version"] as? String,
                              authors: [],
                              description: meta?["description"] as? String,
                              loader: "Quilt")
        }

        return nil
    }

    /// 读取 jar（zip）里的一个文件（纯 Swift ZIP 解析，iOS 无 Process）
    private static func readEntry(_ jarURL: URL, _ entry: String) -> Data? {
        guard let data = try? Data(contentsOf: jarURL) else { return nil }
        return ZipReader.extract(data: data, entryName: entry)
    }

    private static func parseToml(_ text: String) -> ModJarInfo? {
        var id: String?, name: String?, version: String?, desc: String?
        var authors: [String] = []
        for line in text.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("modId") { id = value(l) }
            else if l.hasPrefix("displayName") { name = value(l) }
            else if l.hasPrefix("version") { version = value(l) }
            else if l.hasPrefix("description") { desc = value(l) }
            else if l.hasPrefix("authors") { authors = [value(l)] }
        }
        guard id != nil || name != nil else { return nil }
        return ModJarInfo(id: id, name: name, version: version,
                          authors: authors, description: desc)
    }

    private static func value(_ line: String) -> String {
        guard let eq = line.firstIndex(of: "=") else { return "" }
        return line[line.index(after: eq)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}

// MARK: - 最小 ZIP 读取器（iOS 可用，不依赖外部工具）
enum ZipReader {
    /// 从 zip 数据中提取指定文件
    static func extract(data: Data, entryName: String) -> Data? {
        guard let eocd = findEOCD(data) else { return nil }
        // EOCD: 签名4 + disk2 + cdDisk2 + entries2 + entries2 + cdSize4 + cdOffset4 + comment2
        guard eocd + 22 <= data.count else { return nil }
        let cdOffset = readU32(data, at: eocd + 16)
        let cdCount = readU16(data, at: eocd + 10)
        guard cdOffset < data.count else { return nil }

        var p = cdOffset
        for _ in 0..<cdCount {
            guard p + 46 <= data.count else { return nil }
            guard readU32(data, at: p) == 0x02014b50 else { return nil }
            let method = readU16(data, at: p + 10)
            let compSize = readU32(data, at: p + 20)
            let uncompSize = readU32(data, at: p + 24)
            let nameLen = readU16(data, at: p + 28)
            let extraLen = readU16(data, at: p + 30)
            let commentLen = readU16(data, at: p + 32)
            let localOffset = readU32(data, at: p + 42)
            guard p + 46 + nameLen <= data.count else { return nil }
            let nameData = data.subdata(in: (p + 46)..<(p + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? ""

            if name == entryName {
                return extractLocal(data, offset: localOffset, compSize: compSize,
                                    uncompSize: uncompSize, method: method)
            }
            p += 46 + nameLen + extraLen + commentLen
        }
        return nil
    }

    private static func extractLocal(_ data: Data, offset: Int, compSize: Int,
                                     uncompSize: Int, method: Int) -> Data? {
        guard offset + 30 <= data.count else { return nil }
        guard readU32(data, at: offset) == 0x04034b50 else { return nil }
        let nameLen = readU16(data, at: offset + 26)
        let extraLen = readU16(data, at: offset + 28)
        let start = offset + 30 + nameLen + extraLen
        guard start + compSize <= data.count else { return nil }
        let raw = data.subdata(in: start..<(start + compSize))

        if method == 0 { return raw }          // 存储
        if method == 8 { return inflateRaw(raw, expected: uncompSize) }
        return nil
    }

    /// raw deflate 解压（用 Compression framework）
    private static func inflateRaw(_ input: Data, expected: Int) -> Data? {
        guard expected > 0, expected < 64 * 1024 * 1024 else { return nil }
        var out = Data(count: expected)
        let result: Int = out.withUnsafeMutableBytes { dst in
            guard let dstPtr = dst.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return input.withUnsafeBytes { src in
                guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return compression_decode_buffer(dstPtr, expected, srcPtr, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard result > 0 else { return nil }
        return out.prefix(result)
    }

    // MARK: 工具
    private static func findEOCD(_ d: Data) -> Int? {
        guard d.count >= 22 else { return nil }
        let limit = max(0, d.count - 65557)
        var i = d.count - 22
        while i >= limit {
            if readU32(d, at: i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }

    private static func readU16(_ d: Data, at i: Int) -> Int {
        guard i + 2 <= d.count else { return 0 }
        return Int(d[i]) | (Int(d[i + 1]) << 8)
    }

    private static func readU32(_ d: Data, at i: Int) -> Int {
        guard i + 4 <= d.count else { return 0 }
        return Int(d[i]) | (Int(d[i + 1]) << 8) | (Int(d[i + 2]) << 16) | (Int(d[i + 3]) << 24)
    }

    // MARK: 检查更新

    private func checkUpdates() {
        updating = true
        updates.removeAll()
        let snapshot = mods
        Task {
            let api = ModrinthAPI()
            var found: [String: String] = [:]
            for m in snapshot {
                guard let id = m.modId, !id.isEmpty else { continue }
                let (has, latest) = await ZLModUpdater.checkUpdate(
                    modID: id,
                    currentVersion: m.modVersion,
                    gameVersion: nil,
                    loader: m.loader?.lowercased(),
                    api: api
                )
                if has, let v = latest { found[id] = v }
            }
            await MainActor.run {
                updates = found
                updating = false
                if found.isEmpty {
                    showToast("全部模组都是最新版")
                } else {
                    showToast("\(found.count) 个模组有新版本")
                }
            }
        }
    }
}
