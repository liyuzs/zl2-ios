// ZL2-iOS · 高级毛玻璃 + 动态背景
// 和 ZLPolish.swift 的 Q 弹动效体系配套：这里只负责"材质"，颜色一律走
// ZLTheme / ZLColorTheme 的现有 token，所以 7 套主题 + 深色模式都不用额外改。
//
// 只用 iOS 16.0 起就确定存在的 API（material / RadialGradient / LinearGradient /
// strokeBorder / clipShape / shadow）；没有用 MeshGradient、也没有用 iOS 26 的
// .glassEffect —— 本机没有 Xcode，宁可少一个效果，也不冒 CI 编译失败的风险。
import SwiftUI

// MARK: - 动态背景（光斑缓慢漂移）

/// 首页/大页面用的动态背景：主题底色 + 2~4 个缓慢漂移的 radial 渐变光斑。
///
/// 实现方式：一个 @State 布尔 + withAnimation(.repeatForever)，SwiftUI 只在
/// 状态切换时重建一次，不靠 TimelineView 每帧重算，静止/省电模式下几乎零开销。
/// 光斑本身很淡（0.14~0.30 透明度 + 大范围渐变衰减），不会干扰读字。
struct ZLBackdrop: View {
    /// 光斑整体强度：1 = 默认，0.5 = 很淡，0 = 只剩纯主题底色
    var intensity: Double = 1
    /// 深色模式自动降亮度（只压光斑，不动底色）
    var dimInDark: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    private var dim: Double {
        if dimInDark && colorScheme == .dark { return 0.55 }
        return 1
    }

    var body: some View {
        ZStack {
            // 打底：主题背景色，保证和原来的纯色背景观感一致
            ZLTheme.background

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let long = max(w, h)

                ZStack {
                    // 主色高光（跟着主题 secondary 走）
                    ZLBackdropBlob(color: ZLTheme.primaryGlow,
                                   diameter: long * 0.85,
                                   alpha: 0.22 * intensity * dim)
                        .offset(x: drifting ? -w * 0.16 : w * 0.12,
                                y: drifting ? -h * 0.12 : h * 0.04)
                        .scaleEffect(drifting ? 1.05 : 0.94)

                    // 主色光斑
                    ZLBackdropBlob(color: ZLTheme.primary,
                                   diameter: long * 0.72,
                                   alpha: 0.14 * intensity * dim)
                        .offset(x: drifting ? w * 0.30 : -w * 0.24,
                                y: drifting ? h * 0.16 : -h * 0.10)
                        .scaleEffect(drifting ? 0.96 : 1.06)

                    // 柔和的主题浅色（暖光），压低一点
                    ZLBackdropBlob(color: ZLTheme.primarySoft,
                                   diameter: long * 0.60,
                                   alpha: 0.30 * intensity * dim)
                        .offset(x: drifting ? -w * 0.30 : -w * 0.02,
                                y: drifting ? h * 0.26 : h * 0.20)
                        .scaleEffect(drifting ? 1.08 : 1)
                }
                .frame(width: w, height: h)
            }
        }
        .clipped()
        .onAppear { startDrift() }
        .onDisappear { drifting = false }
    }

    private func startDrift() {
        // 尊重"减弱动态效果"：关了动画就保持静止，仍然好看
        if reduceMotion { return }
        withAnimation(.easeInOut(duration: 17).repeatForever(autoreverses: true)) {
            drifting = true
        }
    }
}

/// 单个光斑：用 RadialGradient 从中心向外衰减，不额外加 blur（省 GPU）
struct ZLBackdropBlob: View {
    var color: Color
    var diameter: CGFloat
    var alpha: Double

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: color.opacity(alpha), location: 0),
                        .init(color: color.opacity(alpha * 0.55), location: 0.42),
                        .init(color: color.opacity(0), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.5
                )
            )
            .frame(width: diameter, height: diameter)
    }
}

// MARK: - 玻璃底板

