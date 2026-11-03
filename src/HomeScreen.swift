// ZL2-iOS · 首页（依据真机截图还原）
// 真机布局：横屏 · 左上标题 · 右上三个图标 · 右侧浮动面板（账户/版本/启动）
import SwiftUI

struct HomeScreen: View {
    @AppStorage("accountName") private var accountName = "liyuzs"
    @AppStorage("accountType") private var accountType = "LittleSkin"

    @State private var launching = false
    @State private var selectedVersion = "1.20.1 Fabric 0.19.2"

    var onMultiplayer: () -> Void = {}
    var onDownload: () -> Void = {}
    var onSettings: () -> Void = {}
    var onVersionSettings: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZLTheme.background.ignoresSafeArea()

            // 顶部：标题 + 右侧图标
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("ZalithLauncher")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .padding(.leading, ZLTheme.screenPadding)

                    Spacer()

                    HStack(spacing: 8) {
                        topButton("person.2.fill", action: onMultiplayer)
                        topButton("arrow.down.to.line", action: onDownload)
                        topButton("gearshape.fill", action: onSettings)
                    }
                    .padding(.trailing, ZLTheme.screenPadding)
                }
                .frame(height: 60)
                Spacer()
            }

            // 右侧浮动面板
            HStack {
                Spacer()
                panel
                    .frame(width: 340)
                    .padding(.trailing, ZLTheme.screenPadding)
                    .padding(.vertical, 14)
            }
        }
        .fullScreenCover(isPresented: $launching) {
            LaunchScreen(versionName: selectedVersion,
                         isPresented: Binding(get: { launching }, set: { if !$0 { launching = false } }))
        }
    }

    private func topButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .frame(width: 44, height: 36)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 右侧面板（真机：一张大圆角白卡包住账户+版本+启动）
    private var panel: some View {
        VStack(spacing: 14) {
            // 账户
            VStack(spacing: 8) {
                skinAvatar
                    .frame(width: 96, height: 96)
                Text(accountName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(accountType)
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // 版本卡片
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ZLTheme.primarySoft)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "cube.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ZLTheme.primary))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedVersion)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                    Text("1.20.1 · Fabric 0.19.2")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Spacer(minLength: 4)

                Button(action: onVersionSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 40, height: 40)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(ZLTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 启动
            ZLGoldButton(title: "启动游戏", icon: "play.fill") {
                launching = true
            }
        }
        .padding(18)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
    }

    // 用色块拼一个像素皮肤头像（避免外部资源依赖）
    private var skinAvatar: some View {
        GeometryReader { geo in
            let s = geo.size.width / 8
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0xDCE3E8))
                VStack(spacing: 0) {
                    // 头发
                    Rectangle().fill(Color(hex: 0xC9D2DA)).frame(height: s * 2)
                    // 脸
                    HStack(spacing: s) {
                        Rectangle().fill(Color(hex: 0x2B2B2B)).frame(width: s * 1.5, height: s)
                        Rectangle().fill(Color(hex: 0x2B2B2B)).frame(width: s * 1.5, height: s)
                    }
                    .frame(height: s * 2)
                    // 嘴
                    Rectangle().fill(Color(hex: 0xE8B15A)).frame(width: s * 3, height: s)
                    Spacer()
                }
                .padding(s)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
