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

