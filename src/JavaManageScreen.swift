// ZL2-iOS · Java 管理（按真机录屏还原）
// 结构：顶部 导入 / 新建 / 打开 Jar 文件；列表显示每个 Java 的版本与架构
import SwiftUI

struct JavaRuntime: Identifiable {
    let id = UUID()
    let name: String        // Internal-25
    let version: String     // 25.0.1
    let arch: String        // arm64
    let path: String
    let isInternal: Bool
}

struct JavaManageScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var runtimes: [JavaRuntime] = []
    @State private var alertText = ""
    @State private var showAlert = false
    @State private var importing = false
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "Java 管理", onBack: onBack, onHome: onHome)

            HStack(spacing: 10) {
                actionButton("导入", "square.and.arrow.down") { importing = true }
                actionButton("新建", "plus") { }
                actionButton("打开 Jar 文件", "doc") { }
                Spacer()
                Button { scan() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 38, height: 38)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 8) {
                    if isLoading {
                        ZLSkeletonList(count: 3, height: 72)
                    } else if let e = loadError {
                        errorState(e)
                    } else if runtimes.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(runtimes.enumerated()), id: \.element.id) { idx, rt in
                            runtimeRow(rt)
                                .popIn(delay: Double(min(idx, 10)) * 0.035)
                        }
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { scan() }
        .alert(alertText, isPresented: $showAlert) { Button("好", role: .cancel) { } }
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(ZLTheme.textSecond)
            .padding(.horizontal, 12).frame(height: 38)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ZLEmptyState(
            icon: "cup.and.saucer",
            title: "还没有 Java 运行时",
            detail: "App 自带的 JRE 会自动出现在这里。\n如果刚重装过 App，点「重新扫描」试试",
            actionTitle: "重新扫描",
            action: { scan() })
    }

    /// App 包里没有 java_runtimes 时，别让用户以为是"没装 Java"
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ZLTheme.warning)
            Text("Java 列表没能读出来")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                ZLHaptic.light()
                scan()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium))
                    Text("重试").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ZLTheme.primaryDeep)
                .padding(.horizontal, 14).frame(height: 34)
                .background(ZLTheme.primarySoft)
                .clipShape(Capsule())
            }
            .buttonStyle(ZLPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private func runtimeRow(_ rt: JavaRuntime) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 18))
                .foregroundStyle(ZLTheme.primary)
                .frame(width: 40, height: 40)
                .background(ZLTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(rt.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("版本 \(rt.version) · 架构 \(rt.arch)")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                Text(rt.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            if rt.isInternal {
                Text("内置")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ZLTheme.success)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(ZLTheme.success.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 扫描 bundle 里的 java_runtimes
    private func scan() {
        var found: [JavaRuntime] = []
        let bundle = Bundle.main.bundlePath
        let root = "\(bundle)/java_runtimes"
        let fm = FileManager.default

        // 目录不存在和目录为空是两回事：前者说明这个构建没打包 JRE
        guard fm.fileExists(atPath: root) else {
            runtimes = []
            loadError = "App 包里没有 java_runtimes 目录，\n这个构建可能没有打包内置 JRE。"
            isLoading = false
            return
        }
        guard let dirs = try? fm.contentsOfDirectory(atPath: root) else {
            runtimes = []
            loadError = "读不了 java_runtimes 目录，重装 App 试试。"
            isLoading = false
            return
        }

        for d in dirs where d.hasPrefix("java-") {
            let dir = "\(root)/\(d)"
            let libjli = "\(dir)/lib/libjli.dylib"
            guard fm.fileExists(atPath: libjli) else { continue }

            // 从目录名解析版本：java-17-openjdk → 17
            let ver = d.replacingOccurrences(of: "java-", with: "")
                .replacingOccurrences(of: "-openjdk", with: "")
                .replacingOccurrences(of: "-", with: ".")

            // 尝试读 release 文件拿精确版本
            var exact = ver
            let release = "\(dir)/release"
            if let txt = try? String(contentsOfFile: release, encoding: .utf8),
               let line = txt.split(separator: "\n").first(where: { $0.hasPrefix("JAVA_VERSION=") }) {
                exact = line.replacingOccurrences(of: "JAVA_VERSION=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
            }

            found.append(JavaRuntime(name: "Internal-\(ver)",
                                     version: exact,
                                     arch: "arm64",
                                     path: d,
                                     isInternal: true))
        }

        // 按版本号降序
        runtimes = found.sorted { a, b in
            let va = Int(a.version.split(separator: ".").first ?? "0") ?? 0
            let vb = Int(b.version.split(separator: ".").first ?? "0") ?? 0
            return va > vb
        }
        loadError = nil
        isLoading = false
    }
}
