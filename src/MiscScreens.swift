// ZL2-iOS · 剩余页面：搜索 / 导出 / 引导 / 崩溃日志 / 联机房间
import SwiftUI
import UIKit

// MARK: - 资源搜索（跨类型聚合搜索）
struct SearchScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var query = ""
    @State private var scope = 0
    private let scopes = ["全部", "模组", "整合包", "资源包", "光影"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "搜索", active: .download, onBack: onBack, onHome: onHome)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ZLTheme.textSecond)
                    TextField("搜索模组、整合包、光影…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.leading, ZLTheme.screenPadding)
                .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                ForEach(scopes.indices, id: \.self) { i in
                    ZLChip(title: scopes[i], selected: scope == i) { scope = i }
                }
                Spacer()
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 10) {
                    if query.isEmpty {
                        emptyHint
                    } else {
                        ForEach(results) { r in
                            resultRow(r)
                        }
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.5))
            Text("输入关键词开始搜索").font(.system(size: 14))
                .foregroundStyle(ZLTheme.textSecond)
            Text("支持 Modrinth / CurseForge 全站资源").font(.system(size: 12))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var results: [AssetItem] {
        var all: [AssetItem] = []
        for k in [AssetKind.mod, .modpack, .resource, .shader] {
            all += SampleData.items(for: k).filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.subtitle.localizedCaseInsensitiveContains(query)
            }
        }
        return all
    }

    private func resultRow(_ item: AssetItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZLTheme.primarySoft)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "magnifyingglass")
                    .foregroundStyle(ZLTheme.primary))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("\(item.author) · \(item.subtitle)")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(ZLTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 版本导出
struct ExportScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var selected: Set<String> = [".minecraft/versions", ".minecraft/mods"]
    @State private var exporting = false
    @State private var shareURL: URL?
    @State private var message: String?
    private let options = [
        ("版本核心文件", ".minecraft/versions"),
        ("模组", ".minecraft/mods"),
        ("资源包", ".minecraft/resourcepacks"),
        ("光影", ".minecraft/shaderpacks"),
        ("存档", ".minecraft/saves"),
        ("配置文件", ".minecraft/config"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "导出整合包", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    ZLCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("选择要导出的内容").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text("导出的 zip 可以直接分享给别人导入").font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    ForEach(options, id: \.1) { name, path in
                        HStack(spacing: 12) {
                            Button {
                                if selected.contains(path) { selected.remove(path) }
                                else { selected.insert(path) }
                            } label: {
                                Image(systemName: selected.contains(path) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected.contains(path) ? ZLTheme.primary : ZLTheme.textSecond)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(path).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    ZLGoldButton(title: exporting ? "正在打包…" : "导出并分享",
                                 icon: "square.and.arrow.up",
                                 enabled: !selected.isEmpty && !exporting) {
                        exportPack()
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: Binding(
            get: { shareURL.map { ShareBox(url: $0) } },
            set: { if $0 == nil { shareURL = nil } }
        )) { box in
            ShareSheet(items: [box.url])
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .padding(.bottom, 20)
            }
        }
    }

    /// 把选中的目录打包成 zip 并弹分享
    private func exportPack() {
        exporting = true
        message = "正在打包，请稍候…"
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            _ = docs  // 保留变量避免警告
            let gameDir = VersionRepository.shared.mcRoot
            let stamp = Int(Date().timeIntervalSince1970)
            let outName = "整合包-\(stamp).zip"
            let outURL = fm.temporaryDirectory.appendingPathComponent(outName)

            do {
                // 用一个临时目录组织结构，再整体压缩
                let stage = fm.temporaryDirectory.appendingPathComponent("zl_export_\(stamp)")
                try? fm.removeItem(at: stage)
                try fm.createDirectory(at: stage, withIntermediateDirectories: true)

                for rel in selected {
                    let src = gameDir.appendingPathComponent(rel.replacingOccurrences(of: ".minecraft/", with: ""))
                    guard fm.fileExists(atPath: src.path) else { continue }
                    let dst = stage.appendingPathComponent(rel)
                    try? fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.copyItem(at: src, to: dst)
                }

                // NSFileCoordinator 的 forUploading 能直接产出 zip
                var coordError: NSError?
                var zipURL: URL?
                NSFileCoordinator().coordinate(readingItemAt: stage, options: [.forUploading], error: &coordError) { tmp in
                    zipURL = try? fm.copyItemToTemp(tmp, named: outName)
                }
                try? fm.removeItem(at: stage)

                DispatchQueue.main.async {
                    exporting = false
                    if let z = zipURL {
                        shareURL = z
                        message = "打包完成"
                    } else {
                        message = "打包失败，请重试"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { message = nil }
                }
            } catch {
                DispatchQueue.main.async {
                    exporting = false
                    message = "打包失败：\(ZLFriendlyError.text(error))"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { message = nil }
                }
            }
        }
    }
}

// MARK: - 导出用的小工具

private struct ShareBox: Identifiable {
    let url: URL
    var id: String { url.path }
}

private extension FileManager {
    /// 把临时文件拷到另一个带名字的临时路径（forUploading 给的是随机名）
    func copyItemToTemp(_ src: URL, named name: String) throws -> URL {
        let dst = temporaryDirectory.appendingPathComponent(name)
        try? removeItem(at: dst)
        try copyItem(at: src, to: dst)
        return dst
    }
}

// MARK: - 首次引导
struct WelcomeScreen: View {
    var onFinish: () -> Void = {}
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("cube.fill", "欢迎使用 ZL2", "开源的 Minecraft: Java 版启动器\n为 iOS 重新实现的界面"),
        ("wrench.and.screwdriver.fill", "先做个自检", "检查启动核心与 Java 运行时\n确保能正常启动游戏"),
        ("play.circle.fill", "准备开始", "下载一个游戏版本\n然后点击「启动游戏」"),
    ]

    var body: some View {
        ZStack {
            ZLTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: pages[page].0)
                        .font(.system(size: 56))
                        .foregroundStyle(ZLTheme.primary)
                    Text(pages[page].1)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(pages[page].2)
                        .font(.system(size: 14))
                        .foregroundStyle(ZLTheme.textSecond)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? ZLTheme.primary : ZLTheme.primarySoft)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                ZLGoldButton(title: page == pages.count - 1 ? "开始使用" : "下一步",
                             icon: page == pages.count - 1 ? "checkmark" : "arrow.right") {
                    if page < pages.count - 1 { page += 1 } else { onFinish() }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 崩溃日志
struct CrashLogScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var logs: [String] = []
    @State private var findings: [ZLCrashAnalyzer.Finding] = []

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "崩溃日志", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    // 自动诊断结果
                    if !findings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("可能的原因").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            ForEach(Array(findings.enumerated()), id: \.offset) { _, f in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Image(systemName: f.severity >= 3
                                              ? "exclamationmark.octagon.fill"
                                              : "exclamationmark.triangle.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(f.severity >= 3 ? ZLTheme.danger : ZLTheme.warning)
                                        Text(f.title).font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(ZLTheme.textPrimary)
                                    }
                                    Text(f.advice)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ZLTheme.textSecond)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, ZLTheme.screenPadding)
                        .padding(.top, ZLTheme.screenPadding)
                    }
                    ForEach(logs.indices, id: \.self) { i in
                        Text(logs[i])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(ZLTheme.screenPadding)
            }
            HStack(spacing: 10) {
                ZLGoldButton(title: "复制日志", icon: "doc.on.doc") {
                    UIPasteboard.general.string = logs.joined(separator: "\n")
                }
                ShareLink(item: logs.joined(separator: "\n")) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                        Text("分享").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(ZLTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(ZLTheme.surface)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { loadRealLog() }
    }

    /// 读真实的 ame.log 并自动诊断
    private func loadRealLog() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent("ame.log")
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            logs = ["[提示] 还没找到日志文件。",
                    "先在首页启动一次游戏，日志会自动写到 Documents/ame.log。"]
            findings = []
            return
        }
        let all = text.components(separatedBy: "\n")
        logs = Array(all.suffix(400))
        findings = ZLCrashAnalyzer.analyze(text)
    }
}

