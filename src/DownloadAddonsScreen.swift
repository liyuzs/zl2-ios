// ZL2-iOS · 下载附加组件（加载器 / API / OptiFine）
// 参考：ZL2 的 DownloadGameWithAddonScreen.kt + addons/modloader/*
// API 端点来自源码：
//   Fabric  https://meta.fabricmc.net/v2
//   Quilt   https://meta.quiltmc.org/v3
//   NeoForge https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge
import SwiftUI

// MARK: - 加载器类型
enum ZLLoaderKind: String, CaseIterable, Identifiable {
    case vanilla = "原版"
    case fabric = "Fabric"
    case quilt = "Quilt"
    case forge = "Forge"
    case neoforge = "NeoForge"

    var id: String { rawValue }

    var supportsAPI: Bool {
        self == .fabric || self == .quilt
    }
}

// MARK: - 附加组件状态
struct ZLAddonSelection {
    var loader: ZLLoaderKind = .vanilla
    var loaderVersion: String = ""
    var apiVersion: String = ""        // Fabric API / Quilt API
    var optifine: String = ""          // OptiFine 版本
    var customName: String = ""
}

// MARK: - 加载器版本服务
enum ZLLoaderService {

    /// Fabric 加载器版本
    static func fabricLoaders(gameVersion: String) async throws -> [String] {
        let url = "https://meta.fabricmc.net/v2/versions/loader/\(gameVersion)"
        let data = try await httpGet(url)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { ($0["loader"] as? [String: Any])?["version"] as? String }
    }

    /// Quilt 加载器版本
    static func quiltLoaders(gameVersion: String) async throws -> [String] {
        let url = "https://meta.quiltmc.org/v3/versions/loader/\(gameVersion)"
        let data = try await httpGet(url)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { ($0["loader"] as? [String: Any])?["version"] as? String }
    }

    /// NeoForge 版本（带 gameVersion 前缀过滤）
    static func neoforgeVersions(gameVersion: String) async throws -> [String] {
        let url = "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"
        let data = try await httpGet(url)
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = o["versions"] as? [String] else { return [] }
        // NeoForge 版本形如 21.1.0（前两位是 MC 版本），按 gameVersion 过滤
        let short = gameVersion.split(separator: ".").prefix(2).joined(separator: ".")
        return arr.filter { $0.hasPrefix(short + ".") }.reversed()
    }

    /// Forge 版本（用 promotions API）
    static func forgeVersions(gameVersion: String) async throws -> [String] {
        let url = "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
        let data = try await httpGet(url)
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let promos = o["promos"] as? [String: String] else { return [] }
        var out: [String] = []
        if let latest = promos["\(gameVersion)-latest"] { out.append(latest) }
        if let rec = promos["\(gameVersion)-recommended"], rec != out.first { out.append(rec) }
        return out
    }

