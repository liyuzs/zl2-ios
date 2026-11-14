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
                        .submitLabel(.search)
                        .onSubmit { runLiveSearch() }
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
            .onChange(of: scope) { _ in
                if !query.isEmpty { runLiveSearch() }
            }

            ScrollView {
                VStack(spacing: 10) {
                    if query.isEmpty {
                        emptyHint
                    } else if let e = searchError {
                        Text(e).font(.system(size: 12)).foregroundStyle(ZLTheme.danger)
                            .padding()
                    } else if searching {
                        ProgressView().padding(30)
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
            Text("支持 Modrinth 全站资源").font(.system(size: 12))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    /// 真实搜索结果（Modrinth）
    @State private var liveHits: [ModrinthHit] = []
    @State private var searching = false
    @State private var searchError: String?

    /// 真正去 Modrinth 搜
    private func runLiveSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            liveHits = []
            searchError = nil
            return
        }
        searching = true
        searchError = nil
        Task {
            do {
                // 按当前 scope 决定搜什么类型
                let type: ModrinthProjectType? = {
                    switch scope {
                    case 1: return .mod
                    case 2: return .modpack
                    case 3: return .resourcepack
                    case 4: return .shader
                    default: return nil
                    }
                }()
                let r = try await ModrinthAPI.shared.search(query: q, type: type, limit: 30)
                await MainActor.run {
                    liveHits = r.hits
                    searching = false
                }
            } catch {
                await MainActor.run {
                    searchError = ZLFriendlyError.text(error)
                    liveHits = []
                    searching = false
                }
            }
        }
    }

    private var results: [AssetItem] {
        // 有真实结果就用真实的
        if !liveHits.isEmpty {
            return liveHits.map { h in
                AssetItem(title: h.title,
                          subtitle: h.description,
                          author: h.author,
                          downloads: "\(h.downloads)",
                          tags: h.categories,
                          version: h.versions.first ?? "—")
            }
        }
        // 搜不到就是搜不到，不再回退到硬编码假数据
        return []
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
            // 没有 project 上下文就不画假按钮
            EmptyView()
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 版本导出
// MARK: - 导出用的小工具

private extension FileManager {
}

// MARK: - 首次引导
struct WelcomeScreen: View {
    var onFinish: () -> Void = {}
    @State private var page = 0
    /// 自检结果：nil = 还没跑，true = 通过，false = 有问题
    @State private var checkResult: Bool?
    @State private var checkDetail = ""
    @State private var checking = false

    private let pages: [(String, String, String)] = [
        ("cube.fill", "欢迎使用 CraftLauncher",
         "开源的 Minecraft: Java 版启动器\n为 iOS 重新实现的界面"),
        ("wrench.and.screwdriver.fill", "先做个自检",
         "检查启动核心与 Java 运行时\n确保能正常启动游戏"),
        ("play.circle.fill", "准备开始",
         "下载一个游戏版本\n然后点击「启动游戏」"),
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
                        .symbolEffect(.bounce, value: page)
                    Text(pages[page].1)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(pages[page].2)
                        .font(.system(size: 14))
                        .foregroundStyle(ZLTheme.textSecond)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    // 第二页：真实的运行时自检
                    if page == 1 {
                        selfCheckPanel
                    }
                }
                Spacer(minLength: 20)
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
                    if page < pages.count - 1 {
                        withAnimation(ZLSpring.page) { page += 1 }
                        if page == 1 { runSelfCheck() }
                    } else {
                        onFinish()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
    }

    /// 自检面板：真的去查 JRE 和核心
    private var selfCheckPanel: some View {
        VStack(spacing: 10) {
            if checking {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("检查中…").font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            } else if let ok = checkResult {
                HStack(spacing: 8) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ok ? ZLTheme.success : ZLTheme.warning)
                    Text(checkDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(ZLTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.top, 12)
    }

    /// 跑一次真实自检
    private func runSelfCheck() {
        guard !checking else { return }
        checking = true
        checkResult = nil

        DispatchQueue.global(qos: .userInitiated).async {
            // 1) 内置 JRE 是否在
            let jre = CoreBridge.runtimeCheck()
            // 2) 核心是否链接（模拟器下恒为 false）
            var coreOK = false
            #if ZL2_CORE_LINKED
            coreOK = true
            #endif

            let allOK = jre && coreOK
            var msg = ""
            if allOK {
                msg = "运行环境正常，可以开始使用了"
            } else if !jre {
                msg = "找不到内置 Java 运行时，游戏可能无法启动"
            } else {
                msg = "当前是模拟器环境，无法真正启动游戏"
            }

            DispatchQueue.main.async {
                checking = false
                checkResult = allOK
                checkDetail = msg
                ZLHaptic.success()
            }
        }
    }
}

// MARK: - 崩溃日志
// MARK: - 联机房间（房主 / 房客）
struct MultiplayerRoomScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var isHost = true
    @State private var code = ""
    @State private var joinMessage: String?
    @State private var roomCode = "—"
    @State private var hostMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "陶瓦联机", active: .multiplayer, onBack: onBack, onHome: onHome)
            // **第189轮**：这个界面**当前没有任何入口**（`AppRoute.room` 存在、`ZL2App` 也接了
            // `case .room:`，但全项目没有任何地方 `path.append(.room)`）。
            // 而且它依赖的 EasyTier 隧道需要 **Network Extension**（本项目没做，见 EasyTierTunnel 里的 TODO）。
            //
            // 这条提示是给它"将来被接上入口"那天准备的：那时候用户会真的走进来，
            // 而如果底下的隧道不通，他会看到一个"能点但连不上"的界面 —— 比空白更糟。
            // 所以先在这里说清楚状态，而不是等用户自己发现。
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.warning)
                Text("这个功能还没做完 —— 隧道组件需要 Network Extension，当前版本里连不通。下面的按钮先别指望。")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.vertical, 10)

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
                            if let hostMessage {
                                // 注意：修饰符必须挂在 Text 上，不能挂在 if 语句上（SwiftUI 不允许）
                                Text(hostMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.warning)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 10)
                                    .background(ZLTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            ZLGoldButton(title: "创建房间", icon: "person.badge.plus") {
                                // 原来生成的是 6 位随机串，和 ZLEasyTierRoom 要求的
                                // U/XXXX-XXXX-XXXX-XXXX 格式对不上，谁拿去 join 都会失败。
                                // 内核没接入之前不要假造可用的邀请码。
                                roomCode = "未接入"
                                hostMessage = "远程联机需要 EasyTier 内核，当前版本还没接入。\n局域网联机请用「多人游戏」页扫描。"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { hostMessage = nil }
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
                .frame(maxWidth: 260)
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
                        Image(systemName: "magnifyingglass").accessibilityLabel("搜索")
                            .foregroundStyle(ZLTheme.textOnGold)
                            .frame(width: 44, height: 40)
                            .background(ZLTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(projectID.isEmpty || loading)

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
            // 原来后面那个 else-if 会把「搜到的第一条」当成结果，
            // 等于输错 ID 也会显示一个不相干项目。必须严格匹配。
            if let first = r.hits.first(where: { $0.id == projectID || $0.slug == projectID }) {
                result = first
            } else {
                result = nil
                errorText = "没找到 ID 为「\(projectID)」的项目，检查一下有没有写错"
            }
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
        loading = false
    }
}

// MARK: - 系统分享面板（SwiftUI 包装）

