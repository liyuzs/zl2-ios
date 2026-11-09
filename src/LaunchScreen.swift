// ZL2-iOS · 启动进度页
// 真实调用 Amethyst 核心：环境自检 → bootstrap → launchJVM
import SwiftUI
// 打包日志用到 UIActivityViewController / UIApplication
import UIKit

struct LaunchScreen: View {
    let versionName: String
    var versionID: String = ""
    /// 实例名（与 VersionInstaller 的 instanceName 对齐；跟随游戏目录页的选择）
    var instanceName: String = VersionRepository.shared.instanceName
    @Binding var isPresented: Bool

    @State private var stage: Stage = .check
    @State private var progress: Double = 0
    // 加载时随机显示一句可爱提示
    @State private var cuteTip = ZLLoadingTips.random
    @State private var logs: [String] = []
    @State private var failed = false
    @State private var lastError: String?
    @State private var packingLog = false
    @State private var packErrorText: String?
    /// 启动前预检结果（点「尝试启动」之前就能看到哪条必崩条件不满足）
    @State private var preflight: [ZLDiagItem] = []
    @State private var coreLinked = false
    @State private var runtimeReady = false
    @State private var versionReady = false

    enum Stage: String, CaseIterable {
        case check  = "环境自检"
        case boot   = "初始化核心"
        case launch = "启动 JVM"
        case done   = "已交给核心"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(ZLTheme.stroke)
            content
            if !preflight.isEmpty { preflightView }
            footer
        }
        .background(ZLTheme.background)
        .onAppear {
            runCheck()
            runPreflight()
        }
        .alert("打包失败", isPresented: Binding(
            get: { packErrorText != nil },
            set: { if !$0 { packErrorText = nil } }
        )) {
            Button("知道了", role: .cancel) { packErrorText = nil }
        } message: {
            Text(packErrorText ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.fill")
                .font(.system(size: 20))
                .foregroundStyle(ZLTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(versionName).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(failed ? "启动失败" : stage.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(failed ? ZLTheme.danger : ZLTheme.textSecond)
                if !failed {
                    // 「可爱彩蛋 4」原本就接在这里；「彩蛋 3」（按时间变化的问候）一直没接线，
                    // 现在一并显示 —— 早上/下午/晚上各一句，加载时间也就不那么干等了。
                    Text("\(ZLCuteGreeting.now) · \(cuteTip)")
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond.opacity(0.65))
                        .transition(.opacity)
                }
            }
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 36, height: 36)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(ZLTheme.screenPadding)
    }

