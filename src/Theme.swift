// ZL2-iOS · 主题（依据真机截图还原）
// 真机配色：米白背景 + 橄榄金主色 + 白色大圆角卡片 + 横屏
import SwiftUI

enum ZLTheme {
    // 背景与容器
    static let background   = Color(hex: 0xF2EDE4)   // 米白底（真机取色）
    static let surface      = Color(hex: 0xFFFFFF)   // 卡片白
    static let surfaceAlt   = Color(hex: 0xFAF7F1)   // 次级卡片
    static let stroke       = Color(hex: 0xE5DED0)   // 细边框

    // 兼容旧命名（AccountScreen / LaunchScreen / ModsScreen 仍在用）
    static let cardStroke   = stroke
    static let cardBg       = surface

    // 主色：橄榄金（真机按钮/开关/高亮同色系）
    static let primary      = Color(hex: 0x8B7D3A)
    static let primaryDeep  = Color(hex: 0x6E622D)
    static let primarySoft  = Color(hex: 0xEFE6C9)   // 选中项浅金背景
    static let primaryGlow  = Color(hex: 0xC9B76A)

    // 文字
    static let textPrimary  = Color(hex: 0x1C1A17)
    static let textSecond   = Color(hex: 0x6B6459)
    static let textOnGold   = Color(hex: 0xFFFBF2)

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

// MARK: - 卡片（真机：白底、大圆角、极浅阴影）
struct ZLCard<Content: View>: View {
    var padding: CGFloat = 16
    var alt: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alt ? ZLTheme.surfaceAlt : ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 3)
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

    var body: some View {
        HStack(spacing: 10) {
            if showBack { topIcon("chevron.left") { onBack?() } }
            topIcon("house.fill") { onHome?() }

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.leading, 6)

            Spacer()

            topIcon("person.2.fill", highlighted: active == .multiplayer) { onMultiplayer?() }
            topIcon("arrow.down.to.line", highlighted: active == .download) { onDownload?() }
            topIcon("gearshape.fill", highlighted: active == .settings) { onSettings?() }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 56)
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
