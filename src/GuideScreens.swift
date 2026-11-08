// ZL2-iOS · 首次引导（主界面 / 控制布局编辑器）
// 对齐 ZL2 安卓版引导：半透明遮罩 + 高亮挖洞 + 白色文案气泡，轻点空白处推进
import SwiftUI

// MARK: - 高亮区域
// 屏幕归一化坐标：x / y 为中心点（0...1），width / height 为相对屏幕的比例
struct GuideSpot {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat = 18
}

// MARK: - 引导步骤
struct GuideStep: Identifiable {
    let text: String
    var icon: String = "sparkles"
    var spot: GuideSpot? = nil

    var id: String { text }
}

// MARK: - 引导遮罩（半透明遮罩 + 高亮挖洞 + 文案气泡 + 点击推进）
struct GuideOverlay: View {
    let steps: [GuideStep]
    var onFinish: () -> Void = {}

    @State private var index = 0

    private var currentStep: GuideStep? {
        guard !steps.isEmpty else { return nil }
        return steps[min(index, steps.count - 1)]
    }

    private var isLast: Bool { index >= steps.count - 1 }

    var body: some View {
        GeometryReader { geo in
            if let step = currentStep {
                content(step: step, size: geo.size)
            } else {
                Color.clear
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func content(step: GuideStep, size: CGSize) -> some View {
        let rect = spotRect(step.spot, in: size)
        let radius = step.spot?.radius ?? 18
        return ZStack {
            dimMask(rect: rect, radius: radius)
            if let rect = rect {
                highlightRing(rect: rect, radius: radius)
            }
            bubble(step: step, size: size, rect: rect)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    // 半透明遮罩；高亮处用 destinationOut 挖出透明洞
    private func dimMask(rect: CGRect?, radius: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.55)
            if let rect = rect {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .animation(.easeInOut(duration: 0.25), value: rect)
    }

    // 高亮描边（主题主色 + 柔和光晕）
    private func highlightRing(rect: CGRect, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(ZLTheme.primary, lineWidth: 2.5)
            .frame(width: rect.width + 10, height: rect.height + 10)
            .shadow(color: ZLTheme.primary.opacity(0.45), radius: 8)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.25), value: rect)
    }

    // 白色文案气泡（与首页卡片同款圆角 / 阴影）
    private func bubble(step: GuideStep, size: CGSize, rect: CGRect?) -> some View {
        let width = min(340, size.width - 56)
        let anchor = bubbleAnchor(in: size, rect: rect, width: width, height: 184)
        return VStack(alignment: .leading, spacing: 12) {
            header(step)
            Text(step.text)
                .font(.system(size: 15))
                .foregroundStyle(ZLTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous)
                .strokeBorder(ZLTheme.stroke.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 10)
        .position(x: anchor.x, y: anchor.y)
    }

    private func header(_ step: GuideStep) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZLTheme.primarySoft)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: step.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                }
            Text("第 \(index + 1) / \(steps.count) 步")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textSecond)
            Spacer(minLength: 8)
            Button {
                finish()
            } label: {
                Text("跳过")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? ZLTheme.primary : ZLTheme.primarySoft)
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
            Spacer(minLength: 12)
            Text(isLast ? "点击空白处完成" : "点击空白处继续")
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
        }
        .animation(.easeInOut(duration: 0.2), value: index)
    }

    private func spotRect(_ spot: GuideSpot?, in size: CGSize) -> CGRect? {
        guard let spot = spot else { return nil }
        let w = max(28, spot.width * size.width)
        let h = max(28, spot.height * size.height)
        return CGRect(x: spot.x * size.width - w / 2,
                      y: spot.y * size.height - h / 2,
                      width: w,
                      height: h)
    }

    // 气泡落点：避开高亮区域，尽量贴近它
    private func bubbleAnchor(in size: CGSize,
                              rect: CGRect?,
                              width: CGFloat,
                              height: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let gap: CGFloat = 18
        let inset: CGFloat = 20
        let minX = width / 2 + inset
        let maxX = size.width - width / 2 - inset
        let minY = height / 2 + inset
        let maxY = size.height - height / 2 - inset

        guard let rect = rect else {
            return (min(max(size.width / 2, minX), maxX),
                    min(max(size.height * 0.46, minY), maxY))
        }

        var x = size.width / 2
        var y = size.height / 2

        if rect.height > size.height * 0.45 {
            // 高亮区域较高：气泡放到左右另一侧
            if rect.midX > size.width / 2 {
                x = rect.minX - gap - width / 2
            } else {
                x = rect.maxX + gap + width / 2
            }
            y = rect.midY
        } else if rect.midY > size.height / 2 {
            // 高亮在下方：气泡在上方
            x = rect.midX
            y = rect.minY - gap - height / 2
        } else {
            // 高亮在上方：气泡在下方
            x = rect.midX
            y = rect.maxY + gap + height / 2
        }

        return (min(max(x, minX), maxX), min(max(y, minY), maxY))
    }

    private func advance() {
        if isLast {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.25)) { onFinish() }
    }
}

