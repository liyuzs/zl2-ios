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
        "卡的话…先确认 StikDebug 里给 CraftLauncher 开了 JIT",
        "编辑器顶栏那个「＋」里能加按键、文本框和摇杆",
        "第 6 下，你还挺有耐心",
        "被你发现了。去玩游戏吧 🎮"
    ]

    static func message(for count: Int) -> String? {
        let i = count - 1
        return clicks.indices.contains(i) ? clicks[i] : nil
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

// MARK: - 骨架屏（列表加载中不再空白）

struct ZLSkeletonRow: View {
    var height: CGFloat = 58
    var corner: CGFloat = 12
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(ZLTheme.surfaceAlt)
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, ZLTheme.surface.opacity(0.75), .clear],
                        startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

/// 一组骨架行
struct ZLSkeletonList: View {
    var count: Int = 4
    var height: CGFloat = 58
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                ZLSkeletonRow(height: height)
            }
        }
    }
}

// MARK: - 列表项依次淡入

extension View {
}

// MARK: - 长按快捷菜单（版本卡片等）

/// 用 .contextMenu 实现的原生长按菜单，比自绘更符合 iOS 习惯。
/// 这里只提供文案常量，避免各处写重复字面量。
enum ZLQuickActions {
    static let play = "启动"
    static let settings = "版本设置"
    static let files = "浏览文件"
    static let copyID = "复制版本 ID"
    static let delete = "删除"
    static let refresh = "刷新"
}

// MARK: - 进度数字（等宽，滚动时不跳）

struct ZLPercentText: View {
    var value: Double        // 0...1
    var size: CGFloat = 12

    var body: some View {
        Text(String(format: "%.0f%%", max(0, min(1, value)) * 100))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(ZLTheme.textSecond)
            .contentTransition(.numericText())
    }
}

// MARK: - 彩蛋 2：节日祝福

enum ZLFestival {
    /// 今天如果是节日，返回祝福语
    static var greeting: String? {
        let cal = Calendar.current
        let now = Date()
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)

        switch (m, d) {
        case (1, 1):   return "新年快乐 🎉 今年也要好好玩 MC"
        case (2, 14):  return "情人节快乐 💛"
        case (6, 1):   return "儿童节快乐 🎈 大朋友也要玩得开心"
        case (10, 1):  return "国庆快乐 🇨🇳"
        case (12, 24), (12, 25): return "圣诞快乐 🎄"
        case (12, 31): return "今年最后一天了，明年见 👋"
        default: break
        }

        // 中秋/春节每年日期不同，用农历判断太复杂，这里就不硬猜了
        return nil
    }
}

// MARK: - 彩蛋 2：隐藏信息（点版本号 5 下）

enum ZLSecretInfo {
    static let lines: [String] = [
        "😺 你找到了这里",
        "App 里自带 3 套 Java 运行时（17 / 21 / 25），按版本自动挑",
        "界面是照着安卓版 ZL2 逐像素对的",
        "Java 在 iPhone 上跑，靠 Amethyst 核心",
        "如果启动失败，先看日志里有没有 JIT 相关提示",
        "祝你游戏愉快 🎮"
    ]

    static func line(for count: Int) -> String? {
        let i = count - 1
        return lines.indices.contains(i) ? lines[i] : nil
    }
}

// MARK: - 旋转动画（长按头像用）

struct ZLSpinEffect: ViewModifier {
    @Binding var spinning: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .scaleEffect(spinning ? 1.12 : 1)
            .animation(.spring(response: 0.55, dampingFraction: 0.6), value: spinning)
            .onChange(of: spinning) { on in
                if on {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        spinning = false
                    }
                }
            }
    }
}

extension View {
    func spinWhen(_ spinning: Binding<Bool>) -> some View {
        modifier(ZLSpinEffect(spinning: spinning))
    }
}

// MARK: - 弹跳动画（点图标用）

