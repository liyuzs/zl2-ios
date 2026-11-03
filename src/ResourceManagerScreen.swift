// ZL2-iOS · 资源包 / 光影包 / 截图 管理
// 参考：ZL2 的 ResourcePackManageScreen.kt / ShadersManagerScreen.kt / ScreenshotsManagerScreen.kt
import SwiftUI

// MARK: - 通用资源项
struct ZLResourceItem: Identifiable, Equatable {
    var id = UUID()
    var fileName: String
    var path: URL
    var sizeBytes: Int64
    var enabled: Bool
    var packName: String?
    var packDescription: String?
    var packVersion: String?
    var iconData: Data?
}

enum ZLResourceKind: String {
    case resourcePack = "资源包"
    case shaderPack = "光影包"
    case screenshot = "截图"

    var folder: String {
        switch self {
        case .resourcePack: return "resourcepacks"
        case .shaderPack: return "shaderpacks"
        case .screenshot: return "screenshots"
        }
    }

    var icon: String {
        switch self {
        case .resourcePack: return "paintbrush"
        case .shaderPack: return "sun.max"
        case .screenshot: return "photo"
        }
    }
}

// MARK: - 通用资源管理页
struct ResourceManagerScreen: View {
    var kind: ZLResourceKind
    var versionID: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var items: [ZLResourceItem] = []
    @State private var search = ""
    @State private var deleteTarget: ZLResourceItem?
    @State private var preview: ZLResourceItem?

