// ZL2-iOS · 游戏内覆盖层（性能悬浮球 / 帧率 / 内存 / 菜单入口）
//
// 逐项对齐 ZL2 安卓源码：
//   ui/screens/game/elements/GameBall.kt       —— 悬浮球内容：图标 + FPS 数字/图表 + 内存条
//   ui/screens/game/elements/FpsChart.kt       —— 15 点帧率折线图（"好数"纵轴 + 当前值标注）
//   ui/components/Draggabble.kt  (FloatingBall) —— 拖动、边界夹取、拖动结束保存位置、首次置顶居中
//   ui/screens/game/GameScreen.kt:817-847      —— 悬浮球显示条件、帧率捕获生命周期、点击呼出菜单
//   ui/screens/game/GameScreen.kt:851-884      —— 返回键：编辑布局中 → 退出编辑；悬浮窗关闭 → 打开菜单；
//                                                 否则给游戏发送 ESC
//   setting/AllSettings.kt:513-533             —— showFPS / fpsDisplayMode / showMemory /
//                                                 showMenuBall / menuBallPos / menuBallOpacity
//
// 入口（安卓）：
//   · 点悬浮球 → switchMenu()（GameScreen.kt:843-845）
//   · 系统返回键：悬浮窗开着 → 发 ESC 给游戏；悬浮窗关着 → 打开菜单（GameScreen.kt:865-876）
//   · iOS 没有系统返回键：宿主可通过本视图的 `isMenuPresented` 绑定自行触发（例如 Esc 键、手势）
//
// 尚未接入（iOS 侧没有对应实现，已在代码中标注）：
//   · 真实帧率：安卓用 CallbackBridge.getCurrentFps()。iOS 端没有等价桥，
//     宿主可传 `fpsProvider`（每秒调用一次，返回当前帧率）；不传时显示 0。
//   · 内存：安卓读 ActivityManager / /proc/meminfo；iOS 用 task_vm_info.phys_footprint 与
//     ProcessInfo.physicalMemory 近似，含义与安卓的"已用/总量"不完全等价。

import SwiftUI
import UIKit
import Darwin

// MARK: - 游戏内覆盖层

struct GameOverlay: View {
    @Binding private var isMenuPresented: Bool

    @StateObject private var store = ZLSettingsStore.shared
    @StateObject private var fpsMonitor = GameFPSMonitor()

    /// 宿主提供的真实帧率（每秒取一次）；nil 时性能球显示 0（见文件头说明）
    private let fpsProvider: (() -> Int?)?
    private let sdlEnabled: Bool
    private let gyroscopeAvailable: Bool
    private let gamepadMappingConfigs: [String]
    private let enableTerracotta: Bool

    private let onForceClose: (() -> Void)?
    private let onSwitchLog: (() -> Void)?
    private let onOpenTerracottaMenu: (() -> Void)?
    private let onRefreshWindowSize: (() -> Void)?
    private let onInputMethod: (() -> Void)?
    private let onSendKeycode: (() -> Void)?
    private let onReplacementControl: (() -> Void)?
    private let onEditLayout: (() -> Void)?
    private let onShowToast: ((String) -> Void)?

