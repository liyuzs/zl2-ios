//
//  DiagnosticsScreen.swift
//  ZL2-iOS · 环境诊断界面
//
//  真机出问题时，用户只要打开这一页，截图或复制文本发给开发者，
//  就能省掉大量来回问答。
//

import SwiftUI
// 打包分享用到 UIDevice / UIActivityViewController / UIApplication
import UIKit

struct DiagnosticsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var items: [ZLDiagItem] = []
    @State private var running = true
    @State private var copied = false
    @State private var packing = false

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

            // 打包日志分享：真机出问题时最低成本的反馈方式。
            // 原来用户得自己进「文件」App 找 ame.log 再分享，中间每一步都可能做错；
            // 有了这个按钮就是：出问题 → 环境诊断 → 打包 → 直接发给开发者。
            Button {
                packAndShare()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: packing ? "hourglass" : "shippingbox.and.arrow.backward")
                    Text(packing ? "正在打包…" : "打包日志分享")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ZLTheme.primaryDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(ZLTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(packing || running)

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

    // MARK: 打包日志

    private func packAndShare() {
        guard !packing else { return }
        packing = true
        let diagText = ZLDiagnostics.exportText(items)
        Task {
            let zip = await Self.buildDiagnosticBundle(diagText: diagText)
            await MainActor.run {
                packing = false
                guard let zip else { return }
                let av = UIActivityViewController(activityItems: [zip], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    // iPad 上没有 popover 锚点会直接崩
                    if let pop = av.popoverPresentationController {
                        pop.sourceView = root.view
                        pop.sourceRect = CGRect(x: root.view.bounds.midX,
                                               y: root.view.bounds.midY, width: 0, height: 0)
                        pop.permittedArrowDirections = []
                    }
                    root.present(av, animated: true)
                }
            }
        }
    }

    /// 组包（纯文件 IO，放后台做）
    ///
    /// 装进去的东西按「排查价值」排序：
    ///   · 诊断报告.txt —— 页面上的检查结果 + App/系统/机型，一眼能看出环境
    ///   · ame.log      —— 核心日志，启动失败的原因基本都在这里
    ///   · latest.log   —— 游戏自己打的日志（如果进到了那一步）
    ///   · 崩溃-*        —— 最近两个 crash report
    ///   · 目录清单.txt  —— 即使日志是空的，也能看出 versions/libraries/libs 有没有东西
    private static func buildDiagnosticBundle(diagText: String) async -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mcRoot = VersionRepository.shared.mcRoot
        let stamp = Int(Date().timeIntervalSince1970)
        let stage = fm.temporaryDirectory.appendingPathComponent("zl_diag_\(stamp)")

        try? fm.removeItem(at: stage)
        guard (try? fm.createDirectory(at: stage, withIntermediateDirectories: true)) != nil else {
            return nil
        }

        // 1) 诊断报告
        var header = diagText
        let info = Bundle.main.infoDictionary
        header += "\n\n=== 设备与环境 ===\n"
        header += "App 版本：" + ((info?["CFBundleShortVersionString"] as? String) ?? "?")
        header += " (" + ((info?["CFBundleVersion"] as? String) ?? "?") + ")\n"
        header += "系统：" + UIDevice.current.systemName + " " + UIDevice.current.systemVersion + "\n"
        header += "机型：" + UIDevice.current.model + "\n"
        try? header.write(to: stage.appendingPathComponent("诊断报告.txt"),
                          atomically: true, encoding: .utf8)

        // 2) 核心日志
        let ameLog = docs.appendingPathComponent("ame.log")
        if fm.fileExists(atPath: ameLog.path) {
            try? fm.copyItem(at: ameLog, to: stage.appendingPathComponent("ame.log"))
        }

        // 3) 游戏日志
        let latest = mcRoot.appendingPathComponent("logs/latest.log")
        if fm.fileExists(atPath: latest.path) {
            try? fm.copyItem(at: latest, to: stage.appendingPathComponent("latest.log"))
        }

        // 4) 最近两个崩溃报告
        let crashDir = mcRoot.appendingPathComponent("crash-reports", isDirectory: true)
        let crashFiles = (try? fm.contentsOfDirectory(
            at: crashDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        let newest = crashFiles.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }.prefix(2)
        for f in newest {
            try? fm.copyItem(at: f, to: stage.appendingPathComponent("崩溃-" + f.lastPathComponent))
        }

        // 5) 目录清单（日志为空时也能看出安装现场）
        var tree = "=== 目录清单 ===\n"
        tree += "游戏目录：" + mcRoot.path + "\n"
        let versions = (try? fm.contentsOfDirectory(atPath: mcRoot.appendingPathComponent("versions").path)) ?? []
        tree += "versions（\(versions.count)）：" + (versions.isEmpty ? "（空）" : versions.joined(separator: ", ")) + "\n"
        let libs = (try? fm.contentsOfDirectory(atPath: mcRoot.appendingPathComponent("libraries").path)) ?? []
        tree += "libraries 顶层（\(libs.count)）：" + (libs.isEmpty ? "（空）" : libs.prefix(10).joined(separator: ", ")) + "\n"
        let bundleLibs = (try? fm.contentsOfDirectory(atPath: Bundle.main.bundlePath + "/libs")) ?? []
        tree += "bundle/libs（\(bundleLibs.count)）：" + (bundleLibs.isEmpty ? "（空 —— 这是危险信号）" : bundleLibs.sorted().joined(separator: ", ")) + "\n"
        let runtimes = (try? fm.contentsOfDirectory(atPath: Bundle.main.bundlePath + "/java_runtimes")) ?? []
        tree += "bundle/java_runtimes：" + (runtimes.isEmpty ? "（空）" : runtimes.sorted().joined(separator: ", ")) + "\n"
        try? tree.write(to: stage.appendingPathComponent("目录清单.txt"),
                        atomically: true, encoding: .utf8)

        // 6) 打成 zip（靠 NSFileCoordinator 的 forUploading 选项，系统会替我们压缩）
        var zipURL: URL?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: stage, options: [.forUploading], error: &coordError) { tmp in
            let dst = fm.temporaryDirectory.appendingPathComponent("CraftLauncher-诊断包-\(stamp).zip")
            try? fm.removeItem(at: dst)
            zipURL = (try? fm.copyItem(at: tmp, to: dst)) != nil ? dst : nil
        }
        try? fm.removeItem(at: stage)
        return zipURL
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
