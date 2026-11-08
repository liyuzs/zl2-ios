//
//  DiagnosticsScreen.swift
//  ZL2-iOS · 环境诊断界面
//
//  真机出问题时，用户只要打开这一页，截图或复制文本发给开发者，
//  就能省掉大量来回问答。
//

import SwiftUI

struct DiagnosticsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var items: [ZLDiagItem] = []
    @State private var running = true
    @State private var copied = false

    private var fails: Int { items.filter { $0.level == .fail }.count }
    private var warns: Int { items.filter { $0.level == .warn }.count }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "环境诊断", onBack: onBack, onHome: onHome)

            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    summaryCard

                    if !items.isEmpty {
                        resultCard
                    }

                    actionCard
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.vertical, 12)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await runChecks()
        }
    }

    // MARK: 结论

    private var summaryCard: some View {
        ZLCard(sheen: true) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(summaryColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: summarySymbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(summaryColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(summaryTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(summarySubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                if running {
                    ProgressView().scaleEffect(0.9)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var summarySymbol: String {
        if running { return "hourglass" }
        if fails > 0 { return "xmark.octagon.fill" }
        if warns > 0 { return "exclamationmark.triangle.fill" }
        return "checkmark.seal.fill"
    }

    private var summaryColor: Color {
        if running { return ZLTheme.textSecond }
        if fails > 0 { return ZLTheme.danger }
        if warns > 0 { return ZLTheme.warning }
        return ZLTheme.success
    }

    private var summaryTitle: String {
        if running { return "正在检查…" }
        if fails > 0 { return "\(fails) 项异常" }
        if warns > 0 { return "\(warns) 项需注意" }
        return "一切正常"
    }

    private var summarySubtitle: String {
        if running { return "大概需要一两秒" }
        if fails > 0 { return "这可能是启动失败的原因" }
        if warns > 0 { return "不影响基本使用，但值得看一眼" }
        return "环境符合要求，可以正常游戏"
    }

    // MARK: 检查结果

    private var resultCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("检查明细")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .padding(.bottom, 10)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().background(ZLTheme.cardStroke).padding(.vertical, 8)
                    }
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: ZLDiagItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.level.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(levelColor(item.level))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Spacer()
                        Text(item.value)
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    if let advice = item.advice {
                        Text(advice)
                            .font(.system(size: 11))
                            .foregroundStyle(levelColor(item.level).opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func levelColor(_ l: ZLDiagLevel) -> Color {
        switch l {
        case .ok:   return ZLTheme.success
        case .warn: return ZLTheme.warning
        case .fail: return ZLTheme.danger
        case .skip: return ZLTheme.textSecond
        }
    }

    // MARK: 操作

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                let text = ZLDiagnostics.exportText(items)
                UIPasteboard.general.string = text
                ZLHaptic.success()
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "已复制" : "复制诊断报告")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(copied ? ZLTheme.success : ZLTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)

            Button {
                Task { await runChecks() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新检查")
                }
                .font(.system(size: 13))
                .foregroundStyle(ZLTheme.primaryDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(ZLTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(running)
        }
    }

    // MARK: 执行

    @MainActor
    private func runChecks() async {
        running = true
        items = []
        // 让 UI 先画出「正在检查」
        await Task.yield()
        let result = await Task.detached(priority: .userInitiated) {
            ZLDiagnostics.run()
        }.value
        withAnimation(.easeOut(duration: 0.2)) {
            items = result
            running = false
        }
    }
}
