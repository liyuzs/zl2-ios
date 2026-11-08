//
//  ZL2FrameStats.swift
//  ZL2-iOS · 把核心的帧计数翻译成可用的 FPS / 内存数值
//
//  数据来源（core/ZL2FrameStats.m）：
//    · ZL2FrameStatsTotal()          —— 自重置以来的累计帧数
//    · ZL2FrameStatsReset()          —— 清零
//    · ZL2FrameStatsResidentMemory() —— 进程常驻内存（字节），走 mach task_info
//
//  这个类每秒读一次累计帧数、做差分，就得到真实 FPS。
//  比在渲染线程里算安全得多：这里在主线程 Timer，只做加减法。
//

import Foundation

// MARK: - 核心桥接声明
//
// 这些符号由 ZL2Core 静态库提供。模拟器构建时核心不链接
// （见 project.yml 的 SWIFT_ACTIVE_COMPILATION_CONDITIONS），
// 所以用 #if 隔开，保证模拟器也能编过。

#if ZL2_CORE_LINKED
@_silgen_name("ZL2FrameStatsTotal")
private func ZL2FrameStatsTotal() -> UInt64

@_silgen_name("ZL2FrameStatsReset")
private func ZL2FrameStatsReset()

@_silgen_name("ZL2FrameStatsResidentMemory")
private func ZL2FrameStatsResidentMemory() -> UInt64
#endif

// MARK: - 采样器

/// 每秒采样一次帧数与内存，供游戏内悬浮层显示
@MainActor
final class ZL2PerfSampler: ObservableObject {

    /// 当前帧率
    @Published private(set) var fps: Int = 0
    /// 最近 N 秒的帧率（用于折线图）
    @Published private(set) var history: [Int] = []
    /// 本局最高 / 最低
    @Published private(set) var fpsMax: Int = 0
    @Published private(set) var fpsMin: Int = 0
    /// 常驻内存（MB）
    @Published private(set) var memoryMB: Int = 0

    /// 保留多少个采样点
    private let historySize = 15

    private var timer: Timer?
    private var lastTotal: UInt64 = 0
    private var lastTime: CFTimeInterval = 0
    /// 首帧前不要报 0，避免曲线开头掉一截
    private var primed = false

    /// 是否在跑
    var isRunning: Bool { timer != nil }

    // MARK: 生命周期

    func start() {
        guard timer == nil else { return }

        #if ZL2_CORE_LINKED
        ZL2FrameStatsReset()
        #endif

        lastTotal = 0
        lastTime = CACurrentMediaTime()
        primed = false
        history = []
        fpsMax = 0
        fpsMin = 0
        fps = 0

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 手动注入一次采样（宿主已有自己帧计数时用）
    func feed(fps value: Int, memoryMB mem: Int? = nil) {
        apply(fps: value, mem: mem)
    }

    // MARK: 采样

    private func tick() {
        #if ZL2_CORE_LINKED
        let total = ZL2FrameStatsTotal()
        let now = CACurrentMediaTime()
        let dt = now - lastTime
        lastTime = now

        var value = 0
        if primed, dt > 0.05 {
            let delta = total >= lastTotal ? Double(total - lastTotal) : 0
            value = Int((delta / dt).rounded())
            // 偶尔会因为暂停/切后台算出一个离谱值，钳一下
            if value > 240 { value = 240 }
        }
        lastTotal = total
        primed = true

        let mem = Int(ZL2FrameStatsResidentMemory() / 1024 / 1024)
        apply(fps: value, mem: mem > 0 ? mem : nil)
        #else
        // 模拟器：没有核心，内存仍可以取（这里用 Task 的近似值）
        let mem = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
        apply(fps: 0, mem: mem)
        #endif
    }

    private func apply(fps value: Int, mem: Int?) {
        fps = max(0, value)

        history.append(fps)
        if history.count > historySize {
            history.removeFirst(history.count - historySize)
        }

        // 只在有真实帧数时更新最高/最低
        if fps > 0 {
            if fpsMax == 0 || fps > fpsMax { fpsMax = fps }
            if fpsMin == 0 || fps < fpsMin { fpsMin = fps }
        }

        if let mem { memoryMB = mem }
    }
}
