// ZL2-iOS · 轻交互小工具
// 只依赖 UIKit，保证「长按 / 滑动 / 分享」这类 iOS 原生手感可以独立复用，
// 不跟设计系统里的其它辅助类型耦合。
import Foundation
import UIKit

enum ZLInteraction {
    enum Haptic {
        case light
        case medium
        case heavy
        case rigid
        case soft
        case selection
    }

    /// 触感反馈（对应 iOS 原生长按 / 滑动删除的手感）
    static func haptic(_ style: Haptic) {
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    /// 写入剪贴板
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
