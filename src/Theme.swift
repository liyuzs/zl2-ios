// ZL2-iOS · Material 3 风格配色与通用组件
// 目标：在 SwiftUI 里还原 ZL2 的视觉语言（深蓝主色 + 圆角卡片 + 柔和阴影）
import SwiftUI

// MARK: - 主题色板（对照 ZL2 的 Material 3 取色）
enum ZLTheme {
    static let primary      = Color(hex: 0x1B6FF3)   // 主蓝
    static let primaryDark  = Color(hex: 0x0D47A1)
    static let surface      = Color(hex: 0xF7F8FA)   // 页面底色
    static let cardBg       = Color.white
    static let cardStroke   = Color(hex: 0xE3E8EF)
    static let textPrimary  = Color(hex: 0x1A1C1E)
    static let textSecond   = Color(hex: 0x6B7280)
    static let success      = Color(hex: 0x22A06B)
    static let warning      = Color(hex: 0xE8A317)
    static let danger       = Color(hex: 0xD93025)

    static let cardRadius: CGFloat = 18
    static let screenPadding: CGFloat = 16
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - 通用卡片
struct ZLCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ZLTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous)
                    .stroke(ZLTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 主按钮（对应 ZL2 的 filled button）
struct ZLPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(enabled ? ZLTheme.primary : ZLTheme.textSecond.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!enabled)
    }
}

// MARK: - 版本卡片（ZL2 首页的核心单元）
struct VersionCard: View {
    let name: String            // 例如 "1.20.1-Forge"
    let subtitle: String        // 例如 "Forge 47.4.18"
    let badge: String?          // 例如 "Forge" / "Fabric"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ZLTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ZLTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ZLTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous)
                    .stroke(ZLTheme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
