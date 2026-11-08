// ZL2-iOS · 选择游戏版本（下载流程第一步）
// 参考：ZL2 的 SelectGameVersionScreen.kt（649 行）
import SwiftUI

// MARK: - 版本类型
struct ZLVersionEntry: Identifiable, Equatable {
    var id: String { versionID }
    var versionID: String
    var type: String          // release / snapshot / old_beta / old_alpha
    var releaseTime: String
    var url: String

    /// 是否为愚人节版本（按版本号特征判断）
    var isAprilFools: Bool {
        let known = ["15w14a", "1.rv-pre1", "3d shareware v1.34",
                     "20w14∞", "22w13oneblockatatime", "23w13a_or_b",
                     "24w14potato", "25w14craftmine"]
        if known.contains(versionID.lowercased()) { return true }
        // 带特殊后缀的也是
        let special = ["oneblock", "potato", "craftmine", "shareware"]
        return special.contains { versionID.lowercased().contains($0) }
    }

    var displayType: String {
        if isAprilFools { return "愚人节版" }
        switch type {
        case "release": return "正式版"
        case "snapshot": return "快照版"
        case "old_beta": return "远古 Beta"
        case "old_alpha": return "远古 Alpha"
        default: return type
        }
    }

    var typeIcon: String {
        if isAprilFools { return "theatermasks.fill" }
        switch type {
        case "release": return "cube.fill"
        case "snapshot": return "flask.fill"
        default: return "square.stack.fill"
        }
    }

    var isOld: Bool { type.hasPrefix("old_") }
}

// MARK: - 版本筛选
struct ZLVersionFilter {
    var release = true
    var snapshot = true
    var aprilFools = false
    var old = false
    var searchText = ""

    func matches(_ v: ZLVersionEntry) -> Bool {
        // 类型筛选
        let typeOK: Bool
        if v.isAprilFools {
            typeOK = aprilFools
        } else if v.isOld {
            typeOK = old
        } else if v.type == "snapshot" {
            typeOK = snapshot
        } else {
            typeOK = release
        }
        guard typeOK else { return false }
        // 关键词
        if !searchText.isEmpty {
            return v.versionID.localizedCaseInsensitiveContains(searchText)
        }
        return true
    }
}

// MARK: - 选择游戏版本页
struct SelectGameVersionScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onPick: (ZLVersionEntry) -> Void = { _ in }

    @State private var versions: [ZLVersionEntry] = []
    @State private var filter = ZLVersionFilter()
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "选择游戏版本", active: .download,
                     onBack: onBack, onHome: onHome)

            // 筛选芯片
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("正式版", filter.release) { filter.release.toggle() }
                    chip("快照版", filter.snapshot) { filter.snapshot.toggle() }
                    chip("愚人节版", filter.aprilFools) { filter.aprilFools.toggle() }
                    chip("远古版", filter.old) { filter.old.toggle() }
                    Spacer(minLength: 4)
                    TextField("搜索版本", text: $filter.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 10).frame(width: 130, height: 32)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, ZLTheme.screenPadding)
            }
            .padding(.bottom, 8)

            HStack {
                Text("共 \(filtered.count) 个版本")
                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                Spacer()
                if loading { ProgressView().scaleEffect(0.6) }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if let e = error {
                        VStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 30))
                                .foregroundStyle(ZLTheme.danger)
                            Text(e).font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                            Button { Task { await load() } } label: {
                                Text("重试").font(.system(size: 12))
                                    .foregroundStyle(ZLTheme.primaryDeep)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    ForEach(filtered) { v in
                        Button { onPick(v) } label: {
                            row(v)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var filtered: [ZLVersionEntry] {
        versions.filter { filter.matches($0) }
    }

    private func chip(_ title: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                .padding(.horizontal, 12).frame(height: 32)
                .background(on ? ZLTheme.primarySoft : ZLTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ v: ZLVersionEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: v.typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(v.isAprilFools ? ZLTheme.warning :
                                 v.isOld ? ZLTheme.textSecond : ZLTheme.primary)
                .frame(width: 30, height: 30)
                .background((v.isOld ? ZLTheme.textSecond : ZLTheme.primary).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(v.versionID)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(v.displayType)
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            Spacer()
            if let d = v.releaseTime.first(where: { _ in true }) {
                Text(String(d).prefix(10))
                    .font(.system(size: 9))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.7))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
        }
        .padding(10)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func load() async {
        loading = true
        error = nil
        do {
            let api = MojangAPI()
            let manifest = try await api.fetchManifest()
            versions = manifest.versions.map { e in
                ZLVersionEntry(versionID: e.id,
                               type: e.type.zlRaw,
                               releaseTime: e.releaseTime.map { Self.fmt.string(from: $0) } ?? "",
                               url: e.url.absoluteString)
            }
        } catch {
            self.error = "无法获取版本列表：\(ZLFriendlyError.text(error))"
        }
        loading = false
    }
}

// MARK: - VersionType 转字符串
extension VersionType {
    var zlRaw: String {
        switch self {
        case .release: return "release"
        case .snapshot: return "snapshot"
        case .oldBeta: return "old_beta"
        case .oldAlpha: return "old_alpha"
        case .unknown(let s): return s
        }
    }
}
