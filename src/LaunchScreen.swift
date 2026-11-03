// ZL2-iOS · 启动进度页
// 对照 ZL2 启动游戏时的加载界面：阶段指示 + 滚动日志 + 失败提示
import SwiftUI

struct LaunchScreen: View {
    let versionName: String
    @Binding var isPresented: Bool

    @State private var stage: LaunchStage = .prepare
    @State private var progress: Double = 0
    @State private var logs: [String] = ["初始化启动环境…"]
    @State private var failed = false

    enum LaunchStage: String, CaseIterable {
        case prepare = "准备环境"
        case jvm     = "启动 Java 虚拟机"
        case game    = "加载游戏"
        case done    = "完成"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            footer
        }
        .background(ZLTheme.surface)
        .onAppear { simulate() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.fill")
                .font(.system(size: 22))
                .foregroundStyle(ZLTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(versionName).font(.system(size: 16, weight: .semibold))
                Text(failed ? "启动失败" : stage.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(failed ? ZLTheme.danger : ZLTheme.textSecond)
            }
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark").foregroundStyle(ZLTheme.textSecond)
            }
        }
        .padding(ZLTheme.screenPadding)
    }

    private var content: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(ZLTheme.cardStroke, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ZLTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ZLTheme.textPrimary)
            }
            .frame(width: 110, height: 110)
            .padding(.top, 24)

            stageRow
            logView
            Spacer()
        }
        .padding(.horizontal, ZLTheme.screenPadding)
    }

    private var stageRow: some View {
        HStack(spacing: 6) {
            ForEach(LaunchStage.allCases, id: \.self) { s in
                let idx = LaunchStage.allCases.firstIndex(of: s)!
                let cur = LaunchStage.allCases.firstIndex(of: stage)!
                Capsule()
                    .fill(idx <= cur ? ZLTheme.primary : ZLTheme.cardStroke)
                    .frame(height: 4)
            }
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(logs.indices, id: \.self) { i in
                        Text(logs[i])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .id(i)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(height: 180)
            .background(ZLTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ZLTheme.cardStroke, lineWidth: 1))
            .onChange(of: logs.count) { _ in
                withAnimation { proxy.scrollTo(logs.count - 1, anchor: .bottom) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if failed {
                ZLPrimaryButton(title: "查看日志", icon: "doc.text") { }
                ZLPrimaryButton(title: "关闭", icon: "xmark") { isPresented = false }
            } else {
                ZLPrimaryButton(title: stage == .done ? "关闭" : "取消", icon: stage == .done ? "checkmark" : "xmark") {
                    isPresented = false
                }
            }
        }
        .padding(ZLTheme.screenPadding)
    }

    // 演示用：真实实现由 Amethyst 的 JavaLauncher 回调驱动
    private func simulate() {
        let steps: [(LaunchStage, Double, String)] = [
            (.prepare, 0.15, "检查游戏文件完整性…"),
            (.jvm,     0.40, "分配内存 2048 MB"),
            (.jvm,     0.55, "加载 OpenJDK 17…"),
            (.game,    0.75, "加载 Forge 47.4.18…"),
            (.game,    0.90, "初始化渲染器 MobileGlues…"),
            (.done,    1.00, "启动完成"),
        ]
        for (i, s) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                stage = s.0
                progress = s.1
                logs.append(s.2)
            }
        }
    }
}
