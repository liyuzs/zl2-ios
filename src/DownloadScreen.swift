// ZL2-iOS · 下载中心（依据真机截图还原）
// 真机布局：顶部栏 · 左侧竖排分类 · 筛选芯片 + 搜索 · 版本卡片列表
import SwiftUI

struct DownloadScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onSettings: () -> Void = {}
    var onOpenAssets: (AssetKind) -> Void = { _ in }
    var onOpenSearch: () -> Void = {}

    @State private var category = 0
    @State private var filter = 0          // 0 正式版 1 快照 2 愚人节 3 远古
    @State private var query = ""
    @State private var liveVersions: [DLVersion] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var installing: String?
    @State private var installMsg = ""
    @State private var installFrac = 0.0
    @State private var installed: Set<String> = []

    private let categories = ["游戏", "整合包", "模组", "资源包"]
    private let catIcons = ["gamecontroller.fill", "shippingbox.fill", "puzzlepiece.fill", "paintbrush.fill"]
    private let filters = ["正式版", "快照版", "愚人节版", "远古版"]

    private let versions: [DLVersion] = [
        .init(id: "26.3",    type: "正式版", date: "2026 年 09 月 15 日 19:23:02"),
        .init(id: "26.2",    type: "正式版", date: "2026 年 06 月 16 日 20:03:33"),
        .init(id: "26.1.2",  type: "正式版", date: "2026 年 04 月 09 日 18:12:23"),
        .init(id: "1.20.1",  type: "正式版", date: "2023 年 06 月 12 日 15:20:00"),
        .init(id: "1.12.2",  type: "正式版", date: "2017 年 09 月 18 日 12:00:00"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "下载 - \(categories[category])",
                     active: .download,
                     onBack: onBack, onHome: onHome, onSettings: onSettings)

            HStack(spacing: 0) {
                sideRail
                VStack(spacing: 12) {
                    toolbar
                    list
                }
                .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadManifest() }
    }

    // MARK: 真实版本清单
    private func loadManifest(force: Bool = false) async {
        guard force || liveVersions.isEmpty else { return }
        if force { liveVersions.removeAll() }
        loading = true
        loadError = nil
        do {
            let api = MojangAPI()
            let manifest = try await api.fetchManifest()
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "yyyy 年 MM 月 dd 日 HH:mm:ss"
            liveVersions = manifest.versions.map { v in
                DLVersion(id: v.id,
                          type: v.isRelease ? "正式版" : (v.isSnapshot ? "快照版" : "远古版"),
                          date: v.publishDate.map { fmt.string(from: $0) } ?? "—")
            }
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    // MARK: 安装版本
    private func startInstall(_ id: String) async {
        guard installing == nil else { return }
        installing = id
        installFrac = 0
        installMsg = "开始安装 \(id)"
        do {
            let installer = VersionInstaller()
            try await installer.install(versionID: id) { p in
                Task { @MainActor in
                    installFrac = p.fraction
                    installMsg = p.message
                }
            }
            installed.insert(id)
            installMsg = "\(id) 安装完成"
            installFrac = 1
        } catch {
            installMsg = "安装失败：\(error.localizedDescription)"
        }
        installing = nil
    }

    // 左侧竖排分类
    private var sideRail: some View {
        VStack(spacing: 6) {
            ForEach(categories.indices, id: \.self) { i in
                // 真机：整合包 与 模组 之间有分隔线
                if i == 2 {
                    Rectangle()
                        .fill(ZLTheme.textSecond.opacity(0.15))
                        .frame(width: 40, height: 1)
                        .padding(.vertical, 2)
                }
                Button {
                    if i == 0 { category = 0 }
                    else {
                        let kinds: [AssetKind] = [.modpack, .mod, .resource]
                        onOpenAssets(kinds[min(i - 1, kinds.count - 1)])
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: catIcons[i]).font(.system(size: 19))
                        Text(categories[i]).font(.system(size: 11))
                    }
                    .foregroundStyle(category == i ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .frame(width: 72, height: 58)
                    .background(category == i ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .frame(width: 92)
    }

    // 筛选芯片 + 搜索
    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(filters.indices, id: \.self) { i in
                ZLChip(title: filters[i], selected: filter == i, checkmark: true) { filter = i }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                TextField("搜索", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onTapGesture { onOpenSearch() }
            }
            .padding(.horizontal, 12)
            .frame(width: 190, height: 40)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                ZLHaptic.light()
                Task { await loadManifest(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: 44, height: 40)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 2)
    }

    private var sourceVersions: [DLVersion] {
        liveVersions.isEmpty ? versions : liveVersions
    }

    private var filtered: [DLVersion] {
        query.isEmpty ? sourceVersions : sourceVersions.filter { $0.id.contains(query) }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                if installing != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(installMsg).font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                            Spacer()
                            Text("\(Int(installFrac * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ZLTheme.primaryDeep)
                        }
                        ProgressView(value: installFrac)
                            .tint(ZLTheme.primary)
                    }
                    .padding(12)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if loading {
                    HStack(spacing: 8) {
                        ProgressView().tint(ZLTheme.primary)
                        Text("正在获取版本清单…").font(.system(size: 13))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if let e = loadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ZLTheme.warning)
                        Text("清单获取失败：\(e)（显示内置示例）")
                            .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(filtered) { v in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: 0x6DA34D))
                            .frame(width: 42, height: 42)
                            .overlay(Image(systemName: "cube.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.85)))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(v.id)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                ZLTag(text: v.type)
                            }
                            Text(v.date)
                                .font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        Spacer()
                        Button {
                            Task { await startInstall(v.id) }
                        } label: {
                            if installing == v.id {
                                ProgressView().tint(ZLTheme.primary)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: installed.contains(v.id) ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(installed.contains(v.id) ? ZLTheme.success : ZLTheme.primary)
                                    .frame(width: 40, height: 40)
                                    .background(ZLTheme.surfaceAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(installing != nil)
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

struct DLVersion: Identifiable {
    let id: String
    let type: String
    let date: String
}
