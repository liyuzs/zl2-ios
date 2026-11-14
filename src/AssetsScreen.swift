// ZL2-iOS · 资源下载（整合包 / 模组 / 资源包 / 光影 / 存档 / 收藏）
// 依据真机：左侧分类 + 顶部筛选 + 卡片列表；这里做一个通用页，按类型换数据源与筛选项
import SwiftUI
import Combine

// MARK: - 资源类型
enum AssetKind: String, CaseIterable, Identifiable {
    case modpack   = "整合包"
    case mod       = "模组"
    case resource  = "资源包"
    case shader    = "光影"
    case saves     = "存档"
    case favorite  = "收藏"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .modpack:  return "shippingbox.fill"
        case .mod:      return "puzzlepiece.fill"
        case .resource: return "paintbrush.fill"
        case .shader:   return "sun.max.fill"
        case .saves:    return "folder.fill"
        case .favorite: return "heart.fill"
        }
    }

    /// ZL2 里每类内容的分类标签（来自 strings.xml）
    var categories: [String] {
        switch self {
        case .mod:
            return ["世界元素", "生物群系", "维度", "矿物与资源", "天然结构", "科技", "管道与物流",
                    "自动化", "能源", "红石", "食物与烹饪", "农业", "运输", "仓储", "魔法", "冒险",
                    "装饰", "生物", "装备", "信息显示", "服务器", "改良", "支持库", "游戏机制",
                    "性能优化", "多人", "硬核", "战斗", "任务", "探险", "小游戏", "科幻", "空岛", "原版改良"]
        case .modpack:
            return ["FTB 团队制作", "基于地图", "轻量", "大型", "大杂烩", "传统", "科技", "魔法",
                    "冒险", "空岛", "原版改良", "多人", "硬核", "任务"]
        case .resource:
            return ["16x16 像素", "32x32 像素", "64x64 像素", "128x128 像素", "256x256 像素",
                    "512x512 像素及更高", "原版改良", "卡通", "写实", "中世纪", "现代风格"]
        case .shader:
            return ["卡通", "邪门", "奇幻", "半写实", "氛围", "泛光", "彩色照明", "植被",
                    "路径追踪", "PBR", "反射", "阴影", "“土豆”配置", "低等配置", "中等配置", "高等配置"]
        default:
            return []
        }
    }

    var sorts: [String] {
        switch self {
        case .favorite, .saves: return ["最近", "名称"]
        default: return ["相关性", "总下载量", "人气", "最近创建", "最近更新"]
        }
    }
}

// MARK: - 资源条目
struct AssetItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let author: String
    let downloads: String
    let tags: [String]
    let version: String
}

// MARK: - 通用资源页
struct AssetsScreen: View {
    let kind: AssetKind
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onDownload: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var query = ""
    @State private var sort = 0
    // ZL2 的四个筛选维度：目标平台 / 游戏版本 / 类别 / 模组加载器
    @State private var platform = 0
    @State private var gameVersion = 0
    @State private var category = 0
    @State private var modLoader = 0
    // 真实搜索结果
    @State private var hits: [ModrinthHit] = []
    /// 收藏/存档这种走本地的分类
    @State private var localItems: [AssetItem] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var totalHits = 0
    // 点卡片进入项目详情（对应 ZL2 的 AssetInfoScreen）
    @State private var detailHit: ModrinthHit?
    // 轻提示（复制链接等）
    @State private var toast: String?

    /// Modrinth 没有"操作系统"这个维度，iOS 也不需要选。
    /// 真正有用的区分是"客户端 mod / 服务端 mod"。
    private let platforms = ["不限", "仅客户端可用"]
    /// 版本列表缓存。原来是 computed，每次 body 求值都会调 listVersions()，
    /// 而那个函数要对每个版本目录递归算大小 —— 搜索框每敲一个字就在主线程扫一遍。
    @State private var cachedVersions: [String] = ["未选择"]

    private var mcVersions: [String] { cachedVersions }

    /// 只在 .task 里算一次
    private func reloadVersionList() {
        var list = ["未选择"]
        list.append(contentsOf: VersionRepository.shared.listVersions().map { $0.id })
        for v in ["1.21.5", "1.21.4", "1.21.1", "1.20.6", "1.20.1",
                  "1.19.2", "1.18.2", "1.16.5", "1.12.2"] where !list.contains(v) {
            list.append(v)
        }
        cachedVersions = list
    }

    /// 安全取加载器，防越界
    private func safeLoader(_ idx: Int) -> String? {
        guard idx > 0, idx < loaders.count else { return nil }
        return loaders[idx].lowercased()
    }

