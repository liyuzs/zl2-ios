// ZL2-iOS · 应用入口 + 导航（依据真机：顶部导航栏切换页面）
import SwiftUI
import UIKit

@main
struct ZL2StyleApp: App {
    // 处理长按图标弹出的快捷菜单（iOS 独有）
    @UIApplicationDelegateAdaptor(ZLAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            // 这里**不要**再写 .preferredColorScheme。
            // 原来写死 .light，会把整个 App 的系统外观钉在浅色：
            // 于是 RootView 读到的 colorScheme 永远是 .light，
            // 「跟随系统外观」的同步逻辑读到的也是 .light —— 深色模式永远打不开。
            RootView()
        }
    }
}

/// 只负责接系统级入口：图标快捷菜单、Siri 指令落点
final class ZLAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let d = UserDefaults.standard
        switch shortcutItem.type {
        case "com.liyuzs.craftlauncher.launch":
            d.set(true, forKey: "zl.pendingLaunch")
            d.set(Date().timeIntervalSince1970, forKey: "zl.pendingLaunchAt")
        case "com.liyuzs.craftlauncher.download":
            ZLPendingAction.setRoute("download")
        case "com.liyuzs.craftlauncher.settings":
            ZLPendingAction.setRoute("settings")
        default:
            completionHandler(false)
            return
        }
        completionHandler(true)
    }
}

enum AppRoute: Hashable {
    case multiplayer
    case download
    case settings
    case account
    case about
    case assets(String)          // 资源类型名
    case versionContent(String)  // 版本内容类型名
    case search
    case diagnostics
    case room
    case skinCape
    case fileManager
    case versionList
    case javaManage
    case searchID
    case controlManage
    case serverList
    case downloadAddons(String)
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
    /// 首次启动引导（WelcomeScreen 原本写好了但没挂载，用户永远看不到）
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "zl.welcomeShown")
    /// 启动闪屏（同理，SplashScreen 写好了但没挂）
    @State private var showSplash = true
    /// 跟随系统外观。设置页里「深色模式」那一项在 iOS 上是置灰的
    /// （`ZLUnsupportedSettings.platformOnly` 里写着"iOS 跟随系统外观"），
    /// 所以这里直接把系统外观同步给 ThemeManager，再由色板决定取 Light 还是 Dark 那一组。
    @Environment(\.colorScheme) private var colorScheme
    /// 前后台状态。快捷指令把待处理路由写进 UserDefaults 后会把 App 拉到前台，
    /// 但如果 App 本来就在运行，RootView 的 `.task` 不会重跑 —— 路由就没人消费，
    /// 于是"用 Siri 说打开下载页"看起来毫无反应。这里在回到前台时再消费一次。
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            mainStack

            if showSplash {
                SplashScreen {
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }

            if showWelcome && !showSplash {
                WelcomeScreen {
                    UserDefaults.standard.set(true, forKey: "zl.welcomeShown")
                    withAnimation(ZLSpring.page) { showWelcome = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(10)
            }
        }
        .onAppear { syncAppearance() }
        .onChange(of: scenePhase) { phase in
            // 回到前台时再看一眼有没有新的快捷指令指令
            if phase == .active { handlePendingAction() }
        }
        .onChange(of: colorScheme) { _ in syncAppearance() }
    }

    /// 消费 Siri / 快捷指令留下的待处理动作。
    /// 冷启动（`.task`）和回到前台（`scenePhase == .active`）都会调。
    private func handlePendingAction() {
        if let route = ZLPendingAction.consumeRoute() {
            switch route {
            case "download": path.append(.download)
            case "versionList": path.append(.versionList)
            case "multiplayer": path.append(.multiplayer)
            default: break
            }
        }
        if ZLPendingAction.consumeLaunchFlag() {
            // 先记成"待自动启动"，再发一条通知把首页叫醒。
            // 不再靠 0.8 秒的猜测 —— 首页读完版本列表后会自己来问（见 HomeScreen.attemptAutoLaunch）。
            ZLPendingAction.markAutoLaunchPending()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NotificationCenter.default.post(name: .zlAutoLaunch, object: nil)
            }
        }
    }

    /// 把系统亮/暗交给主题层。
    private func syncAppearance() {
        let dark = (colorScheme == .dark)
        if themeManager.darkMode != dark { themeManager.darkMode = dark }
    }

    private var mainStack: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                onAccount: { path.append(.account) },
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
                                Image(systemName: "xmark").accessibilityLabel("关闭")
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
                // 启动时清一次过期日志（按设置里的保留天数）
                ZLLogRetention.cleanup()

                // 处理 Siri / 快捷指令留下的指令
                handlePendingAction()

                // 启动后静默检查一次（不打扰，有新版才提示）
                if ZLUpdateChecker.shouldAutoCheck() {
                    // 6 小时内只自动查一次：GitHub 未认证 API 限额是每小时 60 次（按 IP），
                    // 反复开关 App 会撞限额，撞上后用户只看到一句"失败"，很懵。
                    // 手动点「检查更新」不受这个限制。
                    let checker = ZLUpdateChecker()
                    await checker.check()
                    ZLUpdateChecker.markChecked()
                    if case .available(let info) = checker.state {
                        updateInfo = info
                        withAnimation(ZLSpring.bouncy.delay(0.4)) { showUpdateTip = true }
                    }
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
                                   onOpenSearch: { path.append(.search) },
                                   onOpenSearchID: { path.append(.searchID) },
                                   onOpenAddons: { gv in path.append(.downloadAddons(gv)) })
                case .settings:
                    SettingsScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() },
                                   onDownload: { path.append(.download) })
                case .account:
                    AccountScreen().navigationTitle("账户")
                case .about:
                    AboutScreen().navigationTitle("关于")
                case .assets(let kindName):
                    AssetsScreen(kind: AssetKind(rawValue: kindName) ?? .modpack,
                                 onBack: { path.removeLast() },
                                 onHome: { path.removeAll() },
                                 onSettings: { path.append(.settings) })
                case .versionContent(let packed):
                    // 格式："版本ID|分类名"，原来只传分类名，版本 ID 丢了
                    let parts = packed.split(separator: "|", maxSplits: 1).map(String.init)
                    let vid = parts.first ?? ""
                    let kindName = parts.count > 1 ? parts[1] : "概览"
                    VersionContentScreen(
                        versionName: vid,
                        initial: VersionContentKind(rawValue: kindName) ?? .overview,
                        onBack: { path.removeLast() },
                        onHome: { path.removeAll() },
                        onOpen: { path.append($0) })
                case .search:
                    SearchScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .diagnostics:
                    DiagnosticsScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
                case .room:
                    MultiplayerRoomScreen(onBack: { path.removeLast() }, onHome: { path.removeAll() })
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
                                    try await installer.install(
                                        versionID: gv,
                                        shouldCancel: { ZLCancelFlag.shared.isCancelled(taskID) }
                                    ) { p in
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

                                            // 用户勾了 Fabric API 就得真装上（原来这个选择完全没用）
                                            if !sel.apiVersion.isEmpty {
                                                let apiTask = await ZLTaskCenter.shared.add("Fabric API \(sel.apiVersion)")
                                                do {
                                                    try await ZLFabricAPIInstaller.install(
                                                        gameVersion: gv,
                                                        apiVersion: sel.apiVersion
                                                    ) { msg, p in
                                                        Task { @MainActor in
                                                            ZLTaskCenter.shared.update(apiTask, progress: p, detail: msg)
                                                        }
                                                    }
                                                    await ZLTaskCenter.shared.update(apiTask, detail: "Fabric API 已装到 mods/", state: .done)
                                                    ZLTaskCenter.shared.finish(apiTask)
                                                } catch {
                                                    await ZLTaskCenter.shared.update(apiTask,
                                                        detail: ZLFriendlyError.text(error), state: .failed)
                                                }
                                            }
                                        } catch {
                                            await ZLTaskCenter.shared.update(installTask,
                                                detail: ZLFriendlyError.text(error), state: .failed)
                                        }
                                    }
                                    await ZLTaskCenter.shared.update(taskID,
                                        detail: "安装完成", state: .done)
                                    ZLTaskCenter.shared.finish(taskID)
                                } catch {
                                    await ZLTaskCenter.shared.update(taskID,
                                        detail: ZLFriendlyError.text(error), state: .failed)
                                }
                            }
                        })
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
                        onOpenVersion: { vid in path.append(.versionContent("\(vid)|概览")) })
                }
            }
        }
        .tint(ZLTheme.primary)
        .environmentObject(themeManager)
        // 同理：这里也不再按 darkMode 反推配色。
        // 那一句会让 colorScheme 由 darkMode 决定，而 darkMode 又由 colorScheme 同步而来 ——
        // 两者互相拉扯，系统外观切换反而传不进来。让系统值自然流入即可。
        // ZLTheme 是静态读取（不走 SwiftUI 观察），换主题时要强制重建视图树
        .id("theme-\(themeManager.themeName)-\(themeManager.darkMode)")
        // 键盘快捷键挂在导航栈上：所有页面都能用（iPad / 外接键盘）
        .overlay(alignment: .topLeading) { keyboardShortcutHost }
    }

    // MARK: - 键盘快捷键
    //
    // iOS 的 .keyboardShortcut 只对 Button 生效，不能直接加在 View 上。
    // 所以这里藏一组 1×1 的透明按钮，挂在 NavigationStack 外层，随页面常驻。
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
    /// Siri / 快捷指令 / 图标快捷菜单要求的自动启动
    static let zlAutoLaunch = Notification.Name("zl.autoLaunch")
}