/// 一层玻璃：ultraThinMaterial 打底 + 一层主题底色（保文字对比度）+
/// 极淡主题色 tint + 顶部内高光 + 左上亮/右下暗的 specular 描边 + 柔和投影。
///
/// 注意：中间那层 ZLTheme.surface 不是多余的 —— 文字颜色用的是 ZLTheme 的既有
/// token（深色字），如果只铺 material，切到深色模式时 material 会变暗、字就看不清了。
/// 加一层主题底色后，7 套主题 + 深色模式下卡片都还是"米白磨砂"，对比度不变。
struct ZLGlassBackground: View {
    var cornerRadius: CGFloat = ZLTheme.cardRadius
    var tint: Color = ZLTheme.primary
    var tintOpacity: Double = 0.06
    var shadow: Bool = true
    var sheen: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// 深色模式下 App 的底色 token 仍是亮色（ZLTheme 只取亮色板），所以玻璃里的
    /// 主题底色要压得更实一点，否则卡片会比页面暗一截（字还看得清，但观感不统一）。
    private var surfaceOpacity: Double {
        colorScheme == .dark ? 0.80 : 0.55
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            // 1. 毛玻璃底
            shape.fill(.ultraThinMaterial)
            // 2. 主题底色：保证深色模式/浅色模式下文字对比度都够
            shape.fill(ZLTheme.surface.opacity(surfaceOpacity))
            // 3. 极淡主题色 tint，左上浓、右下淡
            shape.fill(
                LinearGradient(
                    colors: [tint.opacity(tintOpacity * 1.4),
                             tint.opacity(tintOpacity * 0.5),
                             tint.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
            // 4. 顶部内高光：光从上方打进来的感觉
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.20),
                             Color.white.opacity(0.02),
                             Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom))
            // 5. specular 描边：左上亮、右下暗
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.62),
                             Color.white.opacity(0.14),
                             ZLTheme.stroke.opacity(0.26),
                             Color.white.opacity(0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 1)
            // 6. 可选的慢速扫光（默认关，开了才跑动画）
            if sheen {
                ZLGlassSheen()
            }
        }
        .clipShape(shape)
        .shadow(color: shadow ? Color.black.opacity(0.10) : Color.clear,
                radius: shadow ? 14 : 0,
                x: 0,
                y: shadow ? 6 : 0)
    }
}

// MARK: - 缓慢扫过的高光（可选）

/// 一道很淡的高光缓慢扫过卡片（周期 > 6s，低强度，不闪）。
/// 只有显式 sheen: true 才会创建，关掉时连动画都不存在，不耗 CPU。
struct ZLGlassSheen: View {
    var duration: Double = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.6

    var body: some View {
        GeometryReader { geo in
            let band = max(geo.size.width * 0.45, 60)
            LinearGradient(
                colors: [Color.white.opacity(0),
                         Color.white.opacity(0.13),
                         Color.white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing)
                .frame(width: band, height: geo.size.height * 2.2)
                .rotationEffect(.degrees(16))
                .offset(x: phase * (geo.size.width + band),
                        y: -geo.size.height * 0.6)
        }
        .onAppear {
            // 开了"减弱动态效果"就不扫，别做无谓的动画
            if reduceMotion { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                phase = 1.2
            }
        }
    }
}

// MARK: - .zlGlass(...) 修饰器

/// 给任意视图套一层玻璃底板。不改变布局尺寸，内容照旧用 ZLTheme 文字 token。
struct ZLGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = ZLTheme.cardRadius
    var tint: Color = ZLTheme.primary
    var tintOpacity: Double = 0.06
    var shadow: Bool = true
    var sheen: Bool = false

    func body(content: Content) -> some View {
        content.background(
            ZLGlassBackground(cornerRadius: cornerRadius,
                              tint: tint,
                              tintOpacity: tintOpacity,
                              shadow: shadow,
                              sheen: sheen)
        )
    }
}

extension View {
    /// 毛玻璃底板：`.zlGlass()` 默认走主题主色 + 卡片圆角。
    /// 想回退成普通底色，把调用处换成 `.background(...)` 即可，一行就能撤。
    func zlGlass(cornerRadius: CGFloat = ZLTheme.cardRadius,
                 tint: Color = ZLTheme.primary,
                 tintOpacity: Double = 0.06,
                 shadow: Bool = true,
                 sheen: Bool = false) -> some View {
        modifier(ZLGlassModifier(cornerRadius: cornerRadius,
                                 tint: tint,
                                 tintOpacity: tintOpacity,
                                 shadow: shadow,
                                 sheen: sheen))
    }
}

// MARK: - 玻璃卡片（和 ZLCard 同构，底板换成玻璃）

struct ZLGlassCard<Content: View>: View {
    var padding: CGFloat
    var cornerRadius: CGFloat
    var tint: Color
    var tintOpacity: Double
    var sheen: Bool
    private let content: Content

    init(padding: CGFloat = 16,
         cornerRadius: CGFloat = ZLTheme.cardRadius,
         tint: Color = ZLTheme.primary,
         tintOpacity: Double = 0.06,
         sheen: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.tintOpacity = tintOpacity
        self.sheen = sheen
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zlGlass(cornerRadius: cornerRadius,
                     tint: tint,
                     tintOpacity: tintOpacity,
                     shadow: true,
                     sheen: sheen)
    }
}