struct ZLBounceEffect: ViewModifier {
    @Binding var bouncing: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(bouncing ? 1.25 : 1)
            .animation(.interpolatingSpring(stiffness: 320, damping: 12), value: bouncing)
            .onChange(of: bouncing) { on in
                if on {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        bouncing = false
                    }
                }
            }
    }
}

extension View {
    func bounceWhen(_ bouncing: Binding<Bool>) -> some View {
        modifier(ZLBounceEffect(bouncing: bouncing))
    }
}

// MARK: - 可爱彩蛋 1：点哪里冒哪里的小星星

struct ZLStarBurst: View {
    var center: CGPoint
    var onDone: () -> Void

    @State private var spread: CGFloat = 0
    @State private var fade: Double = 1

    private let emojis = ["✨", "⭐️", "💫", "🌟"]

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Text(emojis[i % emojis.count])
                    .font(.system(size: 14))
                    .position(
                        x: center.x + cos(Double(i) * .pi / 3) * spread,
                        y: center.y + sin(Double(i) * .pi / 3) * spread
                    )
                    .opacity(fade)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                spread = 42
                fade = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onDone() }
        }
    }
}

// MARK: - 可爱彩蛋 2：爱心（点头像）

struct ZLHeartPop: View {
    @State private var rise: CGFloat = 0
    @State private var fade: Double = 1
    @State private var scale: CGFloat = 0.6

    private let heart = "💛"

    var body: some View {
        Text(heart)
            .font(.system(size: 20))
            .scaleEffect(scale)
            .opacity(fade)
            .offset(y: rise)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scale = 1.1 }
                withAnimation(.easeOut(duration: 1.1)) {
                    rise = -46
                    fade = 0
                }
            }
    }
}

// MARK: - 可爱彩蛋 3：按时间变化的问候

enum ZLCuteGreeting {
    /// 按当前时间说一句简单的问候
    static var now: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<11:  return "早上好"
        case 11..<13: return "中午好"
        case 13..<18: return "下午好"
        case 18..<23: return "晚上好"
        default:      return "夜深了"
        }
    }
}

// MARK: - 可爱彩蛋 4：加载时的小提示

enum ZLLoadingTips {
    static let tips = [
        "正在搬方块…",
        "苦力怕在门口等着呢…",
        "正在给 Steve 穿衣服…",
        "挖矿中，马上就好…",
        "正在数羊… 一只羊，两只羊…",
        "把红石接好了…",
        "末影人在帮你搬东西…",
        "正在给钻石剑附魔…"
    ]

    static var random: String {
        tips.randomElement() ?? "加载中…"
    }
}

// MARK: - Q弹动画曲线

/// 统一的弹性动画。response 越小越"干脆"，dampingFraction 越小越"弹"。
enum ZLSpring {
    /// 轻按反馈：干净利落
    static let tap     = Animation.spring(response: 0.22, dampingFraction: 0.72)
    /// 卡片出现：有一点弹
    static let appear  = Animation.spring(response: 0.34, dampingFraction: 0.66)
    /// 强调动作：弹得明显
    static let bouncy  = Animation.spring(response: 0.42, dampingFraction: 0.52)
    /// 页面切换：柔和顺滑
    static let page    = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// 数值变化：不弹，只顺滑
    static let smooth  = Animation.easeInOut(duration: 0.28)
}

// MARK: - Q弹按下（替代普通缩放）

struct ZLQPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var haptic: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(ZLSpring.bouncy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { ZLHaptic.soft() }
            }
    }
}

// MARK: - Q弹出现（缩放 + 弹性）

struct ZLPopIn: ViewModifier {
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.86)
            .opacity(shown ? 1 : 0)
            .animation(ZLSpring.bouncy.delay(delay), value: shown)
            .onAppear { shown = true }
    }
}

extension View {
    /// 出现时 Q 弹一下
    func popIn(delay: Double = 0) -> some View {
        modifier(ZLPopIn(delay: delay))
    }
}
// MARK: - Q弹卡片（按下会缩一下）