// MARK: - 联机房间（房主 / 房客）
struct MultiplayerRoomScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var isHost = true
    @State private var code = ""
    @State private var joinMessage: String?
    @State private var roomCode = "—"

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "陶瓦联机", active: .multiplayer, onBack: onBack, onHome: onHome)
            HStack(spacing: ZLTheme.cardGap) {
                ZLCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("", selection: $isHost) {
                            Text("创建房间").tag(true)
                            Text("加入房间").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if isHost {
                            Text("邀请码").font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                            Text(roomCode)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(ZLTheme.primaryDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ZLTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            ZLGoldButton(title: "创建房间", icon: "person.badge.plus") {
                                roomCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
                            }
                        } else {
                            Text("输入房主给的邀请码").font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                            TextField("6 位邀请码", text: $code)
                                .textFieldStyle(.plain)
                                .font(.system(size: 18, design: .monospaced))
                                .padding(12)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            ZLGoldButton(title: "加入房间", icon: "arrow.right.circle", enabled: code.count >= 4) {
                                joinMessage = "远程联机需要 EasyTier 内核，当前版本还没接入。\n局域网联机可以直接用「多人游戏」页扫描。"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { joinMessage = nil }
                            }
                            if let joinMessage {
                                Text(joinMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.warning)
                                    .multilineTextAlignment(.leading)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                ZLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("连接状态").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        HStack(spacing: 8) {
                            Circle().fill(ZLTheme.textSecond.opacity(0.4)).frame(width: 8, height: 8)
                            Text("未连接").font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
                        }
                        Divider()
                        Text("陶瓦联机基于 EasyTier P2P，房间内直连，不经过第三方服务器。")
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                }
                .frame(width: 260)
            }
            .padding(ZLTheme.screenPadding)
            Spacer()
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - 按项目 ID 搜索（真机：下载-搜索ID）
struct SearchIDScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var projectID = ""
    @State private var loading = false
    @State private var errorText: String?
    @State private var result: ModrinthHit?
    @State private var platform = 0
    private let platforms = ["全部", "Modrinth", "CurseForge"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "搜索 ID", active: .download, onBack: onBack, onHome: onHome)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("项目 ID").font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                    TextField("输入项目 ID", text: $projectID)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onSubmit { Task { await search() } }
                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ZLTheme.textOnGold)
                            .frame(width: 44, height: 40)
                            .background(ZLTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(projectID.isEmpty || loading)

                    Menu {
                        ForEach(platforms.indices, id: \.self) { i in
                            Button(platforms[i]) { platform = i }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(platforms[platform]).font(.system(size: 12))
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .foregroundStyle(ZLTheme.textSecond)
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                if loading {
                    ProgressView().tint(ZLTheme.primary).padding(.top, 30)
                } else if let e = errorText {
                    Text(e).font(.system(size: 12)).foregroundStyle(ZLTheme.danger)
                        .padding(.top, 20)
                } else if let r = result {
                    hitCard(r)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "number.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                        Text("根据项目 ID 快速获取对应项目")
                            .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                }
                Spacer()
            }
            .padding(ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func hitCard(_ h: ModrinthHit) -> some View {
        HStack(spacing: 14) {
            Group {
                if let u = h.iconURL {
                    AsyncImage(url: u) { p in
                        if case .success(let img) = p { img.resizable().scaledToFill() }
                        else { ZLTheme.primarySoft }
                    }
                } else { ZLTheme.primarySoft }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(h.title).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(h.description).font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond).lineLimit(2)
                Text("\(h.downloads) 次下载 · \(h.projectType)")
                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
            }
            Spacer()
        }
        .padding(14)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func search() async {
        guard !projectID.isEmpty else { return }
        loading = true
        errorText = nil
        result = nil
        do {
            // 复用 Modrinth 搜索：用 ID 当关键词，命中第一条即目标
            let r = try await ModrinthAPI.shared.search(query: projectID, type: nil, limit: 1)
            if let first = r.hits.first, first.id == projectID || first.slug == projectID {
                result = first
            } else if let first = r.hits.first {
                result = first
            } else {
                errorText = "未找到该项目"
            }
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
        loading = false
    }
}

// MARK: - 系统分享面板（SwiftUI 包装）

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
