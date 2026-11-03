// ZL2-iOS · 游戏内覆盖层（对应 ZL2 的 GameBall.kt）
// 内容：可拖动的悬浮球（FPS 数字/图表 + 内存占用 + 打开菜单）
import SwiftUI

// MARK: - FPS 显示模式（对齐 FpsDisplayMode）
enum ZLFpsDisplayMode: String, CaseIterable {
    case number = "数字"
    case chart = "图表"
}

// MARK: - 性能统计
@MainActor
final class ZLPerformanceMonitor: ObservableObject {
    static let shared = ZLPerformanceMonitor()
    @Published var fps: Int = 0
    @Published var fpsHistory: [Int] = []
    @Published var memoryUsedMB: Double = 0
    @Published var memoryTotalMB: Double = 0

    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // 真实 FPS 需从渲染循环获取；此处先用系统可用内存估算
        if let mem = Self.memoryInfo() {
            memoryUsedMB = mem.used
            memoryTotalMB = mem.total
        }
    }

    static func memoryInfo() -> (used: Double, total: Double)? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let used = Double(info.resident_size) / 1024 / 1024
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        return (used, total)
    }
}

// MARK: - 游戏覆盖层
struct GameOverlay: View {
    var onOpenMenu: () -> Void
    @ObservedObject var perf = ZLPerformanceMonitor.shared

    @AppStorage("showFPS") private var showFPS = true
    @AppStorage("showMemory") private var showMemory = false
    @AppStorage("showMenuBall") private var showMenuBall = true
    @AppStorage("fpsDisplayMode") private var fpsModeRaw = "数字"
    @AppStorage("menuBallPosX") private var ballX = 0.92
    @AppStorage("menuBallPosY") private var ballY = 0.15
    @AppStorage("menuBallOpacity") private var ballOpacity = 100.0

    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // FPS 信息块（左上角）
                if showFPS || showMemory {
                    infoBlock
                        .position(x: 80, y: 34)
                }

                // 悬浮球
                if showMenuBall {
                    gameBall
                        .position(x: geo.size.width * ballX,
                                  y: geo.size.height * ballY)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    dragging = true
                                    ballX = min(max(v.location.x / geo.size.width, 0.05), 0.95)
                                    ballY = min(max(v.location.y / geo.size.height, 0.05), 0.95)
                                }
                                .onEnded { _ in dragging = false }
                        )
                }
            }
        }
        .allowsHitTesting(true)
        .onAppear { perf.start() }
        .onDisappear { perf.stop() }
    }

    // FPS/内存信息
    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showFPS {
                if fpsModeRaw == "图表" {
                    fpsChart
                } else {
                    Text("\(perf.fps)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(fpsColor)
                }
            }
            if showMemory {
                Text("\(Int(perf.memoryUsedMB))MB")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var fpsChart: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(perf.fpsHistory.suffix(20).enumerated()), id: \.offset) { _, v in
                let h = min(Double(v) / 60.0, 1.0) * 18
                Rectangle()
                    .fill(fpsColor)
                    .frame(width: 2, height: max(h, 1))
            }
        }
        .frame(height: 18)
    }

    private var fpsColor: Color {
        perf.fps >= 50 ? .green : perf.fps >= 30 ? .yellow : .red
    }

    // 悬浮球
    private var gameBall: some View {
        Button { if !dragging { onOpenMenu() } } label: {
            Circle()
                .fill(Color.black.opacity(ballOpacity / 100 * 0.6))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.9))
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 游戏加载界面（对齐 GameInfoBox）
struct GameLoadingOverlay: View {
    let versionName: String
    let versionInfo: String
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
                Text("游戏正在运行，等待游戏画面出现中…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text("游戏版本：\(versionName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Text("游戏信息：\(versionInfo)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))

                Button { onClose() } label: {
                    Text("关闭")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).frame(height: 40)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }
}