    init(isMenuPresented: Binding<Bool>,
         fpsProvider: (() -> Int?)? = nil,
         sdlEnabled: Bool = false,
         gyroscopeAvailable: Bool = GameMenuScreen.systemGyroscopeAvailable,
         gamepadMappingConfigs: [String] = [],
         enableTerracotta: Bool = false,
         onForceClose: (() -> Void)? = nil,
         onSwitchLog: (() -> Void)? = nil,
         onOpenTerracottaMenu: (() -> Void)? = nil,
         onRefreshWindowSize: (() -> Void)? = nil,
         onInputMethod: (() -> Void)? = nil,
         onSendKeycode: (() -> Void)? = nil,
         onReplacementControl: (() -> Void)? = nil,
         onEditLayout: (() -> Void)? = nil,
         onShowToast: ((String) -> Void)? = nil) {
        self._isMenuPresented = isMenuPresented
        self.fpsProvider = fpsProvider
        self.sdlEnabled = sdlEnabled
        self.gyroscopeAvailable = gyroscopeAvailable
        self.gamepadMappingConfigs = gamepadMappingConfigs
        self.enableTerracotta = enableTerracotta
        self.onForceClose = onForceClose
        self.onSwitchLog = onSwitchLog
        self.onOpenTerracottaMenu = onOpenTerracottaMenu
        self.onRefreshWindowSize = onRefreshWindowSize
        self.onInputMethod = onInputMethod
        self.onSendKeycode = onSendKeycode
        self.onReplacementControl = onReplacementControl
        self.onEditLayout = onEditLayout
        self.onShowToast = onShowToast
    }

