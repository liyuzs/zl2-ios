// ZL2-iOS · 存档管理
// 参考：ZL2 的 SavesManagerScreen.kt
// 功能：扫描 saves 目录、解析 level.dat（gzip+NBT）、显示世界信息
import SwiftUI
import Compression
import Combine

// MARK: - 管理页共用卡片小件（对齐真机下载卡片的视觉语言）
// 模组 / 存档 / 资源包三个管理页共用，避免三处样式漂移

/// 空状态波浪线（真机：两端波浪 + 中间直线）
struct ZLWaveLine: View {
    var width: CGFloat = 132

    var body: some View {
        ZLWaveShape()
            .stroke(ZLTheme.primary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: width, height: 14)
    }
}

private struct ZLWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let amp = rect.height / 2
        let waveW: CGFloat = 26
        let gap = max(0, rect.width - waveW * 2)
        path.move(to: CGPoint(x: 0, y: midY))
        path.addQuadCurve(to: CGPoint(x: waveW / 2, y: midY),
                          control: CGPoint(x: waveW / 4, y: midY - amp))
        path.addQuadCurve(to: CGPoint(x: waveW, y: midY),
                          control: CGPoint(x: waveW * 0.75, y: midY + amp))
        path.addLine(to: CGPoint(x: waveW + gap, y: midY))
        path.addQuadCurve(to: CGPoint(x: waveW + gap + waveW / 2, y: midY),
                          control: CGPoint(x: waveW + gap + waveW / 4, y: midY - amp))
        path.addQuadCurve(to: CGPoint(x: waveW + gap + waveW, y: midY),
                          control: CGPoint(x: waveW + gap + waveW * 0.75, y: midY + amp))
        return path
    }
}

/// 小胶囊标签（浅色底 + 深主色字）
struct ZLCardTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(ZLTheme.primaryDeep)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(ZLTheme.primarySoft.opacity(0.55))
            .clipShape(Capsule())
    }
}

/// 图标 + 数字的次要元信息（替代真机的 ↓下载量 / ♡点赞位）
struct ZLCardMeta: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 9.5))
        }
        .foregroundStyle(ZLTheme.textSecond.opacity(0.9))
        .lineLimit(1)
    }
}

/// 右上角状态徽标（真机来源徽标的位置）
struct ZLCardStatusBadge: View {
    let enabled: Bool

    var body: some View {
        Text(enabled ? "已启用" : "已禁用")
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(enabled ? ZLTheme.textOnGold : ZLTheme.textSecond)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(enabled ? ZLTheme.primaryDeep : ZLTheme.surfaceAlt)
            .clipShape(Capsule())
    }
}

/// 搜索框（放大镜 + 圆角 10）
struct ZLSearchField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 190

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 34)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(ZLTheme.cardStroke.opacity(0.25), lineWidth: 0.8))
    }
}

