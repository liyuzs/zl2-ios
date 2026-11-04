// ZL2-iOS · 安装新游戏（左侧可安装版本列表 + 右侧版本预览 + 底部「取消 / 安装」）
//
// 真机布局依据（ZL2 安卓源码，/tmp/zl2/ZalithLauncher）：
//  - 左右分栏：VersionsManageScreen.kt:274-348（Row 里 LeftMenu.weight(2.5f) +
//    VersionsLayout.weight(7.5f)）是本项目唯一的「列表 + 面板」双栏页。本页左栏要
//    完整放下 "1.20.1 Forge 47.4.18" 这样的版本卡，取 36 : 64（判断项，见报告）。
//  - 版本卡片：VersionsManageElements.kt:680-880 VersionItemLayout ——
//    RadioButton（719）+ 34dp 版本图标（898-901）+ 版本名（906-911）+
//    灰色副标题（913-924）+ 右侧图标按钮（731-877）。
//  - 卡片字段：
//    版本名 = "$gameVersion $loader $loaderVersion"
//        （DownloadGameWithAddonScreen.kt:652-678 AutoChangeVersionName：formatModloader
//          = "$name $version"，最后 changeValue("$gameVersion $modloaderValue")）
//    副标题 = "$gameVersion · $loader $loaderVersion"
//        （VersionInfo.kt:59-69 getInfoString 的 "mcVersion, Loader - version"，
//          真机截图上分隔符显示为 "·"）
//  - 底部「取消 / 安装」：_Download.Single.kt:377-413 —— 取消（tonal，weight .5）在左、
//    安装（filled，weight .5）在右，按钮行贴在卡片底部。
//  - 加载器版本来源与 ZL2 addons/modloader/* 一致：Fabric meta、Quilt meta、
//    Forge promotions、NeoForge maven。
import SwiftUI

// MARK: - 加载器类型
enum ZLLoaderKind: String, CaseIterable, Identifiable {
    case vanilla = "原版"
    case fabric = "Fabric"
    case quilt = "Quilt"
    case forge = "Forge"
    case neoforge = "NeoForge"

    var id: String { rawValue }

    /// Fabric API / Quilt API 只对 Fabric 系有意义（DownloadGameWithAddonScreen.kt:190-200）
    var supportsAPI: Bool { self == .fabric || self == .quilt }

    /// iOS 禁止 fork 子进程：Forge / NeoForge 的 installer.jar 跑不起来。
    /// 与 STATUS.md 的已知限制、旧版安装页的 isLoaderUnsupported 保持一致。
    var isInstallableOnIOS: Bool { self != .forge && self != .neoforge }

    /// 版本卡左侧图标（ZL2 用 drawable：img_minecraft / img_loader_*）
    var symbol: String {
        switch self {
        case .vanilla:  return "cube.fill"
        case .fabric:   return "square.stack.3d.up.fill"
        case .quilt:    return "puzzlepiece.fill"
        case .forge:    return "hammer.fill"
        case .neoforge: return "flame.fill"
        }
    }
}

// MARK: - 安装选择（ZL2App.swift:128-186 的 onStart 依赖 customName / loader / loaderVersion）
struct ZLAddonSelection {
    var loader: ZLLoaderKind = .vanilla
    var loaderVersion: String = ""
    var customName: String = ""
}

// MARK: - 一条可安装版本
struct ZLInstallCandidate: Identifiable {
    let gameVersion: String
    let loader: ZLLoaderKind
    let loaderVersion: String

    /// 版本名，例如 "1.20.1 Forge 47.4.18"（原版只有 "1.20.1"）
    var id: String { title }

    var title: String {
        loaderVersion.isEmpty ? gameVersion : "\(gameVersion) \(loader.rawValue) \(loaderVersion)"
    }

    /// 灰色副标题，例如 "1.20.1 · Forge 47.4.18"
    var subtitle: String {
        loaderVersion.isEmpty ? "\(gameVersion) · 原版" : "\(gameVersion) · \(loader.rawValue) \(loaderVersion)"
    }

    /// 加载器 + 版本，例如 "Forge 47.4.18"
    var loaderText: String {
        loaderVersion.isEmpty ? "原版（无需加载器）" : "\(loader.rawValue) \(loaderVersion)"
    }
}

// MARK: - 加载器版本服务（API 与 ZL2 相同）
enum ZLLoaderService {

    /// Fabric：https://meta.fabricmc.net/v2/versions/loader/<mc>
    static func fabricLoaders(gameVersion: String) async -> [String] {
        guard let data = try? await get("https://meta.fabricmc.net/v2/versions/loader/\(gameVersion)"),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { ($0["loader"] as? [String: Any])?["version"] as? String }
    }