    var body: some View {
        ZStack {
            if isMenuPresented {
                GameMenuScreen(isPresented: $isMenuPresented,
                               sdlEnabled: sdlEnabled,
                               gyroscopeAvailable: gyroscopeAvailable,
                               gamepadMappingConfigs: gamepadMappingConfigs,
                               enableTerracotta: enableTerracotta,
                               onForceClose: onForceClose,
                               onSwitchLog: onSwitchLog,
                               onOpenTerracottaMenu: onOpenTerracottaMenu,
                               onRefreshWindowSize: onRefreshWindowSize,
                               onInputMethod: onInputMethod,
                               onSendKeycode: onSendKeycode,
                               onReplacementControl: onReplacementControl,
                               onEditLayout: onEditLayout,
                               onShowToast: onShowToast)
                    .zIndex(1)
            }

            // 悬浮球画在菜单之上（GameScreen.kt 里 DraggableGameBall 在 GameMenuSubscreen 之后组合）
            if showMenuBall {
                GamePerformanceBall(
                    position: ballPosition,
                    alpha: menuBallOpacity,
                    opened: isMenuPresented,
                    fps: showFPS ? fpsMonitor.fps : nil,
                    fpsDisplayMode: stringValue("fpsDisplayMode"),
                    fpsHistory: fpsMonitor.history,
                    fpsMax: fpsMonitor.fpsMax,
                    fpsMin: fpsMonitor.fpsMin,
                    showMemory: showMemory,
                    onMove: { moveBall($0) },
                    onSave: { moveBall($0) },
                    onTap: { isMenuPresented.toggle() }
                )
                .zIndex(2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            fpsMonitor.provider = fpsProvider
            syncFPSCapture()
        }
        .onChange(of: fpsCaptureEnabled) { enabled in
            if enabled {
                fpsMonitor.start()
            } else {
                fpsMonitor.stop()
            }
        }
        .onDisappear {
            fpsMonitor.stop()
        }
    }

    // MARK: 设置读取

    private var showMenuBall: Bool { boolValue("showMenuBall") }
    private var showFPS: Bool { boolValue("showFPS") }
    private var showMemory: Bool { boolValue("showMemory") }

    /// 安卓只在「悬浮窗开启」的块里启动帧率捕获，并且受 showFPS 控制（GameScreen.kt:817-825）
    private var fpsCaptureEnabled: Bool { showMenuBall && showFPS }

    private var menuBallOpacity: Double {
        Double(min(max(intValue("menuBallOpacity"), 20), 100)) / 100.0
    }

    /// 安卓 menuBallPos 是绝对屏幕坐标，用 "x,y" 存储
    private var ballPosition: CGPoint {
        let point = ZLSettingsStore.parsePoint(stringValue("menuBallPos"))
        return CGPoint(x: point.0, y: point.1)
    }

    private func boolValue(_ key: String) -> Bool {
        guard let def = ZLSettings.def(key) else { return false }
        return store.bool(def)
    }

    private func intValue(_ key: String) -> Int {
        guard let def = ZLSettings.def(key) else { return 0 }
        return store.int(def)
    }

    private func stringValue(_ key: String) -> String {
        guard let def = ZLSettings.def(key) else { return "" }
        return store.string(def)
    }

    private func moveBall(_ point: CGPoint) {
        guard let def = ZLSettings.def("menuBallPos") else { return }
        store.set(def, "\(Int(point.x.rounded())),\(Int(point.y.rounded()))")
    }

    private func syncFPSCapture() {
        if fpsCaptureEnabled {
            fpsMonitor.start()
        } else {
            fpsMonitor.stop()
        }
    }
}

// MARK: - 帧率采样（GameScreen.kt:141-255 的移植）

final class GameFPSMonitor: ObservableObject {
    /// 帧率历史记录的最大时间节点数（GameScreen.kt:142）
    static let historySize = 15
    /// 最高/最低帧所在节点被清理后，重算前等待的时间节点数（GameScreen.kt:144）
    static let resyncNodes = 10

    @Published private(set) var fps = 0
    @Published private(set) var history: [Int] = []
    @Published private(set) var fpsMax = 0
    @Published private(set) var fpsMin = 0

    /// 宿主可提供真实帧率；返回 nil 时回退到 recordFrame() 的计数
    var provider: (() -> Int?)?

    private var timer: Timer?
    private var frameCount = 0
    private var maxResyncCountdown = -1
    private var minResyncCountdown = -1

    /// 开始帧率捕获（对应 startFpsCapture）
    func start() {
        guard timer == nil else { return }
        history = []
        fpsMax = 0
        fpsMin = 0
        maxResyncCountdown = -1
        minResyncCountdown = -1
        frameCount = 0

        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// 停止帧率捕获（对应 stopFpsCapture）
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 由渲染循环每帧调用一次（等价于安卓 CallbackBridge 的帧计数）
    func recordFrame() {
        frameCount += 1
    }

    /// 直接注入一次采样（宿主已有原生帧率计数时使用）
    func feed(_ value: Int) {
        record(value)
    }

    private func tick() {
        let value = provider?() ?? frameCount
        frameCount = 0
        record(value)
    }

    /// 记录一次帧率采样，并维护记录范围内的最高/最低帧（GameScreen.kt:215-255）
    private func record(_ value: Int) {
        fps = value

        if maxResyncCountdown > 0 { maxResyncCountdown -= 1 }
        if minResyncCountdown > 0 { minResyncCountdown -= 1 }
        if maxResyncCountdown == 0 {
            fpsMax = history.max() ?? 0
            maxResyncCountdown = -1
        }
        if minResyncCountdown == 0 {
            fpsMin = history.min() ?? 0
            minResyncCountdown = -1
        }

        if history.isEmpty {
            fpsMax = value
            fpsMin = value
        } else {
            if value > fpsMax {
                fpsMax = value
                maxResyncCountdown = -1
            }
            if value < fpsMin {
                fpsMin = value
                minResyncCountdown = -1
            }
        }
        history.append(value)

        if history.count > Self.historySize {
            let removed = history.removeFirst()
            if removed == fpsMax && !history.contains(fpsMax) {
                maxResyncCountdown = Self.resyncNodes
            }
            if removed == fpsMin && !history.contains(fpsMin) {
                minResyncCountdown = Self.resyncNodes
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - 帧率图表（FpsChart.kt:96-273 的移植）

struct GameFPSChart: View {
    let history: [Int]
    let fpsMax: Int
    let fpsMin: Int

    /// 纵轴分割段数（FpsChart.kt:57）
    private static let segments = 5
    /// 纵轴刻度步长的候选"好数"（FpsChart.kt:60）
    private static let axisSteps = [1, 2, 5, 10, 15, 20, 30, 60, 120, 240]
    private static let labelFont = Font.system(size: 9)
    /// 纵轴标注框高度，数字在其中垂直居中（FpsChart.kt:94）
    private static let labelHeight: CGFloat = 12

    private var bounds: (min: Int, max: Int) {
        Self.niceBounds(fpsMin: fpsMin, fpsMax: fpsMax)
    }

    private var ticks: [Int] {
        let range = bounds
        let step = (range.max - range.min) / Self.segments
        return (0...Self.segments).map { range.min + step * $0 }
    }

    /// 纵轴的"好数"范围（FpsChart.kt:66-88）
    private static func niceBounds(fpsMin: Int, fpsMax: Int) -> (min: Int, max: Int) {
        let range = max(0, fpsMax - fpsMin)
        for step in axisSteps {
            let span = step * segments
            if span < range { continue }
            let extra = span - range
            // 向下取整到步长网格（余量为负时向负无穷取整）
            let raw = fpsMin - extra / 2
            var axisMin = raw / step * step
            if raw < 0 && raw % step != 0 { axisMin -= step }
            var axisMax = axisMin + span
            if axisMax < fpsMax {
                axisMax = (fpsMax + step - 1) / step * step
                axisMin = axisMax - span
            }
            if axisMin < 0 {
                axisMin = 0
                axisMax = span
            }
            return (axisMin, axisMax)
        }
        return (fpsMin, fpsMax)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // 纵轴帧率标注：最高帧在上，最低帧在下（Arrangement.SpaceBetween）
            VStack(alignment: .trailing, spacing: 0) {
                let labels = Array(ticks.reversed())
                ForEach(labels.indices, id: \.self) { index in
                    Text("\(labels[index])")
                        .font(Self.labelFont)
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(height: Self.labelHeight, alignment: .trailing)
                    if index < labels.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Canvas { context, size in
                drawChart(context: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: 170, height: 95)
        .background(ThemeManager.shared.theme.secondaryContainer.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 绘制帧率图表（FpsChart.kt:178-273）
    private func drawChart(context: inout GraphicsContext, size: CGSize) {
        let range = bounds
        let axisRange = max(1, range.max - range.min)
        let pointRadius: CGFloat = 1.25
        let gridWidth: CGFloat = 1
        // 横向内缩半个点加半条分割线；纵向内缩半个标注框，使刻度数字中心与分割线对齐
        let insetX = pointRadius + gridWidth / 2
        let insetY = Self.labelHeight / 2

        let curveColor = ZLTheme.primary
        let lineColor = ZLTheme.primary.opacity(0.3)
        let labelColor = ZLTheme.textSecond

        // 水平分割线
        for k in 0...Self.segments {
            let fraction = CGFloat(k) / CGFloat(Self.segments)
            let y = insetY + fraction * (size.height - insetY * 2)
            var path = Path()
            path.move(to: CGPoint(x: insetX, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(lineColor), lineWidth: gridWidth)
        }
        // 纵轴分割线：坐标区与数字的交界
        var axisPath = Path()
        axisPath.move(to: CGPoint(x: insetX, y: insetY))
        axisPath.addLine(to: CGPoint(x: insetX, y: size.height - insetY))
        context.stroke(axisPath, with: .color(lineColor), lineWidth: gridWidth)

        guard !history.isEmpty else { return }

        let points = history.enumerated().map { index, value -> CGPoint in
            let x: CGFloat
            if history.count == 1 {
                x = (insetX + size.width) / 2
            } else {
                x = insetX + CGFloat(index) * (size.width - insetX * 2) / CGFloat(history.count - 1)
            }
            let ratio = CGFloat(value - range.min) / CGFloat(axisRange)
            let y = insetY + (1 - ratio) * (size.height - insetY * 2)
            return CGPoint(x: x, y: y)
        }

        // 相邻点之间用带轻微圆滑度的折线相连
        var curve = Path()
        curve.move(to: points[0])
        for i in 1..<points.count {
            let start = points[i - 1]
            let end = points[i]
            let offset = (end.x - start.x) * 0.25
            curve.addCurve(to: end,
                           control1: CGPoint(x: start.x + offset, y: start.y),
                           control2: CGPoint(x: end.x - offset, y: end.y))
        }
        context.stroke(curve, with: .color(curveColor),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        for point in points {
            let dot = Path(ellipseIn: CGRect(x: point.x - pointRadius,
                                             y: point.y - pointRadius,
                                             width: pointRadius * 2,
                                             height: pointRadius * 2))
            context.fill(dot, with: .color(curveColor))
        }

        // 当前帧率标注：放在最后一个点的上/下方，避开来向线条，且不越过上下刻度线
        guard let lastValue = history.last else { return }
        let resolved = context.resolve(Text("\(lastValue)").font(Self.labelFont).foregroundColor(labelColor))
        let measured = resolved.measure(in: CGSize(width: 200, height: 100))
        let last = points[points.count - 1]
        let gap: CGFloat = 2
        let canBelow = last.y + gap + measured.height <= size.height - insetY
        let canAbove = last.y - gap - measured.height >= insetY
        let prevY: CGFloat? = points.count >= 2 ? points[points.count - 2].y : nil

        let placeBelow: Bool
        if canBelow && !canAbove {
            placeBelow = true
        } else if !canBelow && canAbove {
            placeBelow = false
        } else if let prevY, prevY < last.y {
            placeBelow = true
        } else if let prevY, prevY > last.y {
            placeBelow = false
        } else {
            placeBelow = last.y <= size.height / 2
        }

        let origin = CGPoint(x: size.width - measured.width,
                             y: placeBelow ? last.y + gap : last.y - gap - measured.height)
        context.draw(resolved, at: origin, anchor: .topLeading)
    }
}

// MARK: - 内存采样

final class GameMemorySampler: ObservableObject {
    @Published private(set) var usedMB: Double = 0
    @Published private(set) var totalMB: Double = 0

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        // 安卓是从设备总内存 / 进程已用内存计算；iOS 用物理内存 + 进程 phys_footprint 近似
        totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        usedMB = Self.footprintMB()
    }

    /// 进程物理内存占用（task_vm_info.phys_footprint）
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1024 / 1024
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - 内存条（CommonElements.kt:563-710 在球内的形态）

struct GameMemoryBar: View {
    @StateObject private var sampler = GameMemorySampler()

    private var ratio: CGFloat {
        guard sampler.totalMB > 0 else { return 0 }
        return min(1, max(0, CGFloat(sampler.usedMB / sampler.totalMB)))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ZLTheme.surfaceAlt.opacity(0.6))

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ZLTheme.primary.opacity(0.6))
                    .frame(width: geo.size.width * ratio)
            }

            Text("\(Int(sampler.usedMB))MB/\(Int(sampler.totalMB))MB")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.leading, 8)
                .lineLimit(1)
        }
        .frame(minWidth: 168, minHeight: 18)
        .onAppear { sampler.start() }
        .onDisappear { sampler.stop() }
    }
}

// MARK: - 性能悬浮球（GameBall.kt:58-223 + FloatingBall）

struct GamePerformanceBall: View {
    let position: CGPoint
    let alpha: Double
    let opened: Bool
    let fps: Int?
    let fpsDisplayMode: String
    let fpsHistory: [Int]
    let fpsMax: Int
    let fpsMin: Int
    let showMemory: Bool

    let onMove: (CGPoint) -> Void
    let onSave: (CGPoint) -> Void
    let onTap: () -> Void

    @State private var size: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var dragPosition: CGPoint?

    init(position: CGPoint,
         alpha: Double = 1,
         opened: Bool = false,
         fps: Int? = nil,
         fpsDisplayMode: String = "FpsDisplayMode.NUMBER",
         fpsHistory: [Int] = [],
         fpsMax: Int = 0,
         fpsMin: Int = 0,
         showMemory: Bool = false,
         onMove: @escaping (CGPoint) -> Void = { _ in },
         onSave: @escaping (CGPoint) -> Void = { _ in },
         onTap: @escaping () -> Void = {}) {
        self.position = position
        self.alpha = alpha
        self.opened = opened
        self.fps = fps
        self.fpsDisplayMode = fpsDisplayMode
        self.fpsHistory = fpsHistory
        self.fpsMax = fpsMax
        self.fpsMin = fpsMin
        self.showMemory = showMemory
        self.onMove = onMove
        self.onSave = onSave
        self.onTap = onTap
    }

    var body: some View {
        GeometryReader { geo in
            let current = clamp(dragPosition ?? effectivePosition(in: geo.size), in: geo.size)

            content
                .opacity(size == .zero ? 0 : alpha)
                .background(GeometryReader { proxy in
                    Color.clear
                        .onAppear { size = proxy.size }
                        .onChange(of: proxy.size) { newSize in size = newSize }
                })
                .offset(x: current.x, y: current.y)
                .gesture(dragGesture(in: geo.size))
                .onTapGesture { onTap() }
                .onChange(of: size) { newSize in
                    // 首次得到尺寸时，把悬浮球放到屏幕 TopCenter（FloatingBall.kt:101-110）
                    guard newSize != .zero, position == .zero else { return }
                    onMove(CGPoint(x: max(0, (geo.size.width - newSize.width) / 2), y: 0))
                }
                .onChange(of: geo.size) { newContainer in
                    // 屏幕尺寸变化时把球夹回屏幕内（FloatingBall.kt:84-96）
                    let clamped = clamp(position, in: newContainer)
                    if clamped != position { onMove(clamped) }
                }
        }
        .ignoresSafeArea()
    }

    // MARK: 球内容（GameBall.kt:95-210）

    @ViewBuilder
    private var content: some View {
        let showFPS = fps != nil
        let showChart = showFPS && fpsDisplayMode == "FpsDisplayMode.CHART"
        // 图标在「显示内存」或「图表模式」时隐藏
        let showIcon = !(showMemory || (showFPS && showChart))

        HStack(spacing: 0) {
            if showIcon {
                Image(systemName: opened ? "xmark" : "line.3.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(width: 28, height: 28)
            }

            if showFPS || showMemory {
                Spacer().frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                if showFPS || showMemory {
                    Spacer().frame(height: 4)
                }

                if showFPS {
                    if showChart {
                        GameFPSChart(history: fpsHistory, fpsMax: fpsMax, fpsMin: fpsMin)
                    } else {
                        Text("FPS: \(fps ?? 0)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .padding(.trailing, 4)
                    }
                }

                if showFPS && showMemory {
                    Spacer().frame(height: 4)
                }

                if showMemory {
                    GameMemoryBar()
                }

                if showFPS || showMemory {
                    Spacer().frame(height: 4)
                }
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: 位置与拖动

    /// 未设置过位置时：水平居中、贴顶（FloatingBall.kt:106-108）
    private func effectivePosition(in container: CGSize) -> CGPoint {
        guard position == .zero else { return position }
        return CGPoint(x: max(0, (container.width - size.width) / 2), y: 0)
    }

    private func clamp(_ point: CGPoint, in container: CGSize) -> CGPoint {
        let maxX = max(0, container.width - size.width)
        let maxY = max(0, container.height - size.height)
        return CGPoint(x: min(max(0, point.x), maxX),
                       y: min(max(0, point.y), maxY))
    }

    /// 拖动超过 6pt 才算拖动，否则抬起时算点击（FloatingBall.kt:120-178）
    private func dragGesture(in container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let start = dragStart ?? clamp(position, in: container)
                if dragStart == nil { dragStart = start }
                dragPosition = clamp(CGPoint(x: start.x + value.translation.width,
                                             y: start.y + value.translation.height),
                                     in: container)
            }
            .onEnded { _ in
                if let finalPosition = dragPosition {
                    onMove(finalPosition)
                    onSave(finalPosition)
                }
                dragStart = nil
                dragPosition = nil
            }
    }
}