    private var content: some View {
        VStack(spacing: 16) {
            // 自检结果
            ZLCard {
                VStack(alignment: .leading, spacing: 10) {
                    checkRow("启动核心", coreLinked, true)
                    checkRow("Java 运行时", runtimeReady, true)
                    checkRow("版本文件", versionReady, false)
                }
            }

            logView
            Spacer()
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .padding(.top, 12)
    }

    private func checkRow(_ title: String, _ ok: Bool, _ required: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : (required ? "xmark.circle.fill" : "exclamationmark.circle.fill"))
                .foregroundStyle(ok ? ZLTheme.success : ZLTheme.danger)
            Text(title).font(.system(size: 14)).foregroundStyle(ZLTheme.textPrimary)
            Spacer()
            Text(ok ? "就绪" : "缺失")
                .font(.system(size: 12))
                .foregroundStyle(ok ? ZLTheme.success : ZLTheme.danger)
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
                .padding(12)
            }
            .frame(height: 200)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: logs.count) { _ in
                withAnimation { proxy.scrollTo(logs.count - 1, anchor: .bottom) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if failed {
                VStack(spacing: 10) {
                    if let e = lastError {
                        // 常见错误 → 给具体建议
                        if e.contains("JRE") || e.contains("jli") {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb").font(.system(size: 11))
                                Text("多半是 Java 运行时没打进包里，试着重新装一次")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(ZLTheme.warning)
                        } else if e.contains("JIT") {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb").font(.system(size: 11))
                                Text("请先用 StikDebug 给本应用开启 JIT")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(ZLTheme.warning)
                        } else if e.contains("返回错误码") || e.contains("launchJVM") {
                            // 这是真机上最可能出现的一类：JVM 起来了但没走到游戏。
                            // 光一个错误码说明不了什么，具体原因在 ame.log 里。
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb").font(.system(size: 11))
                                Text("JVM 没能启动游戏。点「打包日志」把现场发出来，原因通常在日志里")
                                    .font(.system(size: 11))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(ZLTheme.warning)
                        } else if e.contains("内存") || e.contains("memory") {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb").font(.system(size: 11))
                                Text("内存不够，去设置里把分配改小一点")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(ZLTheme.warning)
                        }
                    }
                    // 失败时最该给的不是「关闭」，是「把这个现场发出去」。
                    ZLGoldButton(title: packingLog ? "正在打包…" : "打包日志发给开发者",
                                 icon: packingLog ? "hourglass" : "shippingbox.and.arrow.backward",
                                 enabled: !packingLog) {
                        packLogs()
                    }

                    HStack(spacing: 10) {
                        ZLGoldButton(title: "查看日志", icon: "doc.text") { isPresented = false }
                        Button {
                            ZLClipboard.copy(lastError ?? "未知错误", label: "错误信息")
                        } label: {
                            Text("复制错误")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ZLTheme.textSecond)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(ZLTheme.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ZLQPressStyle(scale: 0.94))
                    }
                }
            } else if coreLinked && runtimeReady {
                ZLGoldButton(title: "尝试启动", icon: "play.fill", enabled: progress >= 1) {
                    Task { await attemptLaunch() }
                }
            } else {
                ZLGoldButton(title: "关闭", icon: "xmark") { isPresented = false }
            }
        }
        .padding(ZLTheme.screenPadding)
    }

    // MARK: 启动前预检

    /// 把七项必崩条件列出来。只提示不阻止 —— 条件检查宁可宽松，
    /// 一旦把能跑的组合误判成「不能启动」，用户就永远试不了了。
    private var preflightView: some View {
        let s = ZLPreflight.summary(preflight)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: s.level.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(s.level == .fail ? ZLTheme.danger
                                     : (s.level == .warn ? ZLTheme.warning : ZLTheme.success))
                Text("启动前预检：" + s.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            ForEach(preflight) { item in
                if item.level != .ok {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: item.level.symbol)
                            .font(.system(size: 10))
                            .foregroundStyle(item.level == .fail ? ZLTheme.danger : ZLTheme.warning)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title + "：" + item.value)
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textPrimary)
                            if let a = item.advice {
                                Text(a)
                                    .font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.textSecond)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, ZLTheme.screenPadding)
        .padding(.bottom, 6)
    }

    /// 跑预检：版本元数据能读到就带上，读不到只查文件层面
    private func runPreflight() {
        let vid = versionID.isEmpty ? versionName : versionID
        let metaPath = VersionRepository.shared.mcRoot
            .appendingPathComponent("versions/\(vid)/\(vid).json").path
        var meta: [String: Any]?
        if let data = FileManager.default.contents(atPath: metaPath) {
            meta = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        preflight = ZLPreflight.run(versionID: vid, meta: meta)
    }

    // MARK: 打包日志

    /// 把「启动失败现场」也变成可发送的 zip。
    ///
    /// 复用 DiagnosticsScreen 的组包逻辑（ame.log / latest.log / 崩溃报告 / 目录清单），
    /// 额外把这一屏的错误信息和启动日志作为诊断正文塞进去 ——
    /// 真机上最需要日志的时刻就是这里，不该要求用户先去设置里找诊断页。
    private func packLogs() {
        guard !packingLog else { return }
        packingLog = true

        var note = "=== 启动失败现场 ===\n"
        note += "版本：" + versionName + "\n"
        note += "错误：" + (lastError ?? "（没有错误信息）") + "\n"
        note += "\n--- 启动页日志 ---\n"
        note += logs.isEmpty ? "（空）" : logs.joined(separator: "\n")

        Task {
            let zip = await DiagnosticsScreen.buildDiagnosticBundle(diagText: note)
            await MainActor.run {
                packingLog = false
                guard let zip else {
                    packErrorText = "打包失败，可以直接去「设置 → 环境诊断」再试一次。"
                    return
                }
                let av = UIActivityViewController(activityItems: [zip], applicationActivities: nil)
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let root = scene.windows.first?.rootViewController else {
                    packErrorText = "打包好了但打不开分享面板。文件名：" + zip.lastPathComponent
                    return
                }
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

    // MARK: 自检
    private func runCheck() {
        logs.append("开始环境自检…")
        coreLinked = CoreBridge.isCoreLinked
        runtimeReady = CoreBridge.runtimeCheck()
        let vid = versionID.isEmpty ? versionName : versionID
        // 统一走 mcRoot，切了游戏目录也能找对
        let metaPath = VersionRepository.shared.mcRoot
            .appendingPathComponent("versions/\(vid)/\(vid).json").path
        versionReady = FileManager.default.fileExists(atPath: metaPath)
        logs.append(coreLinked ? "✓ Amethyst 核心已链接" : "✗ 未链接核心（仅界面构建）")
        logs.append(runtimeReady ? "✓ 找到 java_runtimes" : "✗ 未找到 java_runtimes")
        progress = 1
        stage = .check
    }

    // MARK: 真正调用核心
    private func attemptLaunch() async {
        stage = .boot
        progress = 0.3
        logs.append("初始化 AME_HOME 与偏好…")
        do {
            try CoreBridge.bootstrap()
            logs.append("✓ 环境初始化完成")
            progress = 0.6
            stage = .launch
            logs.append("调用 launchJVM（minVersion 17）…")
            progress = 0.9
            // 说明：真正启动需要完整版本 JSON 与游戏文件；
            // 这里先验证核心可调用性，缺游戏文件会由核心返回错误码
            let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? NSTemporaryDirectory()
            // 优先用已安装版本的元数据启动
            let vid = versionID.isEmpty ? versionName : versionID
            let metaPath = VersionRepository.shared.mcRoot
                .appendingPathComponent("versions/\(vid)/\(vid).json").path
            if FileManager.default.fileExists(atPath: metaPath),
               let data = FileManager.default.contents(atPath: metaPath),
               let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                logs.append("✓ 找到版本元数据：\(metaPath)")
                logs.append("调用 launchJVM(launchTarget=版本JSON)…")
                try await CoreBridge.launchVersion(meta)
            } else {
                let probeJar = (docs as NSString).appendingPathComponent("probe.jar")
                if FileManager.default.fileExists(atPath: probeJar) {
                    logs.append("未找到已安装版本，改用 probe.jar 验证 JVM")
                    try await CoreBridge.launchJar(probeJar)
                } else {
                    logs.append("⚠ 该版本还未安装，请先到「下载」页安装")
                    logs.append("提示：安装完成后可再次点「尝试启动」")
                }
            }
            progress = 1
            stage = .done
            // 核心接手渲染后，启动页必须退场，否则会一直盖在游戏画面上
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isPresented = false
            }
            logs.append("✓ 自检流程结束")
        } catch {
            failed = true
            lastError = ZLFriendlyError.text(error)
            logs.append("✗ \(error.localizedDescription)")
        }
    }
}