// MARK: - 把系统错误翻成人话

enum ZLFriendlyError {
    /// 把常见的英文网络/文件错误翻成中文，其他情况原样返回。
    static func text(_ error: Error) -> String {
        let ns = error as NSError
        let raw = ns.localizedDescription
        let lower = raw.lowercased()

        // **先按错误码判断（与语言无关）** —— 第145轮补。
        // 原来这 9 条映射全靠 `localizedDescription` 做文本匹配，而它在中文系统上
        // 已经是中文（"请求超时。"），`contains("timed out")` 永远不匹配
        // → 全部落兜底，用户看到的是"请求超时。（错误码 -1001）"。
        if ns.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: ns.code) {
            case .timedOut:
                return "网络超时，请检查网络后重试"
            case .notConnectedToInternet:
                return "没有网络连接"
            case .networkConnectionLost:
                return "网络断开了一下，重试即可"
            case .cannotConnectToHost:
                return "连不上服务器，可能是网络问题或服务器暂时不可用"
            case .cannotFindHost, .dnsLookupFailed:
                return "找不到服务器地址，请检查网络或稍后重试"
            case .secureConnectionFailed, .serverCertificateUntrusted,
                 .serverCertificateHasBadDate, .serverCertificateNotYetValid:
                return "安全连接失败，请检查网络环境"
            case .cancelled:
                return "已取消"
            // 下面这些是下载/API 场景最常见、原来会落兜底的（第146轮补）
            case .badServerResponse:
                return "服务器返回了异常状态（4xx/5xx），换个下载源或稍后重试"
            case .cannotDecodeRawData, .cannotDecodeContentData, .cannotParseResponse:
                return "服务器返回的内容不是预期格式 —— 可能是下载源返回了网页错误页，或接口变了"
            case .resourceUnavailable:
                return "服务器上找不到这个文件"
            case .userAuthenticationRequired:
                return "需要先登录才能访问"
            case .dataNotAllowed:
                return "当前网络限制了这个请求（比如开了省流量模式）"
            // 注意：文件类的这两个码在 **NSURLErrorDomain** 里，不在 NSCocoaErrorDomain
            case .fileDoesNotExist:
                return "文件不存在，可能需要重新下载"
            case .noPermissionsToReadFile:
                return "没有权限读取这个文件"
            default:
                break
            }
        }
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return "文件不存在，可能需要重新下载"
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return "没有权限访问该位置"
            case NSFileWriteOutOfSpaceError:
                return "存储空间不足"
            default:
                break
            }
        }

        // 文本匹配作**补充**（非标准错误、或非 URLSession / 文件 API 抛出的）
        // 网络类
        if lower.contains("timed out") || lower.contains("timeout") {
            return "网络超时，请检查网络后重试"
        }
        if lower.contains("offline") || lower.contains("not connected") || lower.contains("internet") {
            return "没有网络连接"
        }
        if lower.contains("could not connect") || lower.contains("cannot connect")
            || lower.contains("connection") {
            return "连不上服务器，可能是网络问题或服务器暂时不可用"
        }
        if lower.contains("ssl") || lower.contains("certificate") || lower.contains("tls") {
            return "安全连接失败，请检查网络环境"
        }
        // 文件类
        if lower.contains("no such file") || lower.contains("not exist") {
            return "文件不存在，可能需要重新下载"
        }
        if lower.contains("no permission") || lower.contains("denied") {
            return "没有权限访问该位置"
        }
        if lower.contains("not enough space") || lower.contains("disk full") {
            return "存储空间不足"
        }
        // 解析类
        if lower.contains("json") || lower.contains("parse") || lower.contains("decod") {
            return "数据格式不对，可能是下载时文件损坏，请重试"
        }
        // 兜底：带上错误码方便排查
        if ns.domain != NSCocoaErrorDomain, ns.code != 0 {
            return "\(raw)（错误码 \(ns.code)）"
        }
        return raw
    }
}

// MARK: - 崩溃日志分析

