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
    case modsManager(String)
}

struct RootView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                onMultiplayer: { path.append(.multiplayer) },
                onDownload: { path.append(.download) },
                onSettings: { path.append(.settings) },
                onVersionSettings: { path.append(.versionList) }
            )
            .zlGuide(.home)
            .navigationBarHidden(true)
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
    }
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
                    Text(lan.running ? "正在监听 4445 端口…" : "开启后自动发现同一 WiFi 下的游戏")
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                } else {
                    ForEach(lan.servers) { s in
                        Button {
                            UIPasteboard.general.string = "\(s.address):\(s.port)"
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
                ZLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("关于").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        row("应用", "ZL2-iOS（非官方复刻）")
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
