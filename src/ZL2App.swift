// ZL2-iOS · 应用入口 + 导航（依据真机：顶部导航栏切换页面）
import SwiftUI

@main
struct ZL2StyleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
    }
}

enum AppRoute: Hashable {
    case multiplayer
    case download
    case settings
    case account
    case controlEditor
    case about
    case assets(String)          // 资源类型名
    case versionContent(String)  // 版本内容类型名
    case search
    case exportPack
    case crashLog
    case room
    case gameDirs
    case cleanFiles
    case exportPackNew
    case controlLayout
    case skinCape
    case fileManager
    case versionList
    case javaManage
    case searchID
    case controlManage
    case serverList
    case selectGameVersion
    case downloadAddons(String)
    case logView
    case license
    case terracotta
    case modsManager(String)
    case savesManager(String)
    case resourceManager(String, Int)   // versionID, kind raw index
}

struct RootView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var path: [AppRoute] = []
    // 启动时静默检查更新
    @State private var updateInfo: ZLUpdateInfo?
    @State private var showUpdateTip = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                onMultiplayer: { path.append(.multiplayer) },
                onDownload: { path.append(.download) },
                onSettings: { path.append(.settings) },
                onFileManager: { path.append(.fileManager) },
                onVersionSettings: { path.append(.versionList) }
            )
            .zlGuide(.home)
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                if showUpdateTip, let info = updateInfo {
                    Button {
                        ZLHaptic.light()
                        if let u = URL(string: info.releaseURL) { UIApplication.shared.open(u) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 14))
                            Text("有新版本 v\(info.version)")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("查看").font(.system(size: 11))
                            Button {
                                ZLHaptic.light()
                                withAnimation(ZLSpring.page) { showUpdateTip = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(ZLTheme.primaryDeep)
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                        )
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(ZLQPressStyle(scale: 0.96))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                // 启动后静默检查一次（不打扰，有新版才提示）
                let checker = ZLUpdateChecker()
                await checker.check()
                if case .available(let info) = checker.state {
                    updateInfo = info
                    withAnimation(ZLSpring.bouncy.delay(0.4)) { showUpdateTip = true }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .multiplayer:
                    MultiplayerScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .download:
                    DownloadScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() },
                                   onSettings: { path.append(.settings) },
                                   onOpenAssets: { kind in path.append(.assets(kind.rawValue)) },
                                   onOpenSearch: { path.append(.search) })
                case .settings:
                    SettingsScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() },
                                   onDownload: { path.append(.download) })
                case .account:
                    AccountScreen().navigationTitle("账户")
                case .controlEditor:
                    ControlsScreen().navigationTitle("控制布局")
                case .about:
                    AboutScreen().navigationTitle("关于")
                case .assets(let kindName):
                    AssetsScreen(kind: AssetKind(rawValue: kindName) ?? .modpack,
                                 onBack: { path.removeLast() },
                                 onHome: { path.removeAll() },
                                 onSettings: { path.append(.settings) })
                case .versionContent(let kindName):
                    VersionContentScreen(
                        initial: VersionContentKind(rawValue: kindName) ?? .overview,
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() })
                case .search:
                    SearchScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .exportPack:
                    ExportScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .crashLog:
                    CrashLogScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .room:
                    MultiplayerRoomScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .gameDirs:
                    GameDirsScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .cleanFiles:
                    CleanFilesScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .exportPackNew:
                    ExportPackScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .controlLayout:
                    ControlEditorScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                        .zlGuide(.controlEditor)
                case .skinCape:
                    SkinCapeScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .fileManager:
                    FileManagerScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .resourceManager(let vid, let kindIdx):
                    ResourceManagerScreen(
                        kind: [ZLResourceKind.resourcePack, .shaderPack, .screenshot][min(max(kindIdx,0),2)],
                        versionID: vid,
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() })
                case .savesManager(let vid):
                    SavesManagerScreen(versionID: vid,
                                       onBack: { path.removeLast() },
                                       onHome: { path.removeAll() })
                case .selectGameVersion:
                    SelectGameVersionScreen(
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() },
                        onPick: { v in path.append(.downloadAddons(v.versionID)) })
                case .downloadAddons(let gv):
                    DownloadAddonsScreen(
                        gameVersion: gv,
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() },
                        onStart: { sel in
                            path.removeAll()
                            Task {
                                let taskID = await ZLTaskCenter.shared.add("安装 \(sel.customName)")
                                let installer = VersionInstaller()
                                do {
                                    try await installer.install(versionID: gv) { p in
                                        let total = max(p.total, 1)
                                        let frac = Double(p.completed) / Double(total)
                                        Task { @MainActor in
                                            ZLTaskCenter.shared.update(taskID,
                                                progress: frac,
                                                detail: "\(p.phase.rawValue) \(p.completed)/\(p.total)")
                                        }
                                    }
                                    // 加载器安装（Fabric / Quilt）
                                    if sel.loader == .fabric || sel.loader == .quilt {
                                        let installTask = await ZLTaskCenter.shared.add("\(sel.loader.rawValue) 加载器")
                                        do {
                                            let result: ZLLoaderInstallResult
                                            if sel.loader == .fabric {
                                                result = try await ZLLoaderInstaller.installFabric(
                                                    gameVersion: gv,
                                                    loaderVersion: sel.loaderVersion.isEmpty ? "0.15.11" : sel.loaderVersion
                                                ) { msg, p in
                                                    Task { @MainActor in
                                                        ZLTaskCenter.shared.update(installTask, progress: p, detail: msg)
                                                    }
                                                }
                                            } else {
                                                result = try await ZLLoaderInstaller.installQuilt(
                                                    gameVersion: gv,
                                                    loaderVersion: sel.loaderVersion.isEmpty ? "0.26.0" : sel.loaderVersion
                                                ) { msg, p in
                                                    Task { @MainActor in
                                                        ZLTaskCenter.shared.update(installTask, progress: p, detail: msg)
                                                    }
                                                }
                                            }
                                            await ZLTaskCenter.shared.update(installTask,
                                                detail: "已安装 \(result.versionID)（\(result.libraryCount) 个库）",
                                                state: .done)
                                        } catch {
                                            await ZLTaskCenter.shared.update(installTask,
                                                detail: error.localizedDescription, state: .failed)
                                        }
                                    }
                                    await ZLTaskCenter.shared.update(taskID,
                                        detail: "安装完成", state: .done)
                                } catch {
                                    await ZLTaskCenter.shared.update(taskID,
                                        detail: error.localizedDescription, state: .failed)
                                }
                            }
                        })
                case .logView:
                    LogViewScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .license:
                    LicenseScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .terracotta:
                    TerracottaScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .modsManager(let vid):
                    ModsManagerScreen(versionID: vid,
                                      onBack: { path.removeLast() },
                                      onHome: { path.removeAll() })
                case .serverList:
                    ServerListScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .controlManage:
                    ControlManageScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .searchID:
                    SearchIDScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .javaManage:
                    JavaManageScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .versionList:
                    VersionListScreen(
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() },
                        onMultiplayer: { path.append(.multiplayer) },
                        onDownload: { path.append(.download) },
                        onSettings: { path.append(.settings) },
                        onOpenVersion: { _ in path.append(.versionContent("概览")) })
                }
            }
        }
        .tint(ZLTheme.primary)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.darkMode ? .dark : .light)
        // 键盘快捷键挂在导航栈上：所有页面都能用（iPad / 外接键盘）
        .overlay(alignment: .topLeading) { keyboardShortcutHost }
    }

    // MARK: - 键盘快捷键
    //
    // iOS 的 .keyboardShortcut 只对 Button 生效，不能直接加在 View 上。
    // 所以这里藏一组零尺寸按钮，挂在 NavigationStack 外层，随页面常驻。
    private var keyboardShortcutHost: some View {
        Group {
            Button("下载") { push(.download) }
                .keyboardShortcut("n", modifiers: .command)

            Button("设置") { push(.settings) }
                .keyboardShortcut(",", modifiers: .command)

            // ⌘R：能刷新的页面自己监听，没有刷新动作的页面自动忽略
            Button("刷新") {
                NotificationCenter.default.post(name: .zlRefreshRequested, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            // Esc = 返回上一页（没有上一页时什么都不做）
            Button("返回") { goBack() }
                .keyboardShortcut(.cancelAction)

            // ⌘W = 直接回首页
            Button("首页") { path.removeAll() }
                .keyboardShortcut("w", modifiers: .command)
        }
        // 用 1×1 的透明按钮而不是 0×0：iOS 需要按钮真实参与布局才会注册快捷键
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 打开页面（已经在这一页就不重复压栈）
    private func push(_ route: AppRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    /// 返回上一页
    private func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

// MARK: - 全局快捷键广播
extension Notification.Name {
    /// ⌘R：请求当前页面刷新（能刷新的页面监听这个通知）
    static let zlRefreshRequested = Notification.Name("zl.refresh.requested")
}

// MARK: - 陶瓦联机（依据真机：左侧标签页 + 右侧卡片）
struct MultiplayerScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var tab = 0
    @State private var enabled = true
    @StateObject private var lan = LanDiscovery()
    @State private var lanTab = false

    private let tabs = ["用户须知", "房主教程", "房客教程"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "Terracotta | 陶瓦联机",
                     active: .multiplayer,
                     onBack: onBack, onHome: onHome)
            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                // 左：标签页 + 内容
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(tabs.indices, id: \.self) { i in
                            Button { tab = i } label: {
                                VStack(spacing: 8) {
                                    Text(tabs[i])
                                        .font(.system(size: 15, weight: tab == i ? .semibold : .regular))
                                        .foregroundStyle(tab == i ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                                    Rectangle()
                                        .fill(tab == i ? ZLTheme.primary : Color.clear)
                                        .frame(height: 3)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if tab == 0 {
                                section("用户须知", [
                                    "陶瓦联机是第三方开源自由软件，使用中遇到的问题请通过相关渠道反馈。",
                                    "陶瓦联机使用 P2P 技术，联机成功后房间内用户之间直连，不会经第三方服务器转发流量。",
                                    "联机体验与参与者的网络情况有较大关系。",
                                ])
                            } else if tab == 1 {
                                section("房主教程", [
                                    "1. 开启「启用多人联机」开关",
                                    "2. 启动游戏，进入存档后按 ESC → 对局域网开放",
                                    "3. 通过悬浮窗的联机菜单创建房间，把邀请码发给朋友",
                                ])
                            } else {
                                section("房客教程", [
                                    "1. 确认游戏版本与模组和房主完全一致",
                                    "2. 开启「启用多人联机」开关",
                                    "3. 输入房主给的邀请码加入房间",
                                ])
                            }
                            Text("在多人联机全过程中，您必须严格遵守您所在国家与地区的全部法律法规。")
                                .font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                                .padding(.top, 4)
                        }
                        .padding(16)
                    }
                }
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous))

                // 右：开关与入口
                VStack(spacing: ZLTheme.cardGap) {
                    ZLCard {
                        HStack {
                            Text("启用多人联机")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Toggle("", isOn: $enabled)
                                .labelsHidden()
                                .tint(ZLTheme.primary)
                        }
                    }
                    ZLCard {
                        HStack {
                            Text("分享联机核心日志")
                                .font(.system(size: 15))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    ZLCard {
                        HStack {
                            Text("关于 EasyTier")
                                .font(.system(size: 15))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    lanCard
                    Spacer()
                }
                .frame(width: 300)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // 局域网发现（同一 WiFi 下，零依赖）
    private var lanCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("局域网游戏").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { lan.running },
                        set: { on in
                            if on { lan.start() } else { lan.stop() }
                        }
                    ))
                    .labelsHidden()
                    .tint(ZLTheme.primary)
                }
                if lan.servers.isEmpty {
                    if lan.running {
                        HStack(spacing: 8) {
                            ZLPulseDot(color: ZLTheme.success)
                            Text("正在扫描同一 WiFi 下的游戏…")
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ZLEmptyState(
                            icon: "wifi",
                            title: "还没有发现局域网游戏",
                            detail: "在电脑或其他设备上开「对局域网开放」，
然后打开上面的开关"
                        )
                    }
                    if let err = lan.lastError {
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.danger)
                    }
                } else {
                    ForEach(lan.servers) { s in
                        Button {
                            ZLClipboard.copy("\(s.address):\(s.port)", label: "服务器地址")
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(ZLTheme.success).frame(width: 6, height: 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.displayMOTD.isEmpty ? "Minecraft 世界" : s.displayMOTD)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                                    Text("\(s.address):\(s.port)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(ZLTheme.textSecond)
                                }
                                Spacer()
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("房主在游戏里按 ESC → 对局域网开放，其他人就能在这里看到")
                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
            ForEach(lines, id: \.self) { l in
                Text(l)
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 控制布局编辑
struct ControlsScreen: View {
    @State private var keys: [ControlKey] = ControlKey.defaults
    @State private var editing = false

    var body: some View {
        ZStack {
            ZLTheme.background.ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    ForEach($keys) { $key in
                        keyView($key)
                            .position(x: key.x * geo.size.width, y: key.y * geo.size.height)
                            .gesture(editing ? DragGesture().onChanged { v in
                                key.x = min(max(v.location.x / geo.size.width, 0.05), 0.95)
                                key.y = min(max(v.location.y / geo.size.height, 0.05), 0.95)
                            } : nil)
                    }
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button { editing.toggle() } label: {
                        Text(editing ? "完成" : "编辑")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ZLTheme.textOnGold)
                            .padding(.horizontal, 22)
                            .frame(height: 40)
                            .background(editing ? ZLTheme.success : ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                    .padding(ZLTheme.screenPadding)
                }
                Spacer()
                Text(editing ? "拖动按键调整位置" : "点击右上角「编辑」开始调整")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.bottom, 18)
            }
        }
    }

    private func keyView(_ key: Binding<ControlKey>) -> some View {
        Text(key.wrappedValue.label)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ZLTheme.textPrimary)
            .frame(width: key.wrappedValue.w, height: key.wrappedValue.w * 0.62)
            .background(ZLTheme.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct ControlKey: Identifiable {
    let id = UUID()
    var label: String
    var x: Double
    var y: Double
    var w: CGFloat = 58

    static let defaults: [ControlKey] = [
        .init(label: "W", x: 0.15, y: 0.72),
        .init(label: "A", x: 0.07, y: 0.85),
        .init(label: "S", x: 0.15, y: 0.85),
        .init(label: "D", x: 0.23, y: 0.85),
        .init(label: "跳", x: 0.86, y: 0.82, w: 66),
        .init(label: "蹲", x: 0.73, y: 0.90, w: 62),
        .init(label: "背包", x: 0.88, y: 0.58, w: 66),
    ]
}

// MARK: - 关于（真机：致谢列表 + 已加载插件）
struct AboutScreen: View {
    private let credits: [(String, String)] = [
        ("bangbang93", "BMCLAPI 镜像源"),
        ("Fold Craft Launcher", "2.7.2 更新了 HMCL API 服务器的支持"),
        ("Hello Minecraft! Launcher", "2.9.7.2 更新了 HMCL API 服务器，添加新的稳定平台"),
        ("MC 百科 (mcmod.cn)", "同步了部分图标，移除旧误用图"),
        ("Terracotta", "Copyright © 2023-2025 BurningTNT，遵循 AGPL-3.0"),
        ("XZ for Java", "Copyright © 2011 Tukaani，遵循 public domain"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 版本与更新（含反馈入口）
                ZLUpdateCard()

                ZLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("关于").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        row("应用", "CraftLauncher（非官方 iOS 移植版）")
                        row("界面", "SwiftUI 复刻 Zalith Launcher 2")
                        row("启动核心", CoreBridge.isCoreLinked ? "Amethyst 已链接" : "未接入")
                    }
                }

                ZLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("致谢").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        ForEach(credits, id: \.0) { name, desc in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(desc).font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                ZLCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已加载的插件").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        HStack(spacing: 10) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .foregroundStyle(ZLTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MobileGlues").font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text("com.pi.phux.mobileglues · 1.3.4")
                                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }
                }

                ZLCard {
                    NavigationLink(value: AppRoute.license) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(ZLTheme.primary)
                                .frame(width: 38, height: 38)
                                .background(ZLTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("开源许可与致谢")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text("第三方组件、许可证全文与隐私说明")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Text("本项目遵循 GPL-3.0\nZalith Launcher 2 由 MovTery 开发")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
        }
    }

}