    /// Fabric API 版本
    static func fabricAPI(gameVersion: String) async throws -> [String] {
        let url = "https://api.modrinth.com/v2/project/fabric-api/version?game_versions=[\"\(gameVersion)\"]&loaders=[\"fabric\"]"
        let data = try await httpGet(url)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["version_number"] as? String }
    }

    /// 统一的加载器版本获取
    static func versions(for kind: ZLLoaderKind, gameVersion: String) async -> [String] {
        do {
            switch kind {
            case .vanilla: return [""]
            case .fabric: return try await fabricLoaders(gameVersion: gameVersion)
            case .quilt: return try await quiltLoaders(gameVersion: gameVersion)
            case .forge: return try await forgeVersions(gameVersion: gameVersion)
            case .neoforge: return Array(try await neoforgeVersions(gameVersion: gameVersion))
            }
        } catch {
            return []
        }
    }

    static func httpGet(_ url: String) async throws -> Data {
        guard let u = URL(string: url) else { throw URLError(.badURL) }
        var req = URLRequest(url: u, timeoutInterval: 15)
        req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - 下载附加组件页
struct DownloadAddonsScreen: View {
    let gameVersion: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onStart: (ZLAddonSelection) -> Void = { _ in }

    @State private var selection = ZLAddonSelection()
    @State private var loaderVersions: [String] = []
    @State private var apiVersions: [String] = []
    @State private var loading = false
    @State private var showLoaderPicker = false
    @State private var showVersionPicker = false
    @State private var showAPIPicker = false

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "安装 \(gameVersion)", active: .download,
                     onBack: onBack, onHome: onHome)

            ScrollView {
                VStack(spacing: 12) {
                    // 版本名
                    ZLCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("版本名称").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ZLTheme.textPrimary)
                            TextField(autoName, text: $selection.customName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10).frame(height: 34)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("留空则自动命名").font(.system(size: 9))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }

                    // 加载器
                    ZLCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("模组加载器").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            ForEach(ZLLoaderKind.allCases) { k in
                                Button {
                                    selection.loader = k
                                    selection.loaderVersion = ""
                                    selection.apiVersion = ""
                                    Task { await reloadVersions() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selection.loader == k ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 15))
                                            .foregroundStyle(selection.loader == k ? ZLTheme.primary : ZLTheme.textSecond)
                                        Text(k.rawValue).font(.system(size: 13))
                                            .foregroundStyle(ZLTheme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 加载器版本
                    if selection.loader != .vanilla {
                        ZLCard {
                            HStack {
                                Text("加载器版本").font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer()
                                if loading {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Menu {
                                        ForEach(loaderVersions.prefix(30), id: \.self) { v in
                                            Button(v) { selection.loaderVersion = v }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(selection.loaderVersion.isEmpty ? "最新" : selection.loaderVersion)
                                                .font(.system(size: 12, design: .monospaced))
                                            Image(systemName: "chevron.down").font(.system(size: 9))
                                        }
                                        .foregroundStyle(ZLTheme.primaryDeep)
                                    }
                                }
                            }
                        }
                    }

                    // API（Fabric/Quilt）
                    if selection.loader.supportsAPI {
                        ZLCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(selection.loader.rawValue) API").font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(ZLTheme.textPrimary)
                                    Text("大部分模组需要").font(.system(size: 9))
                                        .foregroundStyle(ZLTheme.textSecond)
                                }
                                Spacer()
                                Menu {
                                    Button("不安装") { selection.apiVersion = "" }
                                    ForEach(apiVersions.prefix(20), id: \.self) { v in
                                        Button(v) { selection.apiVersion = v }
                                    }
                                } label: {
                                    Text(selection.apiVersion.isEmpty ? "不安装" : selection.apiVersion)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(ZLTheme.primaryDeep)
                                }
                            }
                        }
                    }

                    // OptiFine
                    ZLCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("OptiFine").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text("需要手动下载并放到 mods 目录（iOS 无法自动安装）")
                                .font(.system(size: 9))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }

                    // 开始
                    Button { onStart(finalSelection) } label: {
                        Text("开始下载")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.textOnGold)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await reloadVersions() }
    }

    private var autoName: String {
        if !selection.customName.isEmpty { return selection.customName }
        var parts = [gameVersion]
        if selection.loader != .vanilla { parts.append(selection.loader.rawValue) }
        if !selection.loaderVersion.isEmpty { parts.append(selection.loaderVersion) }
        return parts.joined(separator: "-")
    }

    private var finalSelection: ZLAddonSelection {
        var s = selection
        if s.customName.isEmpty { s.customName = autoName }
        if s.loaderVersion.isEmpty, let first = loaderVersions.first { s.loaderVersion = first }
        return s
    }

    private func reloadVersions() async {
        guard selection.loader != .vanilla else {
            loaderVersions = []
            apiVersions = []
            return
        }
        loading = true
        loaderVersions = await ZLLoaderService.versions(for: selection.loader, gameVersion: gameVersion)
        if selection.loader.supportsAPI {
            apiVersions = (try? await ZLLoaderService.fabricAPI(gameVersion: gameVersion)) ?? []
        } else {
            apiVersions = []
        }
        loading = false
    }
}
