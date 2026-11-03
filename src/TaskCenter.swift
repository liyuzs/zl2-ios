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
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                        Text("暂无任务").font(.system(size: 13))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(center.tasks) { task in
                                taskRow(task)
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