// MARK: - 陶瓦联机（依据真机：左侧标签页 + 右侧卡片）
struct MultiplayerScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var tab = 0
    @StateObject private var lan = LanDiscovery()
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
                    // 这一组原来是三个**假交互**，都去掉了：
                    //   · 「启用多人联机」是个 Toggle，绑的却是本地 @State enabled ——
                    //     没持久化、没被任何代码读取，拨来拨去什么都不发生
                    //   · 「分享联机核心日志」一个 ZLCard 里放了分享图标，但根本没有 Button
                    //   · 「关于 EasyTier」带 chevron 暗示能点进去，同样没有 Button、也没有目标页
                    // 远程联机要 EasyTier 内核，iOS 版还没接入。与其放三个看起来能用的控件，
                    // 不如直接说清楚现状。
                    ZLCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("远程联机（EasyTier）")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer()
                                Text("尚未接入")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ZLTheme.textSecond)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ZLTheme.surfaceAlt)
                                    .clipShape(Capsule())
                            }
                            Text("远程联机需要 EasyTier P2P 内核，当前版本没有接入。" +
                                 "下面的「局域网游戏」是能用的，同一 WiFi 下可以直接发现。")
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    lanCard
                    Spacer()
                }
                .frame(maxWidth: 300)
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
                            detail: "在电脑或其他设备上开「对局域网开放」，然后打开上面的开关"
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



