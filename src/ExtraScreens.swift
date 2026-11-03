// ZL2-iOS · 补充页面（Splash / LogView / Error / License / AssetInfo）
// 参考：ZL2 的 splash/SplashScreen.kt、content/LogViewScreen.kt、main/ErrorScreen.kt 等
import SwiftUI

// MARK: - 启动页（对齐 SplashScreen）
struct SplashScreen: View {
    var onFinished: () -> Void
    @State private var progress: Double = 0
    @State private var statusText = "正在准备环境…"

    private let steps: [(String, Double)] = [
        ("检查运行环境…", 0.15),
        ("加载主题配置…", 0.35),
        ("初始化游戏核心…", 0.60),
        ("扫描版本列表…", 0.85),
        ("准备就绪", 1.0)
    ]

    var body: some View {
        ZStack {
            ZLTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                // Logo
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ZLTheme.primarySoft)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "cube.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(ZLTheme.primary)
                    )
                Text("ZalithLauncher")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("iOS 版")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)

                Spacer()

                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ZLTheme.textSecond.opacity(0.15))
                            Capsule().fill(ZLTheme.primary)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 60)

                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .padding(.bottom, 50)
            }
        }
        .task { await run() }
    }

    private func run() async {
        for (text, p) in steps {
            statusText = text
            withAnimation(.easeInOut(duration: 0.4)) { progress = p }
            try? await Task.sleep(nanoseconds: 320_000_000)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        onFinished()
    }
}

// MARK: - 日志查看（对齐 LogViewScreen）
struct LogViewScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var logURL: URL? = nil

    @State private var lines: [String] = []
    @State private var autoScroll = true
    @State private var filter = ""
    @State private var fontSize = 11.0

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "运行日志", onBack: onBack, onHome: onHome)

            HStack(spacing: 8) {
                Button { reload() } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Toggle("自动滚动", isOn: $autoScroll)
                    .font(.system(size: 11)).tint(ZLTheme.primary)
                    .labelsHidden()

                TextField("过滤", text: $filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8).frame(width: 120, height: 30)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Text("\(filtered.count) 行")
                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundStyle(lineColor(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(10)
                }
                .background(ZLTheme.surface)
                .onChange(of: filtered.count) { _ in
                    if autoScroll, let last = filtered.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { reload() }
    }

    private var filtered: [String] {
        guard !filter.isEmpty else { return lines }
        return lines.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private func lineColor(_ s: String) -> Color {
        if s.contains("ERROR") || s.contains("错误") { return ZLTheme.danger }
        if s.contains("WARN") || s.contains("警告") { return ZLTheme.warning }
        if s.contains("INFO") { return ZLTheme.textPrimary }
        return ZLTheme.textSecond
    }

    private func reload() {
        guard let url = logURL ?? Self.defaultLogURL() else {
            lines = ["（没有日志文件）"]
            return
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            lines = ["（无法读取 \(url.lastPathComponent)）"]
            return
        }
        lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    static func defaultLogURL() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidates = ["latest.log", "debug.log", "ame.log"]
        for c in candidates {
            let u = docs.appendingPathComponent(c)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }
}

// MARK: - 错误页（对齐 ErrorScreen）
struct ErrorScreen: View {
    let title: String
    let message: String
    var detail: String? = nil
    var onRetry: (() -> Void)? = nil
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(ZLTheme.danger)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            if let d = detail {
                ScrollView {
                    Text(d)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 160)
                .background(ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 24)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Text("返回").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if let retry = onRetry {
                    Button { retry() } label: {
                        Text("重试").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.textOnGold)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZLTheme.background.ignoresSafeArea())
    }
}

// MARK: - 开源许可（对齐 LicenseScreen）
struct LicenseScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    private let licenses: [(String, String)] = [
        ("Zalith Launcher 2", "GNU General Public License v3.0\nCopyright © 2025-2026 MovTery"),
        ("Amethyst", "GNU General Public License v3.0\nAngel Aura Amethyst"),
        ("Terracotta", "GNU General Public License v3.0\nCopyright © BurningTNT"),
        ("LayerController", "GNU General Public License v3.0\nCopyright © MovTery"),
        ("EasyTier", "Apache License 2.0"),
        ("LWJGL", "BSD 3-Clause License"),
        ("MoltenVK", "Apache License 2.0\nCopyright © The Brenwill Workshop Ltd."),
        ("OpenJDK 17", "GNU General Public License v2.0 with Classpath Exception"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "开源许可", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(licenses, id: \.0) { name, text in
                        ZLCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(text).font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - 资源详情（对齐 AssetInfoScreen）
struct AssetInfoSheet: View {
    let title: String
    let author: String
    let description: String
    let downloads: Int
    let projectType: String
    var versions: [String] = []
    var onInstall: (() -> Void)? = nil
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        HStack(spacing: 8) {
                            Text(author).font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                            Text("·").foregroundStyle(ZLTheme.textSecond)
                            Text("\(downloads) 次下载").font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                            Text("·").foregroundStyle(ZLTheme.textSecond)
                            Text(projectType).font(.system(size: 11))
                                .foregroundStyle(ZLTheme.primaryDeep)
                        }
                    }

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)

                    if !versions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("可用版本").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            ForEach(versions.prefix(10), id: \.self) { v in
                                HStack {
                                    Text(v).font(.system(size: 11))
                                        .foregroundStyle(ZLTheme.textSecond)
                                    Spacer()
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ZLTheme.primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if let install = onInstall {
                        Button { install() } label: {
                            Text("安装")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ZLTheme.textOnGold)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(ZLTheme.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
            .background(ZLTheme.background)
            .navigationTitle("资源详情")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { onClose() }
                }
            }
        }
    }
}
