//
//  LaunchContract.swift
//  ZL2-iOS · 启动流程契约（状态机 + 进度 + 协议 + Mock 实现）
//
//  只定义协议与轻量数据结构，不包含真实 JVM / 游戏启动逻辑。
//  真实实现（Amethyst-iOS 启动核心）后续替换 MockLaunchService 即可，UI 不用改。
//  纯 Foundation，iOS 16+
//

import Foundation

// MARK: - 启动状态

/// 启动流程的阶段。rawValue 存日志用，不要随意改名。
enum LaunchState: String, Codable, CaseIterable, Sendable {
    /// 校验版本、资源、账户
    case preparing
    /// JVM 创建与启动
    case jvm
    /// 游戏进程运行中
    case game
    /// 启动成功
    case done
    /// 启动失败
    case failed

    var displayName: String {
        switch self {
        case .preparing: return "准备中"
        case .jvm:       return "启动 JVM"
        case .game:      return "进入游戏"
        case .done:      return "完成"
        case .failed:    return "失败"
        }
    }

    /// 终态：不会再继续推进
    var isTerminal: Bool {
        self == .done || self == .failed
    }
}

// MARK: - 启动进度

/// 一次进度回调。`progress` 保证落在 0...1。
struct LaunchProgress: Equatable, Sendable {
    var state: LaunchState
    var progress: Double
    var message: String

    init(state: LaunchState, progress: Double, message: String) {
        self.state = state
        self.progress = min(max(progress, 0), 1)
        self.message = message
    }

    /// 兼容旧命名（部分文档里叫 stage）
    var stage: LaunchState { state }

    /// 等待启动时的初始值
    static let idle = LaunchProgress(state: .preparing, progress: 0, message: "等待启动")

    /// 构造一个失败态
    static func failure(_ message: String, progress: Double = 0) -> LaunchProgress {
        LaunchProgress(state: .failed, progress: progress, message: message)
    }
}

// MARK: - 错误

enum LaunchError: LocalizedError, Equatable {
    /// 版本未安装 / 版本信息缺失
    case missingVersion
    /// 未找到可用的 Java 运行时
    case javaNotFound
    /// 启动过程中崩溃
    case crashed(String)
    /// 用户取消
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingVersion:
            return "找不到可用的游戏版本"
        case .javaNotFound:
            return "未找到 Java 运行环境"
        case .crashed(let reason):
            return "游戏崩溃：\(reason)"
        case .cancelled:
            return "启动已取消"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingVersion:
            return "先在下载中心安装一个游戏版本"
        case .javaNotFound:
            return "在设置里下载并选择一个 Java 运行时"
        case .crashed:
            return "查看启动日志，或换一个版本重试"
        case .cancelled:
            return "重新点击「启动游戏」即可"
        }
    }
}

// MARK: - 轻量版本描述

/// 给启动器用的版本摘要，不依赖 MojangAPI 的完整版本结构。
struct VersionSummary: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// 版本 id，如 "1.20.1-forge"
    let id: String
    /// 加载器名字，如 "Forge" / "Fabric" / "Vanilla"
    let loader: String
    /// 加载器版本，如 "47.4.18"
    let loaderVersion: String

    init(id: String, loader: String, loaderVersion: String) {
        self.id = id
        self.loader = loader
        self.loaderVersion = loaderVersion
    }

    /// 列表/标题里展示的字符串
    var displayName: String {
        if loaderVersion.isEmpty {
            return "\(id) · \(loader)"
        }
        return "\(id) · \(loader) \(loaderVersion)"
    }

    /// 是否带模组加载器
    var hasModLoader: Bool {
        let lowered = loader.lowercased()
        return lowered != "vanilla" && lowered != "原版" && !loader.isEmpty
    }
}

// MARK: - 启动服务协议

/// 启动一个版本。实现方负责在合适的时机回调 `onProgress`（0...1 单调递增）。
protocol LaunchService {
    func start(version: VersionSummary,
               account: Account,
               onProgress: @escaping (LaunchProgress) -> Void) async throws
}

// MARK: - Mock 实现（给现有 LaunchScreen 用）

/// 假启动：按 6 个阶段推进，每阶段停 0.6 秒，过程中回调进度。
/// 方便在没有启动核心时把整条 UI 链路串起来。
final class MockLaunchService: LaunchService {

    struct Step {
        var state: LaunchState
        var progress: Double
        var message: String

        init(_ state: LaunchState, _ progress: Double, _ message: String) {
            self.state = state
            self.progress = progress
            self.message = message
        }
    }

    /// 6 个阶段
    static let defaultSteps: [Step] = [
        Step(.preparing, 0.05, "初始化启动环境"),
        Step(.preparing, 0.20, "校验版本与资源文件"),
        Step(.jvm,       0.40, "创建 Java 虚拟机"),
        Step(.jvm,       0.65, "加载 LWJGL 与模组加载器"),
        Step(.game,      0.85, "进入游戏主界面"),
        Step(.done,      1.00, "启动完成"),
    ]

    /// 每个阶段的停顿时长（秒）
    var stepDuration: TimeInterval
    private(set) var isRunning = false

    init(stepDuration: TimeInterval = 0.6) {
        self.stepDuration = stepDuration
    }

    func start(version: VersionSummary,
               account: Account,
               onProgress: @escaping (LaunchProgress) -> Void) async throws {
        guard !version.id.isEmpty else { throw LaunchError.missingVersion }

        isRunning = true
        defer { isRunning = false }

        for step in Self.defaultSteps {
            if Task.isCancelled { throw LaunchError.cancelled }
            onProgress(LaunchProgress(state: step.state,
                                      progress: step.progress,
                                      message: step.message))
            try await pause()
        }
    }

    /// 阶段间停顿；外部 Task 取消时转成 `LaunchError.cancelled`
    private func pause() async throws {
        let nanoseconds = UInt64(max(stepDuration, 0) * 1_000_000_000)
        guard nanoseconds > 0 else { return }
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            throw LaunchError.cancelled
        }
    }
}