/// 列表卡片外观：浅色底、圆角 14、极浅描边与阴影
struct ZLCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ZLTheme.cardStroke.opacity(0.25), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.035), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func zlCardSurface() -> some View { modifier(ZLCardSurface()) }
}


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
    @State private var isLoading = true
    @State private var loadError: String?
    // iOS 原生交互：右滑收藏（本地持久化）/ 轻提示
    @AppStorage("zl.saves.favorites") private var favoritesRaw = ""
    @State private var toast: String?

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
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ZLTheme.cardStroke.opacity(0.22), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Text("共 \(filtered.count) 个世界")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)

                Spacer()

                ZLSearchField(placeholder: "搜索世界", text: $search, width: 190)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)

            // 用 List 才能拿到 iOS 原生的 swipeActions（左滑删除 / 右滑收藏）
            List {
                if isLoading {
                    // 首屏骨架：解析 level.dat + 统计每个世界的目录大小要花点时间
                    ZLSkeletonList(count: 4, height: 76)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: ZLTheme.screenPadding,
                                                  bottom: 10, trailing: ZLTheme.screenPadding))
                } else if let e = loadError {
                    errorState(e)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 20, leading: ZLTheme.screenPadding,
                                                  bottom: 20, trailing: ZLTheme.screenPadding))
                } else if filtered.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                } else {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, w in
                        worldRow(w)
                            .popIn(delay: Double(min(idx, 8)) * 0.035)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: ZLTheme.screenPadding,
                                                      bottom: 5, trailing: ZLTheme.screenPadding))
                            // 左滑：删除 / 备份
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = w
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    backup(w)
                                } label: {
                                    Label("备份", systemImage: "externaldrive.badge.plus")
                                }
                                .tint(ZLTheme.primary)
                            }
                            // 右滑：收藏
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggleFavorite(w)
                                } label: {
                                    Label(isFavorite(w) ? "取消收藏" : "收藏",
                                          systemImage: isFavorite(w) ? "star.slash.fill" : "star.fill")
                                }
                                .tint(ZLTheme.warning)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            // iOS 原生下拉刷新
            .refreshable { reload() }
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
        .overlay(alignment: .top) { toastView }
        // ⌘R（iPad 键盘）重新扫描存档
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            reload()
        }
    }

    private func worldRow(_ w: ZLWorldInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 世界图标（level.dat 里的 icon，44×44 圆角 10）
            Group {
                if let d = w.iconData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ZLTheme.primarySoft)
                        Image(systemName: "map.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(ZLTheme.primaryDeep)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(w.levelName ?? w.folderName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                    Text(w.folderName)
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(1)
                    if isFavorite(w) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ZLTheme.warning)
                    }
                    Spacer(minLength: 6)
                }

                // 游戏模式 / 版本 / 大小 小胶囊 + 最后游玩时间
                HStack(spacing: 5) {
                    if let g = w.gameMode { ZLCardTag(text: g) }
                    if let v = w.versionName { ZLCardTag(text: v) }
                    ZLCardTag(text: ByteCountFormatter.string(fromByteCount: w.sizeBytes,
                                                             countStyle: .file))
                    Spacer(minLength: 8)
                    ZLCardMeta(icon: "clock", text: lastPlayedText(w))
                }
                .padding(.top, 1)
            }

            HStack(spacing: 2) {
                Button { detail = w } label: {
                    Image(systemName: "info.circle").font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)

                Button { deleteTarget = w } label: {
                    Image(systemName: "trash").font(.system(size: 12))
                        .foregroundStyle(ZLTheme.danger)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .zlCardSurface()
        .contentShape(Rectangle())
        // iOS 长按菜单
        .contextMenu {
            Button { detail = w } label: {
                Label("进入", systemImage: "arrow.right.circle")
            }
            Button { backup(w) } label: {
                Label("备份", systemImage: "externaldrive.badge.plus")
            }
            // 有可用的备份时才显示恢复
            if let bk = latestBackup(for: w) {
                Button { restore(w, from: bk) } label: {
                    Label("恢复到 \(backupTimeText(bk))", systemImage: "arrow.uturn.backward")
                }
            }
            Button { copyWorldName(w) } label: {
                Label("复制名称", systemImage: "doc.on.doc")
            }
            Button { toggleFavorite(w) } label: {
                Label(isFavorite(w) ? "取消收藏" : "收藏",
                      systemImage: isFavorite(w) ? "star.slash" : "star")
            }
            Divider()
            Button(role: .destructive) { deleteTarget = w } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func lastPlayedText(_ w: ZLWorldInfo) -> String {
        guard let t = w.lastPlayed else { return "从未游玩" }
        return "最后游玩 \(t.formatted(date: .abbreviated, time: .shortened))"
    }

    private var filtered: [ZLWorldInfo] {
        guard !search.isEmpty else { return worlds }
        return worlds.filter {
            ($0.levelName ?? "").localizedCaseInsensitiveContains(search) ||
            $0.folderName.localizedCaseInsensitiveContains(search)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if search.isEmpty {
            ZLEmptyState(
                icon: "map",
                title: "还没有存档",
                detail: "进入游戏后创建一个世界，存档会自动出现在这里。\n刚在游戏里存过档的话，点「重新扫描」",
                actionTitle: "重新扫描",
                action: { reload() })
        } else {
            ZLEmptyState(
                icon: "magnifyingglass",
                title: "没有找到相关存档",
                detail: "换个关键词试试，或者清空搜索看全部 \(worlds.count) 个世界",
                actionTitle: "清空搜索",
                action: { search = "" })
        }
    }

    /// 读不了 saves 目录时的提示（以前这里会静默当成"没有存档"）
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ZLTheme.warning)
            Text("存档列表没能读出来")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                ZLInteraction.haptic(.light)
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

    private func reload() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: savesDir, withIntermediateDirectories: true)
            let dirs = try fm.contentsOfDirectory(at: savesDir,
                                                  includingPropertiesForKeys: [.isDirectoryKey])
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
            loadError = nil
        } catch {
            worlds = []
            loadError = "读不了 saves 目录：\(ZLFriendlyError.text(error))"
        }
        isLoading = false
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

    // MARK: - iOS 交互动作

    private var favoriteSet: Set<String> {
        Set(favoritesRaw.split(separator: "\n").map(String.init))
    }

    private func isFavorite(_ w: ZLWorldInfo) -> Bool {
        favoriteSet.contains(w.folderName)
    }

    /// 右滑收藏：状态存在 UserDefaults，重启后还在
    private func toggleFavorite(_ w: ZLWorldInfo) {
        var s = favoriteSet
        if s.contains(w.folderName) { s.remove(w.folderName) } else { s.insert(w.folderName) }
        favoritesRaw = s.sorted().joined(separator: "\n")
        ZLInteraction.haptic(.selection)
        showToast(s.contains(w.folderName) ? "已收藏「\(w.levelName ?? w.folderName)」"
                                           : "已取消收藏")
    }

    /// 备份：把整个存档目录复制一份到 saves/ 下（不覆盖原存档）
    private func backup(_ w: ZLWorldInfo) {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let name = "\(w.folderName)-备份-\(df.string(from: Date()))"
        let dst = savesDir.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.copyItem(at: w.path, to: dst)
            ZLInteraction.haptic(.medium)
            showToast("已备份为 \(name)")
        } catch {
            showToast("备份失败：\(ZLFriendlyError.text(error))")
        }
        reload()
    }

    private func copyWorldName(_ w: ZLWorldInfo) {
        ZLInteraction.haptic(.light)
        ZLInteraction.copy(w.levelName ?? w.folderName)
        showToast("已复制存档名称")
    }

    // MARK: - 轻提示

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ZLTheme.primaryDeep))
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard toast == text else { return }
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        }
    }

    // MARK: 备份恢复

    /// 找一个存档最新的备份目录（命名规则：<原名>-备份-<yyyyMMdd-HHmmss>）
    private func latestBackup(for w: ZLWorldInfo) -> URL? {
        let fm = FileManager.default
        guard let all = try? fm.contentsOfDirectory(at: savesDir,
                                                    includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        let prefix = "\(w.folderName)-备份-"
        let matches = all.filter { $0.lastPathComponent.hasPrefix(prefix) }
        return matches.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }
    }

    /// 从备份目录名里抽出时间，用于菜单文字
    private func backupTimeText(_ url: URL) -> String {
        let name = url.lastPathComponent
        guard let r = name.range(of: "-备份-") else { return "备份" }
        return String(name[r.upperBound...])
    }

    /// 把备份内容覆盖回原存档目录
    private func restore(_ w: ZLWorldInfo, from backupURL: URL) {
        let fm = FileManager.default
        let park = savesDir.appendingPathComponent("\(w.folderName)-恢复前-\(Int(Date().timeIntervalSince1970))")
        var parked = false
        do {
            // 先把当前存档挪到一边，避免覆盖失败丢数据
            if fm.fileExists(atPath: w.path.path) {
                try fm.moveItem(at: w.path, to: park)
                parked = true
            }
            // 备份复制回来
            try fm.copyItem(at: backupURL, to: w.path)
            try? fm.removeItem(at: park)
            ZLInteraction.haptic(.medium)
            showToast("已恢复到 \(backupTimeText(backupURL))")
        } catch {
            // 失败必须把原存档挪回去，否则存档就从列表里消失了
            if parked {
                try? fm.moveItem(at: park, to: w.path)
            }
            showToast("恢复失败：\(ZLFriendlyError.text(error))")
        }
        reload()
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