    /// Quilt：https://meta.quiltmc.org/v3/versions/loader/<mc>
    static func quiltLoaders(gameVersion: String) async -> [String] {
        guard let data = try? await get("https://meta.quiltmc.org/v3/versions/loader/\(gameVersion)"),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { ($0["loader"] as? [String: Any])?["version"] as? String }
    }

    /// Forge：promotions_slim.json 只有 latest / recommended 两条
    /// （ZL2 ForgeVersions.fetchForgeList 同源）
    static func forgeVersions(gameVersion: String) async -> [String] {
        guard let data = try? await get("https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let promos = obj["promos"] as? [String: String] else { return [] }
        var out: [String] = []
        if let latest = promos["\(gameVersion)-latest"] { out.append(latest) }
        if let recommended = promos["\(gameVersion)-recommended"], !out.contains(recommended) {
            out.append(recommended)
        }
        return out
    }

    /// NeoForge：maven 版本表。1.20.1 仍用 "1.20.1-47.x" 旧格式
    /// （NeoForgeVersion.kt:48-64 parseVersion / parseVersionName），其余按 "1.xx." 前缀
    static func neoforgeVersions(gameVersion: String) async -> [String] {
        guard let data = try? await get("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let all = obj["versions"] as? [String] else { return [] }
        let majorMinor = gameVersion.split(separator: ".").prefix(2).joined(separator: ".")
        let mapped = all.compactMap { raw -> String? in
            if raw.hasPrefix(gameVersion + "-") {
                return String(raw.dropFirst(gameVersion.count + 1))
            }
            if raw.hasPrefix(majorMinor + ".") { return raw }
            return nil
        }
        return Array(mapped.reversed())
    }

    private static func get(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - 安装新游戏页
struct DownloadAddonsScreen: View {
    let gameVersion: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onStart: (ZLAddonSelection) -> Void = { _ in }

    @State private var candidates: [ZLInstallCandidate] = []
    @State private var selectedID: String?
    @State private var loading = true
    @State private var loadersUnavailable = false
    @State private var customName = ""
    @State private var nameEdited = false

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "安装新游戏",
                     active: .download,
                     onBack: onBack,
                     onHome: onHome)

            GeometryReader { geo in
                HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                    versionList
                        .frame(width: max(240, geo.size.width * 0.36))
                    previewPanel
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadCandidates() }
    }

    // MARK: 左栏：可安装版本列表
    private var versionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("可安装版本")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("\(candidates.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(ZLTheme.primarySoft)
                    .clipShape(Capsule())
                Spacer()
                if loading { ProgressView().controlSize(.small).tint(ZLTheme.primary) }
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if loading && candidates.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView().tint(ZLTheme.primary)
                            Text("正在获取加载器版本…")
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(candidates) { candidate in
                            candidateRow(candidate)
                        }
                    }

                    if loadersUnavailable {
                        Text("加载器版本获取失败，仅显示原版")
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .padding(2)
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    private func candidateRow(_ candidate: ZLInstallCandidate) -> some View {
        let on = selectedID == candidate.id
        return Button {
            selectedID = candidate.id
            if !nameEdited { customName = candidate.title }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(on ? ZLTheme.primary : ZLTheme.textSecond.opacity(0.55))

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(on ? ZLTheme.primarySoft : ZLTheme.surfaceAlt)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: candidate.loader.symbol)
                            .font(.system(size: 16))
                            .foregroundStyle(on ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(candidate.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 2)

                // 卡片右侧下载图标：表示该项可安装
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(candidate.loader.isInstallableOnIOS
                                     ? ZLTheme.primaryDeep
                                     : ZLTheme.textSecond.opacity(0.45))
                    .frame(width: 28, height: 28)
                    .background(on ? ZLTheme.surface : ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(8)
            .background(on ? ZLTheme.primarySoft.opacity(0.7) : ZLTheme.surfaceAlt.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? ZLTheme.primary.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: 右栏：预览卡（大图 + 版本信息 + 底部按钮）
    private var previewPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    previewHero
                    infoSection
                    if let candidate = selectedCandidate, !candidate.loader.isInstallableOnIOS {
                        unsupportedWarning(candidate)
                    }
                }
                .padding(12)
            }

            Rectangle()
                .fill(ZLTheme.stroke.opacity(0.25))
                .frame(height: 1)

            footerButtons
                .padding(12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ZLTheme.stroke.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    /// 大图预览：真机上是版本截图；工程里没有随包截图，用放大的版本图标占位
    private var previewHero: some View {
        LinearGradient(colors: [ZLTheme.primarySoft,
                                ZLTheme.primarySoft.opacity(0.45),
                                ZLTheme.surfaceAlt],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: selectedCandidate?.loader.symbol ?? "cube.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(ZLTheme.primaryDeep.opacity(0.5))
                    .offset(y: -10)
            )
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedCandidate?.title ?? "—")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(selectedCandidate?.subtitle ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(1)
                }
                .padding(12)
            }
            .overlay(alignment: .topLeading) {
                Text("版本预览")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(ZLTheme.surface.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if let loader = selectedCandidate?.loader {
                    ZLTag(text: loader.rawValue,
                          color: loader.isInstallableOnIOS ? ZLTheme.success : ZLTheme.warning)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 版本信息：版本名称（可改）+ MC 版本 / 加载器 / 安装位置
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("版本名称")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 58, alignment: .leading)
                TextField(selectedCandidate?.title ?? gameVersion, text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            infoRow("游戏版本", gameVersion)
            infoRow("加载器", selectedCandidate?.loaderText ?? "—")
            infoRow("安装位置", "\(VersionRepository.shared.instanceName) · .minecraft")
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .lineLimit(1)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func unsupportedWarning(_ candidate: ZLInstallCandidate) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ZLTheme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(candidate.loader.rawValue) 需要运行 installer.jar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("iOS 不允许启动子进程，无法自动安装。请先用 Fabric / Quilt，或在电脑上安装后把版本目录导入。")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZLTheme.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 底部「取消 / 安装」——_Download.Single.kt:377-413 同款：左取消、右安装，各占一半
    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button { onBack() } label: {
                Text("取消")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { install() } label: {
                Text(installBlockedByLoader ? "需电脑端安装" : "安装")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textOnGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(canInstall ? ZLTheme.primary : ZLTheme.textSecond.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canInstall)
        }
    }

    // MARK: 数据
    private var selectedCandidate: ZLInstallCandidate? {
        candidates.first { $0.id == selectedID }
    }

    private var installBlockedByLoader: Bool {
        selectedCandidate?.loader.isInstallableOnIOS == false
    }

    private var canInstall: Bool {
        !loading && selectedCandidate != nil && !installBlockedByLoader
    }

    private var nameBinding: Binding<String> {
        Binding(get: { customName },
                set: { value in
                    customName = value
                    nameEdited = true
                })
    }

    private func install() {
        guard let candidate = selectedCandidate else { return }
        var selection = ZLAddonSelection()
        selection.loader = candidate.loader
        selection.loaderVersion = candidate.loaderVersion
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        selection.customName = trimmed.isEmpty ? candidate.title : trimmed
        onStart(selection)
    }

    private func loadCandidates() async {
        guard candidates.isEmpty else { return }
        loading = true

        async let fabric = ZLLoaderService.fabricLoaders(gameVersion: gameVersion)
        async let quilt = ZLLoaderService.quiltLoaders(gameVersion: gameVersion)
        async let forge = ZLLoaderService.forgeVersions(gameVersion: gameVersion)
        async let neoforge = ZLLoaderService.neoforgeVersions(gameVersion: gameVersion)
        let (fabricList, quiltList, forgeList, neoforgeList) = await (fabric, quilt, forge, neoforge)

        var rows: [ZLInstallCandidate] = [
            ZLInstallCandidate(gameVersion: gameVersion, loader: .vanilla, loaderVersion: "")
        ]
        rows += fabricList.prefix(4).map {
            ZLInstallCandidate(gameVersion: gameVersion, loader: .fabric, loaderVersion: $0)
        }
        rows += quiltList.prefix(4).map {
            ZLInstallCandidate(gameVersion: gameVersion, loader: .quilt, loaderVersion: $0)
        }
        rows += forgeList.prefix(2).map {
            ZLInstallCandidate(gameVersion: gameVersion, loader: .forge, loaderVersion: $0)
        }
        rows += neoforgeList.prefix(4).map {
            ZLInstallCandidate(gameVersion: gameVersion, loader: .neoforge, loaderVersion: $0)
        }

        candidates = rows
        loadersUnavailable = fabricList.isEmpty && quiltList.isEmpty
            && forgeList.isEmpty && neoforgeList.isEmpty

        if selectedID == nil {
            selectedID = rows.first?.id
            if !nameEdited { customName = rows.first?.title ?? gameVersion }
        }
        loading = false
    }
}
