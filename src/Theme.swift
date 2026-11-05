// ZL2-iOS · 主题（依据真机截图还原）
// 真机配色：米白背景 + 橄榄金主色 + 白色大圆角卡片 + 横屏
import SwiftUI
import Combine

// MARK: - 主题管理器（8 套主题来自 ZL2 Color.kt）
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themeName: String {
        didSet { UserDefaults.standard.set(themeName, forKey: "zl.theme.name") }
    }
    @Published var darkMode: Bool {
        didSet { UserDefaults.standard.set(darkMode, forKey: "zl.theme.dark") }
    }

    init() {
        let d = UserDefaults.standard
        self.themeName = d.string(forKey: "zl.theme.name") ?? ZLColorTheme.verdantField.rawValue
        self.darkMode = d.bool(forKey: "zl.theme.dark")
    }

    var theme: ZLColorTheme {
        ZLColorTheme(rawValue: themeName) ?? .verdantField
    }
}

enum ZLTheme {
    private static var tm: ThemeManager { ThemeManager.shared }
    private static var th: ZLColorTheme { tm.theme }

    // 背景与容器（跟进当前主题）
    static var background: Color   { th.background }
    static var surface: Color      { th.surface }
    static var surfaceAlt: Color   { th.surfaceContainer }
    static var stroke: Color       { th.outline }

    // 兼容旧命名（AccountScreen / LaunchScreen / ModsScreen 仍在用）
    static let cardStroke   = stroke
    static let cardBg       = surface

    // 主色（跟进当前主题）
    static var primary: Color      { th.primary }
    static var primaryDeep: Color  { th.onPrimaryContainer }
    static var primarySoft: Color  { th.primaryContainer }
    static var primaryGlow: Color  { th.secondary }

    // 文字
    static var textPrimary: Color { th.onSurface }
    static var textSecond: Color  { th.onSurfaceVariant }
    static var textOnGold: Color  { th.onPrimary }

    // 语义色
    static let success      = Color(hex: 0x4A7C3F)   // "正式版" 绿标签
    static let warning      = Color(hex: 0xC08A2E)
    static let danger       = Color(hex: 0xB3402F)

    // 圆角与间距（真机卡片圆角很大）
    static let cardRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let screenPadding: CGFloat = 18
    static let cardGap: CGFloat = 12
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 卡片（真机：米白磨砂玻璃、大圆角、柔和投影）
// 全 App 的卡片都走这里：底板从纯色换成 .zlGlass（毛玻璃 + 主题 tint + specular 描边），
// 布局尺寸、padding、圆角都没变，文字颜色仍是 ZLTheme 的 token，对比度不受影响。
struct ZLCard<Content: View>: View {
    var padding: CGFloat = 16
    var alt: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zlGlass(cornerRadius: ZLTheme.cardRadius,
                     tint: ZLTheme.primary,
                     tintOpacity: alt ? 0.10 : 0.05,
                     shadow: true)
    }
}

// MARK: - 金色胶囊按钮（真机"启动游戏"同款）
struct ZLGoldButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(ZLTheme.textOnGold)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: enabled ? [ZLTheme.primary, ZLTheme.primaryDeep]
                                    : [ZLTheme.textSecond.opacity(0.35), ZLTheme.textSecond.opacity(0.3)],
                    startPoint: .top, endPoint: .bottom)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(ZLQPressStyle(scale: 0.955, haptic: true))
        .disabled(!enabled)
    }
}

// MARK: - 顶部导航栏（返回 / 主页 / 标题 / 右侧三个图标）
struct ZLTopBar: View {
    enum TopItem { case none, multiplayer, download, settings }

    let title: String
    var showBack: Bool = true
    var active: TopItem = .none
    var onBack: (() -> Void)? = nil
    var onHome: (() -> Void)? = nil
    var onMultiplayer: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onSettings: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            if showBack { topIcon("chevron.left") { onBack?() } }
            topIcon("house.fill") { onHome?() }

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.leading, 6)

            Spacer()

            // 没传回调就不画图标（原来画了但点了没反应，还会高亮误导）
            if let a = onMultiplayer {
                topIcon("person.2.fill", highlighted: active == .multiplayer, action: a)
            }
            if let a = onDownload {
                topIcon("arrow.down.to.line", highlighted: active == .download, action: a)
            }
            if let a = onSettings {
                topIcon("gearshape.fill", highlighted: active == .settings, action: a)
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 56)
        // 顶栏加一层玻璃底（高度/内边距不变，只换底板），往上盖住状态栏那条安全区
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(ZLTheme.surface.opacity(colorScheme == .dark ? 0.82 : 0.62))
                Rectangle().fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
            }
            .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ZLTheme.stroke.opacity(0.22))
                .frame(height: 0.5)
        }
    }

    private func topIcon(_ name: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(highlighted ? ZLTheme.primaryDeep : ZLTheme.textPrimary)
                .frame(width: 44, height: 36)
                .background(highlighted ? ZLTheme.primarySoft : ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 左侧竖排图标导航（下载页 / 设置页同款）
struct ZLSideRail<Item: Identifiable & Equatable>: View {
    let items: [Item]
    let label: (Item) -> String
    let icon: (Item) -> String
    @Binding var selection: Item
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                Button {
                    selection = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(item))
                            .font(.system(size: 19, weight: .medium))
                        Text(label(item)).font(.system(size: 11))
                    }
                    .foregroundStyle(selection == item ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .frame(width: 76, height: 62)
                    .background(selection == item ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: 92)
        // 侧边栏整条加玻璃底（圆角面板），选中项的高亮仍然是主题色
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(ZLTheme.surface.opacity(colorScheme == .dark ? 0.80 : 0.55))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(ZLTheme.stroke.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - 筛选芯片（"正式版 / 快照版 …"）
struct ZLChip: View {
    let title: String
    var selected: Bool
    var checkmark: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if checkmark && selected {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(selected ? ZLTheme.primaryDeep : ZLTheme.textSecond)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(selected ? ZLTheme.primarySoft : ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ZLTheme.chipRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 状态标签（"正式版" 绿标）
struct ZLTag: View {
    let text: String
    var color: Color = ZLTheme.success

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - 兼容层：旧代码里的 ZLPrimaryButton 映射到金色按钮
struct ZLPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        ZLGoldButton(title: title, icon: icon, enabled: enabled, action: action)
    }
}