    /// 从版本 ID 推断加载器（Fabric / Forge / NeoForge / Quilt）
    /// 用缓存，不再每次 body 都扫一遍版本目录
    private var defaultLoader: String? {
        if cachedVersions.count > 1 {
            let id = cachedVersions[1].lowercased()
            if id.contains("fabric") { return "fabric" }
            if id.contains("neoforge") { return "neoforge" }
            if id.contains("quilt") { return "quilt" }
            if id.contains("forge") { return "forge" }
            return "vanilla"
        }
        return nil
    }

    /// 取收藏/存档的本地条目
    /// 本地条目的一行（收藏/存档用）
    private func localRow(_ item: AssetItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZLTheme.primarySoft)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: kind.icon).foregroundStyle(ZLTheme.primary))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                Text(item.subtitle).font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond).lineLimit(1)
            }
            Spacer()
            if kind == .favorite {
                Button {
                    ZLHaptic.light()
                    var ids = Set((UserDefaults.standard.string(forKey: "zl.assets.favorites") ?? "")
                        .split(separator: "\n").map(String.init))
                    ids.remove(item.title)
                    UserDefaults.standard.set(ids.sorted().joined(separator: "\n"),
                                              forKey: "zl.assets.favorites")
                    localItems = localItemsForCurrentKind()
                } label: {
                    Image(systemName: "heart.fill").accessibilityLabel("收藏")
                        .font(.system(size: 15)).foregroundStyle(ZLTheme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func localItemsForCurrentKind() -> [AssetItem] {
        switch kind {
        case .favorite:
            let raw = UserDefaults.standard.string(forKey: "zl.assets.favorites") ?? ""
            let ids = raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            return ids.map { id in
                AssetItem(title: id, subtitle: "已收藏", author: "—",
                          downloads: "—", tags: ["收藏"], version: "—")
            }
        case .saves:
            let dir = VersionRepository.shared.mcRoot.appendingPathComponent("saves", isDirectory: true)
            let fm = FileManager.default
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
            return names.filter { !$0.hasPrefix(".") }.compactMap { name in
                var isDir: ObjCBool = false
                let p = dir.appendingPathComponent(name)
                guard fm.fileExists(atPath: p.path, isDirectory: &isDir), isDir.boolValue else { return nil }
                return AssetItem(title: name, subtitle: "世界存档", author: "本地",
                                 downloads: "—", tags: ["存档"], version: "—")
            }.sorted { $0.title < $1.title }
        default:
            return []
        }
    }

    /// 安全取版本，防越界
    private func safeVersion(_ idx: Int) -> String? {
        guard idx > 0, idx < mcVersions.count else { return nil }
        return mcVersions[idx]
    }

    /// 默认版本 = 用户当前在用的版本（解析不到就退回 1.20.1）
    private var defaultGameVersion: String {
        // cachedVersions[0] 是「未选择」，跳过
        if cachedVersions.count > 1 { return cachedVersions[1] }
        return "1.20.1"
    }
    private let loaders = ["未选择", "Fabric", "Forge", "NeoForge", "Quilt"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "下载 - \(kind.rawValue)",
                     active: .download,
                     onBack: onBack, onHome: onHome, onSettings: onSettings)

            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                kindRail
                resultList
                    .frame(maxWidth: .infinity)
                filterPanel
                    // 原来是写死的 210。加上左侧 92pt 的 kindRail，
                    // 在手机竖屏上结果列表会被挤到只剩几十点宽。
                    // 改成 maxWidth：iPad 上按这个上限，手机上按比例收缩。
                    //
                    // 第106轮把上限从 210 收到 180：375pt 屏算一下账 ——
                    // 375 − 18×2（内边距）= 339，减去左栏 92 与间距 12、右内边距 18，
                    // 210 时只剩 7pt 给结果列表（等于没有），180 时约 37pt，仍然紧但能看。
                    // 彻底舒服要改成两列或把筛选收进 sheet —— 没有视觉反馈，不做盲改，
                    // 已在 STATUS 第 5 条记为已知问题。
                    .frame(maxWidth: 180)
                    .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: "\(kind.rawValue)|\(query)|\(sort)|\(gameVersion)|\(modLoader)|\(category)") {
            // 收藏与存档走本地，不打网络
            if kind == .favorite || kind == .saves {
                localItems = localItemsForCurrentKind()
                return
            }
            await runSearch()
        }
        // 独立 task，只在进页面时算一次版本列表（不能挂在带 id 的 task 里，
        // 否则搜索框每敲一个字都会重扫一遍所有版本目录）
        .task { reloadVersionList() }
        .sheet(item: $detailHit) { h in
            AssetInfoScreen(hit: h,
                            kind: kind,
                            onBack: { detailHit = nil },
                            onHome: { detailHit = nil })
        }
        .overlay(alignment: .top) { toastView }
        // ⌘R（iPad 键盘）重新搜索
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            guard kind != .favorite && kind != .saves else { return }
            Task { await runSearch() }
        }
    }

    // 左侧类型栏
    private var kindRail: some View {
        VStack(spacing: 6) {
            ForEach(AssetKind.allCases) { k in
                NavigationLink(value: AppRoute.assets(k.rawValue)) {
                    VStack(spacing: 4) {
                        Image(systemName: k.icon).font(.system(size: 19))
                        Text(k.rawValue).font(.system(size: 11))
                    }
                    .foregroundStyle(k == kind ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .frame(width: 76, height: 62)
                    .background(k == kind ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .frame(width: 92)
    }

    // 右侧：筛选面板（真机：竖排卡片）
    private var filterPanel: some View {
        VStack(spacing: 8) {
            // 搜索
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                TextField("搜索名称", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onSubmit { Task { await runSearch() } }
            }
            .padding(.horizontal, 10).frame(height: 34)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            filterCard("排序方式", current: kind.sorts[min(sort, kind.sorts.count-1)]) {
                ForEach(kind.sorts.indices, id: \.self) { i in
                    Button(kind.sorts[i]) { sort = i }
                }
            }
            if !kind.categories.isEmpty {
                filterCard("类别",
                           current: category == 0 ? "未选择" : kind.categories[min(category-1, kind.categories.count-1)]) {
                    Button("未选择") { category = 0 }
                    ForEach(kind.categories.indices, id: \.self) { i in
                        Button(kind.categories[i]) { category = i + 1 }
                    }
                }
            }
            filterCard("模组加载器", current: loaders[min(modLoader, loaders.count-1)]) {
                ForEach(loaders.indices, id: \.self) { i in
                    Button(loaders[i]) { modLoader = i }
                }
            }
            Spacer()
        }
    }

    private func filterCard<C: View>(_ title: String, current: String,
                                     @ViewBuilder options: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
            Menu {
                options()
            } label: {
                HStack {
                    Text(current)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 9))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .padding(.horizontal, 10).frame(height: 34)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // 顶部：来源 + 四个筛选维度 + 排序 + 搜索
    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 6)
                filterMenu(title: "用途", options: platforms, selection: $platform)
                filterMenu(title: "版本", options: mcVersions, selection: $gameVersion)
                filterMenu(title: "加载器", options: loaders, selection: $modLoader)
                filterMenu(title: "排序", options: kind.sorts, selection: $sort)
            }
            HStack(spacing: 8) {
                if !kind.categories.isEmpty {
                    filterMenu(title: "类别", options: ["未选择"] + kind.categories, selection: $category)
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
                    TextField("搜索\(kind.rawValue)", text: $query)
                        .textFieldStyle(.plain).font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .frame(maxWidth: 260)
                Spacer()
            }
        }
        .padding(.trailing, 2)
    }

    private func filterMenu(title: String, options: [String], selection: Binding<Int>) -> some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i]) { selection.wrappedValue = i }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selection.wrappedValue > 0 ? options[min(max(selection.wrappedValue, 0), options.count - 1)] : title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(selection.wrappedValue > 0 ? ZLTheme.primaryDeep : ZLTheme.textSecond)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(selection.wrappedValue > 0 ? ZLTheme.primarySoft : ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    /// 真实搜索（Modrinth）；本地收藏走 SampleData
    private func runSearch() async {
        guard let type = ModrinthProjectType.from(kind) else { hits = []; return }
        loading = true
        loadError = nil
        do {
            let gv = safeVersion(gameVersion)
            let ld = safeLoader(modLoader)
            let cats = category > 0 && category - 1 < kind.categories.count ? [kind.categories[category - 1]] : []
            let r = try await ModrinthAPI.shared.search(
                query: query,
                type: type,
                gameVersion: gv,
                loader: ld,
                categories: cats,
                clientSideOnly: platform == 1,
                sortIndex: sortIndex,
                limit: 20)
            hits = r.hits
            totalHits = r.totalHits
        } catch {
            loadError = ZLFriendlyError.text(error)
            hits = []
        }
        loading = false
    }

    private var sortIndex: String {
        switch sort {
        case 1: return "downloads"
        case 2: return "follows"
        case 3: return "newest"
        case 4: return "updated"
        default: return "relevance"
        }
    }

    private var resultList: some View {
        ScrollView {
            VStack(spacing: 10) {
                if loading {
                    // 骨架屏：比转圈更稳，列表不会跳动
                    VStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            ZLSkeletonRow(height: 76, corner: 14)
                        }
                    }
                    .padding(.top, 2)
                } else if let e = loadError {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ZLTheme.warning)
                        Text(e).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                        Button("重试") { Task { await runSearch() } }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.primaryDeep)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else if kind == .favorite || kind == .saves {
                    // 本地分类：渲染收藏/存档，不再看 hits
                    if localItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: kind == .favorite ? "heart" : "folder")
                                .font(.system(size: 30)).foregroundStyle(ZLTheme.textSecond)
                            Text(kind == .favorite ? "还没有收藏任何东西"
                                                   : "还没有存档，进游戏存一个吧")
                                .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        ForEach(localItems) { item in
                            localRow(item)
                        }
                    }
                } else if hits.isEmpty {
                    VStack(spacing: 10) {
                        // 真机的"空"视觉：一条波浪线
                        Path { path in
                            let w: CGFloat = 120
                            let h: CGFloat = 16
                            path.move(to: CGPoint(x: 0, y: h / 2))
                            var x: CGFloat = 0
                            while x < w {
                                path.addQuadCurve(to: CGPoint(x: x + 15, y: h / 2),
                                                  control: CGPoint(x: x + 7.5, y: 0))
                                path.addQuadCurve(to: CGPoint(x: x + 30, y: h / 2),
                                                  control: CGPoint(x: x + 22.5, y: h))
                                x += 30
                            }
                        }
                        .stroke(ZLTheme.textSecond.opacity(0.35), lineWidth: 2)
                        .frame(width: 120, height: 16)

                        Text("没有找到相关\(kind.rawValue)")
                            .font(.system(size: 13))
                            .foregroundStyle(ZLTheme.textSecond)
                        if gameVersion == 0 {
                            Text("试试换个游戏版本或类别").font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    HStack(spacing: 6) {
                        Text("1/\(totalHits)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ZLTheme.textSecond)
                        Spacer()
                        Text("\(hits.count) 条/页")
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
                    }
                    ForEach(Array(hits.enumerated()), id: \.element.id) { idx, h in
                        hitRow(h).popIn(delay: Double(min(idx, 10)) * 0.035)
                    }
                }
            }
            .padding(.trailing, 2)
        }
        // iOS 原生下拉刷新：重新搜一次
        .refreshable { await runSearch() }
    }

    private func hitRow(_ h: ModrinthHit) -> some View {
        HStack(spacing: 14) {
            Group {
                if let url = h.iconURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: ZLTheme.primarySoft
                        }
                    }
                } else {
                    ZLTheme.primarySoft
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(h.title).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                Text(h.description).font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond).lineLimit(2)
                HStack(spacing: 6) {
                    ForEach(h.categories.prefix(2), id: \.self) { c in
                        Text(c).font(.system(size: 10))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(ZLTheme.primarySoft).clipShape(Capsule())
                    }
                    Text("\(h.downloads) 次下载").font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            }
            Spacer(minLength: 6)
            Button {
                Task { await installProject(h) }
            } label: {
                Image(systemName: "arrow.down.circle.fill").accessibilityLabel("下载并安装整合包")
                    .font(.system(size: 24)).foregroundStyle(ZLTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { detailHit = h }
        // iOS 长按菜单
        .contextMenu {
            Button { detailHit = h } label: {
                Label("查看详情", systemImage: "info.circle")
            }
            Button { Task { await installProject(h) } } label: {
                Label("下载安装", systemImage: "arrow.down.circle")
            }
            Button { copyProjectLink(h) } label: {
                Label("复制链接", systemImage: "link")
            }
            if let url = projectURL(h) {
                ShareLink(item: url) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - 项目链接与轻提示

    private func projectURL(_ h: ModrinthHit) -> URL? {
        URL(string: "https://modrinth.com/project/\(h.id)")
    }

    private func copyProjectLink(_ h: ModrinthHit) {
        guard let url = projectURL(h) else { return }
        ZLInteraction.haptic(.light)
        ZLInteraction.copy(url.absoluteString)
        showToast("已复制项目链接")
    }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard toast == text else { return }
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        }
    }

    /// 下载并放入对应目录
    private func installProject(_ h: ModrinthHit) async {
        do {
            let vs = try await ModrinthAPI.shared.versions(
                projectID: h.id,
                gameVersion: safeVersion(gameVersion) ?? defaultGameVersion,
                loader: safeLoader(modLoader) ?? defaultLoader)
            guard let v = vs.first, let f = v.files.first(where: \.primary) ?? v.files.first else {
                loadError = "该项目没有可用文件"; return
            }
            let root = VersionRepository.shared.mcRoot
            let dir: URL
            switch kind {
            case .mod:      dir = root.appendingPathComponent("mods")
            case .resource: dir = root.appendingPathComponent("resourcepacks")
            case .shader:   dir = root.appendingPathComponent("shaderpacks")
            case .modpack:  dir = root.appendingPathComponent("modpacks")
            default:        dir = root.appendingPathComponent("downloads")
            }
            _ = try await ModrinthAPI.shared.download(f, to: dir)
        } catch {
            loadError = ZLFriendlyError.text(error)
        }
    }
}
