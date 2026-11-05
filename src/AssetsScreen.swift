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

    /// 每个类型的来源平台（真机里就是 Modrinth / CurseForge 等）
    var sources: [String] {
        switch self {
        case .modpack, .mod, .resource, .shader: return ["Modrinth", "CurseForge"]
        default: return ["本地"]
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
    @State private var source = 0
    @State private var installedOnly = false
    // ZL2 的四个筛选维度：目标平台 / 游戏版本 / 类别 / 模组加载器
    @State private var platform = 0
    @State private var gameVersion = 0
    @State private var category = 0
    @State private var modLoader = 0
    // 真实搜索结果
    @State private var hits: [ModrinthHit] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var totalHits = 0
    // 点卡片进入项目详情（对应 ZL2 的 AssetInfoScreen）
    @State private var detailHit: ModrinthHit?
    // 轻提示（复制链接等）
    @State private var toast: String?

    private let platforms = ["未选择", "Windows", "Linux", "macOS", "Android", "iOS"]
    private let mcVersions = ["未选择", "1.21.4", "1.20.1", "1.19.2", "1.16.5", "1.12.2"]
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
                    .frame(width: 210)
                    .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: "\(kind.rawValue)|\(query)|\(sort)|\(gameVersion)|\(modLoader)|\(category)") {
            // 收藏与存档走本地，不打网络
            if kind == .favorite || kind == .saves { return }
            await runSearch()
        }
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

            filterCard("目标平台", current: kind.sources[min(source, kind.sources.count-1)]) {
                ForEach(kind.sources.indices, id: \.self) { i in
                    Button(kind.sources[i]) { source = i }
                }
            }
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
                ForEach(kind.sources.indices, id: \.self) { i in
                    ZLChip(title: kind.sources[i], selected: source == i) { source = i }
                }
                Spacer(minLength: 6)
                filterMenu(title: "平台", options: platforms, selection: $platform)
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
                Text(selection.wrappedValue > 0 ? options[selection.wrappedValue] : title)
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
            let gv = gameVersion > 0 ? mcVersions[gameVersion] : nil
            let ld = modLoader > 0 ? loaders[modLoader] : nil
            let cats = category > 0 && category - 1 < kind.categories.count ? [kind.categories[category - 1]] : []
            let r = try await ModrinthAPI.shared.search(
                query: query,
                type: type,
                gameVersion: gv,
                loader: ld,
                categories: cats,
                sortIndex: sortIndex,
                limit: 20)
            hits = r.hits
            totalHits = r.totalHits
        } catch {
            loadError = error.localizedDescription
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
                Image(systemName: "arrow.down.circle.fill")
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
                gameVersion: gameVersion > 0 ? mcVersions[gameVersion] : "1.20.1",
                loader: modLoader > 0 ? loaders[modLoader] : nil)
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
            loadError = error.localizedDescription
        }
    }
}

// MARK: - 演示数据（真实实现接 Modrinth/CurseForge API）
enum SampleData {
    static func items(for kind: AssetKind) -> [AssetItem] {
        switch kind {
        case .modpack:
            return [
                .init(title: "Better MC [FORGE]", subtitle: "A proper Vanilla+ Modpack", author: "SHXRKIE", downloads: "12.6万", tags: ["Forge", "1.20.1"], version: "1.20.1"),
                .init(title: "Vanilla Perfected", subtitle: "Vanilla+ 优化整合", author: "demonjoeTV", downloads: "152万", tags: ["Fabric", "1.21"], version: "1.21.4"),
                .init(title: "OptiFabric Creator", subtitle: "OptiFine 替代方案", author: "Creator", downloads: "124万", tags: ["Fabric", "1.16-1.21"], version: "1.21.11"),
            ]
        case .mod:
            return [
                .init(title: "Waystones", subtitle: "传送石碑，远距离快速移动", author: "BlayTheNinth", downloads: "4.2亿", tags: ["Forge", "Fabric"], version: "14.0.2"),
                .init(title: "JEI", subtitle: "物品与配方查询", author: "mezz", downloads: "8.9亿", tags: ["Forge"], version: "15.20.0"),
                .init(title: "JourneyMap", subtitle: "实时小地图与路径点", author: "techbrew", downloads: "3.1亿", tags: ["Forge", "Fabric"], version: "5.10.3"),
                .init(title: "AppleSkin", subtitle: "显示食物饱食度", author: "squeek502", downloads: "2.7亿", tags: ["Forge"], version: "2.5.1"),
            ]
        case .resource:
            return [
                .init(title: "Programmer Art", subtitle: "经典原版材质", author: "Mojang", downloads: "内置", tags: ["原版"], version: "1.20"),
                .init(title: "VM 汉化资源包", subtitle: "VM汉化组官方汉化", author: "VM汉化组", downloads: "8.3万", tags: ["汉化"], version: "1.20.1"),
                .init(title: "Mod Resources", subtitle: "1 个 Mod 文件资源", author: "自动生成", downloads: "—", tags: ["内置"], version: "1.0"),
            ]
        case .shader:
            return [
                .init(title: "BSL Shaders", subtitle: "最受欢迎的光影之一", author: "capttatsu", downloads: "1.2亿", tags: ["光影"], version: "v10.11"),
                .init(title: "Complementary", subtitle: "高性能写实光影", author: "EminGT", downloads: "9800万", tags: ["光影"], version: "r5.3"),
                .init(title: "Chocapic13", subtitle: "Bliss 修改版", author: "Chocapic13", downloads: "4200万", tags: ["光影"], version: "v2.1.2"),
            ]
        case .saves:
            return [
                .init(title: "新的世界", subtitle: "生存存档 · 1.20.1", author: "我", downloads: "—", tags: ["生存"], version: "1.20.1"),
                .init(title: "Silent Hills", subtitle: "恐怖地图 PT 补丁", author: "社区", downloads: "5.6万", tags: ["恐怖", "地图"], version: "1.17.1"),
            ]
        case .favorite:
            return [
                .init(title: "Waystones", subtitle: "已收藏 · 模组", author: "BlayTheNinth", downloads: "4.2亿", tags: ["收藏"], version: "14.0.2"),
                .init(title: "BSL Shaders", subtitle: "已收藏 · 光影", author: "capttatsu", downloads: "1.2亿", tags: ["收藏"], version: "v10.11"),
            ]
        }
    }
}
