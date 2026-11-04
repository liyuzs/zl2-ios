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
                Text("CraftLauncher")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("非官方 iOS 移植版")
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
