// ZL2-iOS · 资源下载（整合包 / 模组 / 资源包 / 光影 / 存档 / 收藏）
// 依据真机：左侧分类 + 顶部筛选 + 卡片列表；这里做一个通用页，按类型换数据源与筛选项
import SwiftUI

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

    var sorts: [String] {
        switch self {
        case .favorite, .saves: return ["最近", "名称"]
        default: return ["相关性", "下载量", "最新", "评分"]
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

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "下载 - \(kind.rawValue)",
                     active: .download,
                     onBack: onBack, onHome: onHome, onSettings: onSettings)

            HStack(spacing: 0) {
                kindRail
                VStack(spacing: 12) {
                    toolbar
                    resultList
                }
                .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // 左侧类型栏
    private var kindRail: some View {
        VStack(spacing: 6) {
            ForEach(AssetKind.allCases) { k in
                Button { } label: {
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

    // 顶部：来源 + 排序 + 搜索
    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(kind.sources.indices, id: \.self) { i in
                ZLChip(title: kind.sources[i], selected: source == i) { source = i }
            }
            Menu {
                ForEach(kind.sorts.indices, id: \.self) { i in
                    Button(kind.sorts[i]) { sort = i }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 12))
                    Text(kind.sorts[sort]).font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(ZLTheme.textSecond)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                TextField("搜索\(kind.rawValue)", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12)
            .frame(width: 200, height: 40)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.trailing, 2)
    }

    private var samples: [AssetItem] {
        SampleData.items(for: kind)
    }

    private var filtered: [AssetItem] {
        query.isEmpty ? samples : samples.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    private var resultList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(filtered) { item in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ZLTheme.primarySoft)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: kind.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(ZLTheme.primary))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                ForEach(item.tags.prefix(3), id: \.self) { t in
                                    Text(t)
                                        .font(.system(size: 10))
                                        .foregroundStyle(ZLTheme.primaryDeep)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(ZLTheme.primarySoft)
                                        .clipShape(Capsule())
                                }
                                Text("\(item.downloads) 次下载")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text(item.version)
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                            Button { } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ZLTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
            }
            .padding(.trailing, 2)
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