// MARK: - 引导管理（用 AppStorage 记录是否已看过）
// 用法：`HomeScreen(...).zlGuide(.home)`
struct GuideManager: View {
    enum Kind {
        case home
        case controlEditor
    }

    var kind: Kind

    @AppStorage("zl.guide.home.seen") private var homeSeen = false
    @AppStorage("zl.guide.controlEditor.seen") private var controlEditorSeen = false
    @State private var showing = false

    private var hasSeen: Bool {
        switch kind {
        case .home: return homeSeen
        case .controlEditor: return controlEditorSeen
        }
    }

    private var steps: [GuideStep] {
        switch kind {
        case .home: return GuideManager.homeSteps
        case .controlEditor: return GuideManager.controlEditorSteps
        }
    }

    var body: some View {
        Group {
            if showing {
                GuideOverlay(steps: steps) {
                    markSeen()
                    showing = false
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            guard !hasSeen else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showing = true }
        }
    }

    private func markSeen() {
        switch kind {
        case .home: homeSeen = true
        case .controlEditor: controlEditorSeen = true
        }
    }
}

// MARK: - 两套引导文案（来自 ZL2 安卓版）
extension GuideManager {
    /// 主界面引导：首次启动时覆盖在首页上
    static let homeSteps: [GuideStep] = [
        GuideStep(text: "欢迎使用 ZL2！我们来简单看看主界面的功能吧~",
                  icon: "hand.wave.fill"),
        GuideStep(text: "不太喜欢操作栏的位置？你可以长按卡片提起它，拖动并让它停靠到另一侧哦",
                  icon: "hand.draw.fill",
                  spot: GuideSpot(x: 0.78, y: 0.57, width: 0.40, height: 0.79, radius: 26))
    ]

    /// 控制布局编辑器引导：首次进入编辑器时
    static let controlEditorSteps: [GuideStep] = [
        GuideStep(text: "欢迎使用控制布局编辑器！我们来简单了解一下如何使用它吧~",
                  icon: "hand.wave.fill"),
        GuideStep(text: "这是控制布局编辑器的悬浮菜单",
                  icon: "menucard.fill",
                  spot: GuideSpot(x: 0.50, y: 0.935, width: 0.52, height: 0.12, radius: 22)),
        GuideStep(text: "这是控件层列表，你所添加的所有控件层会在此处列出~",
                  icon: "square.stack.3d.up.fill",
                  spot: GuideSpot(x: 0.09, y: 0.56, width: 0.19, height: 0.82, radius: 18)),
        GuideStep(text: "点击此按钮创建新的控件层",
                  icon: "plus.circle.fill",
                  spot: GuideSpot(x: 0.17, y: 0.21, width: 0.09, height: 0.11, radius: 14)),
        GuideStep(text: "在这里添加控件！选中控件层之后，你可以为其添加任意类型的控件~",
                  icon: "plus.square.on.square",
                  spot: GuideSpot(x: 0.955, y: 0.072, width: 0.09, height: 0.11, radius: 14)),
        GuideStep(text: "想调整控件的外观？你也可以将喜欢的样式添加到通用的收藏柜中！",
                  icon: "paintpalette.fill"),
        GuideStep(text: "可通过预览功能来测试你的控制布局哦~",
                  icon: "eye.fill",
                  spot: GuideSpot(x: 0.37, y: 0.935, width: 0.15, height: 0.12, radius: 20)),
        GuideStep(text: "完成编辑后，记得保存控制布局！",
                  icon: "square.and.arrow.down.fill",
                  spot: GuideSpot(x: 0.955, y: 0.072, width: 0.09, height: 0.11, radius: 14))
    ]

    /// 重置两套引导（调试用，下次进入对应页面会重新显示）
    static func resetAll() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "zl.guide.home.seen")
        defaults.removeObject(forKey: "zl.guide.controlEditor.seen")
    }
}

// MARK: - 接入辅助
extension View {
    /// 在页面之上叠加首次引导，例如：`.zlGuide(.home)`
    func zlGuide(_ kind: GuideManager.Kind) -> some View {
        overlay { GuideManager(kind: kind) }
    }
}
