// ZL2-iOS · 交互细节打磨
// 触觉反馈、按下动画、空状态、呼吸光、彩蛋
import SwiftUI
import UIKit

// MARK: - 触觉反馈

/// 统一的手感反馈。iOS 的 Taptic Engine 让每个操作都有实感。
enum ZLHaptic {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft()     { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid()    { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func failure()  { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection(){ UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - 按下动画

/// 卡片/按钮按下时轻微缩小，松手回弹（比系统默认更"有肉感"）
struct ZLPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var haptic: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { ZLHaptic.soft() }
            }
    }
}

// MARK: - 空状态

/// 比"暂无数据"友好得多的空状态
struct ZLEmptyState: View {
    var icon: String
    var title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.45))
                .padding(.bottom, 2)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ZLTheme.textSecond)

            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let actionTitle, let action {
                Button {
                    ZLHaptic.light()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(ZLTheme.primarySoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(ZLPressStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

// MARK: - 呼吸光（启动按钮用，暗示"可以点"）

struct ZLBreathingGlow: ViewModifier {
    var color: Color
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.5 : 0.12), radius: on ? 15 : 5, y: 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

extension View {
    func breathingGlow(_ color: Color) -> some View {
        modifier(ZLBreathingGlow(color: color))
    }
}

// MARK: - 彩蛋

enum ZLEasterEgg {
    /// 连点标题 7 下依次出现的文案
    static let clicks: [String] = [
        "嗯？你点了我一下",
        "这个启动器是用 SwiftUI 从零写的",
        "Minecraft Java 能跑在 iPhone 上，靠的是 JIT",
        "卡的话…先确认 StikDebug 里给 ZL2 开了 JIT",
        "键位盘可以长按空白处新建按钮",
        "第 6 下，你还挺有耐心",
        "被你发现了。去玩游戏吧 🎮"
    ]

    static func message(for count: Int) -> String? {
        let i = count - 1
        return clicks.indices.contains(i) ? clicks[i] : nil
    }

    /// 深夜问候（22 点后 / 6 点前）
    static var lateNightGreeting: String? {
        let h = Calendar.current.component(.hour, from: Date())
        guard h >= 22 || h < 6 else { return nil }
        return "这么晚了还在折腾啊"
    }
}

// MARK: - 复制到剪贴板 + 提示

enum ZLClipboard {
    /// 复制并返回一句提示，交给调用方 toast
    @discardableResult
    static func copy(_ text: String, label: String = "内容") -> String {
        UIPasteboard.general.string = text
        ZLHaptic.success()
        return "已复制\(label)"
    }
}

// MARK: - 脉冲圆点（"正在扫描"的呼吸指示）

struct ZLPulseDot: View {
    var color: Color
    var size: CGFloat = 7
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(pulse ? 1.0 : 0.45)
                .opacity(pulse ? 0.0 : 0.9)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
