// ZL2-iOS · 资源详情
// 对照 ZL2 的 AssetInfoScreen.kt（嵌套的 DownloadAssetsScreen）：
// 项目头部 + 画廊 + 介绍 + 版本筛选 + 单文件下载。
// 数据全部来自 Modrinth 真实 API；下载会写入当前游戏目录对应的 mods / resourcepacks /
// shaderpacks / modpacks，并交给任务中心显示进度。
import SwiftUI

struct AssetInfoScreen: View {
    let hit: ModrinthHit
    let kind: AssetKind
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var project: ModrinthProject?
    @State private var versions: [ModrinthVersion] = []
    @State private var loading = true
    @State private var errorText: String?

    @State private var gameFilter: String?
    @State private var loaderFilter: String?

    @State private var installingVersion: String?
    @State private var installedVersion: String?
    @State private var noteText: String?

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "资源详情", onBack: onBack, onHome: onHome)
            if loading {
                loadingView
            } else if let e = errorText {
                errorView(e)
            } else {
                content
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - 主体

    private var content: some View {
        ScrollView {
            VStack(spacing: ZLTheme.cardGap) {
                headerCard
                if let p = project, !p.gallery.isEmpty {
                    galleryCard(p)
                }
                if let p = project {
                    descriptionCard(p)
                }
                versionsCard
                if let p = project {
                    linksCard(p)
                }
            }
            .padding(ZLTheme.screenPadding)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().tint(ZLTheme.primary)
            Text("正在获取项目详情…").font(.system(size: 13))
                .foregroundStyle(ZLTheme.textSecond)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(ZLTheme.warning)
            Text(message).font(.system(size: 12))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button("重试") { Task { await load() } }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.primaryDeep)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(ZLTheme.primarySoft)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 头部

    private var headerCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    icon
                        .frame(width: 74, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project?.title ?? hit.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ZLTheme.textPrimary)
                            .lineLimit(2)
                        Text(project?.description ?? hit.description)
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                            .lineLimit(2)
                        Text(hit.author.isEmpty ? hit.slug : hit.author)
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer(minLength: 6)
                    Link(destination: projectURL) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .frame(width: 38, height: 38)
                            .background(ZLTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                HStack(spacing: 8) {
                    ZLTag(text: "\(hit.downloads.formatted()) 次下载")
                    ZLTag(text: "\(hit.follows.formatted()) 收藏", color: ZLTheme.warning)
                    if let lt = project?.licenseName {
                        ZLTag(text: lt, color: ZLTheme.textSecond)
                    }
                    Spacer()
                }

                if !(project?.categories.isEmpty ?? true) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array((project?.categories ?? []).prefix(10)), id: \.self) { c in
                                Text(c)
                                    .font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.primaryDeep)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ZLTheme.primarySoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let note = noteText {
                    HStack(spacing: 7) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.primary)
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let u = project?.iconURL ?? hit.iconURL {
            AsyncImage(url: u) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ZLTheme.primarySoft
                }
            }
        } else {
            ZLTheme.primarySoft
                .overlay(Image(systemName: kind.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(ZLTheme.primary))
        }
    }

    private var projectURL: URL {
        URL(string: "https://modrinth.com/project/\(project?.slug ?? hit.slug)")!
    }

    // MARK: - 画廊

    private func galleryCard(_ p: ModrinthProject) -> some View {
        ZLCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("预览").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(p.gallery) { g in
                            AsyncImage(url: g.url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    ZLTheme.surfaceAlt
                                        .overlay(Image(systemName: "photo")
                                            .foregroundStyle(ZLTheme.textSecond))
                                }
                            }
                            .frame(width: 220, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 介绍

    private func descriptionCard(_ p: ModrinthProject) -> some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("项目介绍").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                    if !p.updated.isEmpty {
                        Text("更新于 \(String(p.updated.prefix(10)))")
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                }
                Text(bodyText)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bodyText: AttributedString {
        let raw = project?.body ?? ""
        let clipped: String
        if raw.count > 8000 {
            clipped = String(raw.prefix(8000)) + "\n\n…（介绍过长，已截断）"
        } else {
            clipped = raw.isEmpty ? (project?.description ?? hit.description) : raw
        }
        if let s = try? AttributedString(markdown: clipped) { return s }
        return AttributedString(clipped)
    }

    // MARK: - 版本

    private var versionsCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("可用版本").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("\(filteredVersions.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ZLTheme.textSecond)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                    Spacer()
                    filterMenu(title: "游戏版本", selection: $gameFilter, options: gameOptions)
                    filterMenu(title: "加载器", selection: $loaderFilter, options: loaderOptions)
                }

                if filteredVersions.isEmpty {
                    Text("没有符合筛选条件的文件")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    ForEach(Array(filteredVersions.prefix(40)), id: \.id) { v in
                        versionRow(v)
                    }
                    if filteredVersions.count > 40 {
                        Text("仅显示前 40 个版本，可用筛选缩小范围")
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                }

                Text(targetHint)
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.top, 2)
            }
        }
    }

    private func filterMenu(title: String, selection: Binding<String?>, options: [String]) -> some View {
        Menu {
            Button("全部\(title)") { selection.wrappedValue = nil }
            Divider()
            ForEach(options, id: \.self) { o in
                Button {
                    selection.wrappedValue = o
                } label: {
                    if selection.wrappedValue == o {
                        Label(o, systemImage: "checkmark")
                    } else {
                        Text(o)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue ?? "全部\(title)")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(selection.wrappedValue == nil ? ZLTheme.textSecond : ZLTheme.primaryDeep)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(selection.wrappedValue == nil ? ZLTheme.surfaceAlt : ZLTheme.primarySoft)
            .clipShape(Capsule())
        }
    }

    private func versionRow(_ v: ModrinthVersion) -> some View {
        let file = v.files.first(where: \.primary) ?? v.files.first
        let busy = installingVersion == v.id
        let done = installedVersion == v.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(v.versionNumber.isEmpty ? v.id : v.versionNumber)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .lineLimit(1)
                if done {
                    ZLTag(text: "已下载", color: ZLTheme.success)
                }
                Spacer(minLength: 6)
                if busy {
                    ProgressView().tint(ZLTheme.primary).scaleEffect(0.8)
                } else {
                    Button {
                        Task { await install(v) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(installingVersion != nil || file == nil)
                }
            }

            HStack(spacing: 6) {
                if !v.gameVersions.isEmpty {
                    Text(v.gameVersions.prefix(3).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                if !v.loaders.isEmpty {
                    Text(v.loaders.joined(separator: " / "))
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.primaryDeep)
                }
                Spacer()
                if let f = file {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(f.size), countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            }

            if let f = file {
                Text(f.filename)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
                    .lineLimit(1)
            }

            if !v.dependencies.isEmpty {
                Text("前置项目：\(v.dependencies.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 9))
                    .foregroundStyle(ZLTheme.warning)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(ZLTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var gameOptions: [String] {
        let set = Set(versions.flatMap(\.gameVersions))
        return set.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
    }

    private var loaderOptions: [String] {
        Array(Set(versions.flatMap(\.loaders))).sorted()
    }

    private var filteredVersions: [ModrinthVersion] {
        versions.filter { v in
            (gameFilter == nil || v.gameVersions.contains(gameFilter!))
                && (loaderFilter == nil || v.loaders.contains(loaderFilter!))
        }
    }

    // MARK: - 链接

    private func linksCard(_ p: ModrinthProject) -> some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("相关链接").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                linkRow("项目主页", "globe", projectURL)
                if let u = p.sourceURL { linkRow("源代码", "chevron.left.forwardslash.chevron.right", u) }
                if let u = p.issuesURL { linkRow("问题反馈", "exclamationmark.bubble", u) }
                if let u = p.wikiURL { linkRow("Wiki", "book", u) }
                if let u = p.licenseURL, let name = p.licenseName {
                    linkRow("许可证：\(name)", "doc.text", u)
                }
            }
        }
    }

    private func linkRow(_ title: String, _ icon: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.primary)
                    .frame(width: 24, height: 24)
                Text(title).font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            .padding(.vertical, 3)
        }
    }

    // MARK: - 下载

    private var targetFolder: String {
        switch kind {
        case .mod:      return "mods"
        case .resource: return "resourcepacks"
        case .shader:   return "shaderpacks"
        case .modpack:  return "modpacks"
        default:        return "downloads"
        }
    }

    private var targetHint: String {
        switch kind {
        case .mod:      return "下载后会放入当前游戏目录的 mods/；装整合包前请先确认加载器与游戏版本。"
        case .resource: return "下载后会放入 resourcepacks/，在游戏「资源包」里启用。"
        case .shader:   return "下载后会放入 shaderpacks/，需要 Iris / Oculus 等光影前置。"
        case .modpack:  return "整合包会先下载到 modpacks/，导入解压流程在版本管理里继续。"
        default:        return "文件会保存到 downloads/。"
        }
    }

    @MainActor
    private func install(_ v: ModrinthVersion) async {
        guard installingVersion == nil else { return }
        guard let file = v.files.first(where: \.primary) ?? v.files.first else {
            noteText = "这个版本没有可下载的文件"
            return
        }
        installingVersion = v.id
        noteText = "开始下载 \(file.filename)"
        let taskID = ZLTaskCenter.shared.add("下载 \(hit.title)", detail: file.filename)
        do {
            let dest = try await ModrinthAPI.shared.download(file, to: targetDir) { p in
                Task { @MainActor in
                    ZLTaskCenter.shared.update(taskID, progress: p, detail: file.filename)
                }
            }
            ZLTaskCenter.shared.update(taskID, progress: 1,
                                        detail: "已保存到 \(targetFolder)/\(dest.lastPathComponent)",
                                        state: .done)
            installedVersion = v.id
            noteText = "已保存到 \(targetFolder)/\(dest.lastPathComponent)"
        } catch {
            ZLTaskCenter.shared.update(taskID, detail: ZLFriendlyError.text(error), state: .failed)
            noteText = "下载失败：\(ZLFriendlyError.text(error))"
        }
        installingVersion = nil
    }

    private var targetDir: URL {
        VersionRepository.shared.mcRoot.appendingPathComponent(targetFolder, isDirectory: true)
    }

    // MARK: - 加载

    @MainActor
    private func load() async {
        loading = true
        errorText = nil
        do {
            async let detail = ModrinthAPI.shared.project(idOrSlug: hit.id)
            async let list = ModrinthAPI.shared.versions(projectID: hit.id)
            project = try await detail
            versions = try await list
            // 默认选中最新的游戏版本，减少一次手动筛选
            if gameFilter == nil {
                gameFilter = gameOptions.first
            }
        } catch {
            errorText = "加载失败：\(ZLFriendlyError.text(error))"
        }
        loading = false
    }
}