    private var folderURL: URL {
        VersionRepository.shared.mcRoot.appendingPathComponent(kind.folder, isDirectory: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "\(kind.rawValue)管理", onBack: onBack, onHome: onHome)

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

                Text("共 \(filtered.count) 个").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                Spacer()
                ZLSearchField(placeholder: "搜索\(kind.rawValue)", text: $search, width: 180)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 8) {
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            ZLWaveLine()
                            Text(search.isEmpty ? "还没有\(kind.rawValue)" : "没有找到相关\(kind.rawValue)")
                                .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                            Text("把文件放进 \(kind.folder) 目录")
                                .font(.system(size: 10.5))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 48)
                    }
                    ForEach(filtered) { item in
                        row(item)
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { reload() }
        .alert("删除\(kind.rawValue)", isPresented: Binding(get: { deleteTarget != nil },
                                                          set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let t = deleteTarget { try? FileManager.default.removeItem(at: t.path) }
                deleteTarget = nil
                reload()
            }
        } message: {
            Text("确定删除「\(deleteTarget?.fileName ?? "")」？")
        }
        .sheet(item: $preview) { p in
            ResourcePreviewSheet(item: p, kind: kind) { preview = nil }
        }
    }

    private func row(_ item: ZLResourceItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧图标：真实预览图或类型图标，44×44
            Group {
                if let d = item.iconData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.enabled ? ZLTheme.primarySoft : ZLTheme.surfaceAlt)
                        Image(systemName: kind.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(item.enabled ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.packName ?? item.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.enabled ? ZLTheme.textPrimary : ZLTheme.textSecond)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if kind != .screenshot {
                        ZLCardStatusBadge(enabled: item.enabled)
                    }
                }

                if let d = item.packDescription, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 底部小胶囊标签 + 右侧文件大小
                HStack(spacing: 5) {
                    ZLCardTag(text: kind.rawValue)
                    if let v = item.packVersion { ZLCardTag(text: v) }
                    if kind == .screenshot {
                        ZLCardTag(text: item.path.pathExtension.uppercased())
                    } else if !item.enabled {
                        ZLCardTag(text: "已禁用")
                    }
                    Spacer(minLength: 8)
                    ZLCardMeta(icon: "internaldrive",
                               text: ByteCountFormatter.string(fromByteCount: item.sizeBytes,
                                                              countStyle: .file))
                }
                .padding(.top, 1)
            }

            VStack(alignment: .trailing, spacing: 4) {
                if kind != .screenshot {
                    Toggle("", isOn: Binding(get: { item.enabled }, set: { toggle(item, $0) }))
                        .labelsHidden()
                        .tint(ZLTheme.primary)
                        .scaleEffect(0.78)
                        .frame(width: 44, height: 24)
                }

                HStack(spacing: 2) {
                    Button { preview = item } label: {
                        Image(systemName: kind == .screenshot ? "eye" : "info.circle")
                            .font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button { deleteTarget = item } label: {
                        Image(systemName: "trash").font(.system(size: 12))
                            .foregroundStyle(ZLTheme.danger).frame(width: 24, height: 24)
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

    private var filtered: [ZLResourceItem] {
        guard !search.isEmpty else { return items }
        return items.filter {
            ($0.packName ?? "").localizedCaseInsensitiveContains(search) ||
            $0.fileName.localizedCaseInsensitiveContains(search)
        }
    }

    private func reload() {
        let fm = FileManager.default
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(at: folderURL,
                                                     includingPropertiesForKeys: [.fileSizeKey]) else {
            items = []
            return
        }
        items = files.filter { f in
            if kind == .screenshot {
                return ["png", "jpg", "jpeg"].contains(f.pathExtension.lowercased())
            }
            return ["zip", "jar"].contains(f.pathExtension.lowercased()) ||
                   (try? f.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.map { url in
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey])
            let enabled = !url.lastPathComponent.hasSuffix(".disabled")
            var info: PackMetaInfo? = nil
            if kind != .screenshot { info = PackMetaParser.parse(url) }
            var iconData: Data? = nil
            if kind == .screenshot { iconData = try? Data(contentsOf: url) }
            return ZLResourceItem(fileName: url.lastPathComponent,
                                  path: url,
                                  sizeBytes: Int64(attrs?.fileSize ?? 0),
                                  enabled: enabled,
                                  packName: info?.name,
                                  packDescription: info?.description,
                                  packVersion: info?.version,
                                  iconData: iconData)
        }
        .sorted { $0.fileName.lowercased() < $1.fileName.lowercased() }
    }

    private func toggle(_ item: ZLResourceItem, _ on: Bool) {
        let fm = FileManager.default
        let src = item.path
        if on, src.lastPathComponent.hasSuffix(".disabled") {
            try? fm.moveItem(at: src, to: src.deletingPathExtension())
        } else if !on, !src.lastPathComponent.hasSuffix(".disabled") {
            try? fm.moveItem(at: src, to: src.appendingPathExtension("disabled"))
        }
        reload()
    }
}

// MARK: - 预览
struct ResourcePreviewSheet: View {
    let item: ZLResourceItem
    let kind: ZLResourceKind
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if kind == .screenshot, let d = item.iconData, let img = UIImage(data: d) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: img).resizable().scaledToFit()
                    }
                } else {
                    List {
                        Section("信息") {
                            row("文件名", item.fileName)
                            if let n = item.packName { row("名称", n) }
                            if let v = item.packVersion { row("版本", v) }
                            row("大小", ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                            row("状态", item.enabled ? "已启用" : "已禁用")
                        }
                        if let d = item.packDescription, !d.isEmpty {
                            Section("描述") { Text(d) }
                        }
                    }
                }
            }
            .navigationTitle(kind.rawValue)
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

// MARK: - pack.mcmeta 解析
struct PackMetaInfo {
    var name: String?
    var description: String?
    var version: String?
}

enum PackMetaParser {
    static func parse(_ url: URL) -> PackMetaInfo? {
        // 资源包是 zip，光影包是目录或 zip
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        if isDir.boolValue {
            let meta = url.appendingPathComponent("pack.mcmeta")
            if let d = try? Data(contentsOf: meta) { return decode(d) }
            // 光影包：读 shaders/shaders.properties
            let props = url.appendingPathComponent("shaders/shaders.properties")
            if let t = try? String(contentsOf: props, encoding: .utf8) {
                var info = PackMetaInfo()
                for line in t.split(separator: "\n") {
                    if line.hasPrefix("name=") { info.name = String(line.dropFirst(5)) }
                    if line.hasPrefix("comment=") { info.description = String(line.dropFirst(8)) }
                    if line.hasPrefix("version=") { info.version = String(line.dropFirst(8)) }
                }
                return info
            }
            return nil
        } else {
            guard let data = try? Data(contentsOf: url),
                  let meta = ZipReader.extract(data: data, entryName: "pack.mcmeta") else {
                // 光影包 zip
                if let data = try? Data(contentsOf: url),
                   let props = ZipReader.extract(data: data, entryName: "shaders/shaders.properties"),
                   let t = String(data: props, encoding: .utf8) {
                    var info = PackMetaInfo()
                    for line in t.split(separator: "\n") {
                        let l = line.trimmingCharacters(in: .whitespaces)
                        if l.hasPrefix("name=") { info.name = String(l.dropFirst(5)) }
                        if l.hasPrefix("comment=") { info.description = String(l.dropFirst(8)) }
                        if l.hasPrefix("version=") { info.version = String(l.dropFirst(8)) }
                    }
                    return info
                }
                return nil
            }
            return decode(meta)
        }
    }

    private static func decode(_ data: Data) -> PackMetaInfo? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pack = o["pack"] as? [String: Any] else { return nil }
        var info = PackMetaInfo()
        info.description = pack["description"] as? String
        if let fv = pack["pack_format"] as? Int { info.version = "格式 \(fv)" }
        return info
    }
}
