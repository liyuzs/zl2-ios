// ZL2-iOS · 任务中心（对应 ZL2 的 TaskMenu / TaskItem）
// 用途：下载、安装、导出等后台任务的统一进度管理 + 顶栏菜单
import SwiftUI
import Combine

// MARK: - 任务模型
struct ZLTask: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail: String = ""
    var progress: Double = 0        // 0~1
    var state: ZLTaskState = .running
    var startedAt = Date()

    var percentText: String { "\(Int(progress * 100))%" }
}

enum ZLTaskState: String {
    case pending = "排队中"
    case running = "进行中"
    case done = "已完成"
    case failed = "失败"
    case cancelled = "已取消"

    var isActive: Bool { self == .pending || self == .running }
}

// MARK: - 任务中心
@MainActor
final class ZLTaskCenter: ObservableObject {
    static let shared = ZLTaskCenter()
    @Published private(set) var tasks: [ZLTask] = []

    /// 有活跃任务
    var hasActive: Bool { tasks.contains { $0.state.isActive } }

    /// 总体进度（所有活跃任务的平均）
    var overallProgress: Double {
        let active = tasks.filter { $0.state.isActive }
        guard !active.isEmpty else { return 0 }
        return active.map(\.progress).reduce(0, +) / Double(active.count)
    }

    /// 活跃任务数
    var activeCount: Int { tasks.filter { $0.state.isActive }.count }

    @discardableResult
    func add(_ title: String, detail: String = "") -> UUID {
        let t = ZLTask(title: title, detail: detail)
        tasks.insert(t, at: 0)
        return t.id
    }

    func update(_ id: UUID, progress: Double? = nil, detail: String? = nil,
                state: ZLTaskState? = nil) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        if let p = progress { tasks[i].progress = min(max(p, 0), 1) }
        if let d = detail { tasks[i].detail = d }
        if let s = state { tasks[i].state = s }
        if tasks[i].state == .done { tasks[i].progress = 1 }
    }

    func cancel(_ id: UUID) {
        update(id, state: .cancelled)
    }

    func clearFinished() {
        tasks.removeAll { !$0.state.isActive }
    }

    /// 只清掉失败的，保留还在跑和已完成的
    func clearFailed() {
        tasks.removeAll { $0.state == .failed }
    }
}

// MARK: - 顶栏任务入口（进度条 + 图标）
struct ZLTaskRailButton: View {
    @ObservedObject var center = ZLTaskCenter.shared
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if center.hasActive {
                    // 进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ZLTheme.textSecond.opacity(0.15))
                            Capsule()
                                .fill(ZLTheme.primary)
                                .frame(width: geo.size.width * center.overallProgress)
                        }
                    }
                    .frame(width: 60, height: 4)
                }
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 14))
                    .foregroundStyle(center.hasActive ? ZLTheme.primary : ZLTheme.textSecond)
                    .overlay(alignment: .topTrailing) {
                        if center.activeCount > 0 {
                            Text("\(center.activeCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(ZLTheme.danger)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .padding(.horizontal, 8).frame(height: 32)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 任务菜单
struct ZLTaskMenu: View {
    @ObservedObject var center = ZLTaskCenter.shared
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if center.tasks.isEmpty {
                    ZLEmptyState(
                        icon: "checkmark.circle",
                        title: "还没有任务",
                        detail: "下载、安装、导出的时候，进度会集中出现在这里。\n这个面板关掉，任务也会继续跑")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            if failedCount > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ZLTheme.warning)
                                    Text("有 \(failedCount) 个任务失败了，可以清掉重新发起")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ZLTheme.textSecond)
                                    Spacer(minLength: 8)
                                    Button {
                                        ZLHaptic.light()
                                        center.clearFailed()
                                    } label: {
                                        Text("清理失败的")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(ZLTheme.primaryDeep)
                                            .padding(.horizontal, 10).frame(height: 28)
                                            .background(ZLTheme.primarySoft)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 4)
                                .padding(.bottom, 2)
                            }
                            ForEach(Array(center.tasks.enumerated()), id: \.element.id) { idx, task in
                                taskRow(task)
                                    .popIn(delay: Double(min(idx, 8)) * 0.035)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("清理") { center.clearFinished() }
                        .disabled(center.tasks.allSatisfy { $0.state.isActive })
                }
            }
        }
    }

    private var failedCount: Int {
        center.tasks.filter { $0.state == .failed }.count
    }

    private func taskRow(_ t: ZLTask) -> some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(t.title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                    Spacer()
                    Text(t.state.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(t.state == .failed ? ZLTheme.danger :
                                         t.state == .done ? ZLTheme.success : ZLTheme.textSecond)
                }
                if !t.detail.isEmpty {
                    Text(t.detail).font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond).lineLimit(2)
                }
                if t.state.isActive {
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ZLTheme.textSecond.opacity(0.15))
                                Capsule().fill(ZLTheme.primary)
                                    .frame(width: geo.size.width * t.progress)
                            }
                        }
                        .frame(height: 4)
                        Text(t.percentText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ZLTheme.primaryDeep).frame(width: 34)
                        Button { center.cancel(t.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
