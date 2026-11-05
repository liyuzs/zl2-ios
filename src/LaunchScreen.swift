// ZL2-iOS · 启动进度页
// 真实调用 Amethyst 核心：环境自检 → bootstrap → launchJVM
import SwiftUI

struct LaunchScreen: View {
    let versionName: String
    var versionID: String = ""
    /// 实例名（与 VersionInstaller 的 instanceName 对齐；跟随游戏目录页的选择）
    var instanceName: String = VersionRepository.shared.instanceName
    @Binding var isPresented: Bool

    @State private var stage: Stage = .check
    @State private var showGameOverlay = false
    @State private var overlayMenu = false
    @State private var progress: Double = 0
    // 加载时随机显示一句可爱提示
    @State private var cuteTip = ZLLoadingTips.random
    @State private var logs: [String] = []
    @State private var failed = false
    @State private var lastError: String?
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
            footer
        }
        .background(ZLTheme.background)
        .overlay {
            // 启动成功后把游戏内悬浮层挂上（FPS 球 / 控制按钮 / 游戏内菜单）
            // 原来 GameOverlay 写了 700 行，全工程没有一处构造它
            if showGameOverlay {
                GameOverlay(isMenuPresented: $overlayMenu,
                            onForceClose: { showGameOverlay = false },
                            onShowToast: { _ in })
            }
        }
        .onAppear(perform: runCheck)
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
                    Text(cuteTip)
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
                        } else if e.contains("内存") || e.contains("memory") {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb").font(.system(size: 11))
                                Text("内存不够，去设置里把分配改小一点")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(ZLTheme.warning)
                        }
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
            showGameOverlay = true
            logs.append("✓ 自检流程结束")
        } catch {
            failed = true
            lastError = ZLFriendlyError.text(error)
            logs.append("✗ \(error.localizedDescription)")
        }
    }
}
