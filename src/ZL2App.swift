// ZL2-iOS · 应用入口 + 侧边抽屉 + 页面导航
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
    case account
    case settings
    case controls
    case download
    case mods
    case about
}

struct RootView: View {
    @State private var path: [AppRoute] = []
    @State private var showDrawer = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(onOpenDrawer: { showDrawer = true },
                       onOpenAccount: { path.append(.account) })
                .navigationBarHidden(true)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .account:  AccountScreen().navigationTitle("账户")
                    case .settings: SettingsScreen().navigationTitle("设置")
                    case .controls: ControlsScreen().navigationTitle("控制布局")
                    case .download: DownloadScreen().navigationTitle("下载中心")
                    case .mods:     ModsScreen().navigationTitle("模组管理")
                    case .about:    AboutScreen().navigationTitle("关于")
                    }
                }
        }
        .overlay(alignment: .leading) {
            if showDrawer {
                drawer.transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.22), value: showDrawer)
    }

    // 对照 ZL2 的侧边栏入口
    private var drawer: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.25).ignoresSafeArea()
                .onTapGesture { showDrawer = false }

            VStack(alignment: .leading, spacing: 4) {
                header
                drawerItem("账户", "person.crop.circle", .account)
                drawerItem("设置", "gearshape", .settings)
                drawerItem("控制布局", "gamecontroller", .controls)
                drawerItem("下载中心", "arrow.down.circle", .download)
                drawerItem("模组管理", "shippingbox", .mods)
                drawerItem("关于", "info.circle", .about)
                Spacer()
                Text("ZL2-iOS · 非官方移植\n界面原型，未接入启动核心")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .frame(width: 280)
            .background(ZLTheme.cardBg)
            .ignoresSafeArea(edges: .trailing)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ZLTheme.primary.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "cube.fill").foregroundStyle(ZLTheme.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text("Zalith Launcher").font(.system(size: 16, weight: .bold))
                Text("iOS 移植版").font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    private func drawerItem(_ title: String, _ icon: String, _ route: AppRoute) -> some View {
        Button {
            showDrawer = false
            path.append(route)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(ZLTheme.primary)
                Text(title).font(.system(size: 15))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 控制布局（视觉层，可拖动的按键网格）
struct ControlsScreen: View {
    @State private var keys: [ControlKey] = ControlKey.defaults
    @State private var editing = false

    var body: some View {
        ZStack {
            ZLTheme.surface.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ForEach($keys) { $key in
                        keyView($key)
                            .position(x: key.x * geo.size.width,
                                      y: key.y * geo.size.height)
                            .gesture(
                                editing ? DragGesture()
                                    .onChanged { v in
                                        key.x = min(max(v.location.x / geo.size.width, 0.05), 0.95)
                                        key.y = min(max(v.location.y / geo.size.height, 0.05), 0.95)
                                    } : nil
                            )
                    }
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        editing.toggle()
                    } label: {
                        Text(editing ? "完成" : "编辑")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 36)
                            .background(editing ? ZLTheme.success : ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(ZLTheme.screenPadding)
                Spacer()
                Text(editing ? "拖动按键调整位置" : "点击右上角「编辑」开始调整")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.bottom, 16)
            }
        }
    }

    private func keyView(_ key: Binding<ControlKey>) -> some View {
        Text(key.wrappedValue.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ZLTheme.textPrimary)
            .frame(width: key.wrappedValue.w, height: key.wrappedValue.w * 0.62)
            .background(ZLTheme.cardBg.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ZLTheme.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct ControlKey: Identifiable {
    let id = UUID()
    var label: String
    var x: Double   // 0~1 相对坐标
    var y: Double
    var w: CGFloat = 56

    static let defaults: [ControlKey] = [
        .init(label: "W", x: 0.15, y: 0.72),
        .init(label: "A", x: 0.07, y: 0.85),
        .init(label: "S", x: 0.15, y: 0.85),
        .init(label: "D", x: 0.23, y: 0.85),
        .init(label: "跳", x: 0.85, y: 0.82, w: 64),
        .init(label: "蹲", x: 0.72, y: 0.90, w: 60),
        .init(label: "背包", x: 0.88, y: 0.58, w: 64),
    ]
}

// MARK: - 关于
struct AboutScreen: View {
    var body: some View {
        List {
            Section("关于") {
                row("应用", "ZL2-iOS（非官方）")
                row("界面", "SwiftUI 复刻 Zalith Launcher 2")
                row("启动核心", "待接入 Amethyst / Pojav")
            }
            Section("致谢与许可") {
                Text("Zalith Launcher 2 —— Jetpack Compose 界面（GPL-3.0）\nAmethyst-iOS —— Java 启动核心（GPL-3.0）\n本项目为界面层原型，遵循 GPL-3.0")
                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ZLTheme.surface)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(ZLTheme.textSecond) }
            .font(.system(size: 14))
    }
}
