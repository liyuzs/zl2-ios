// ZL2-iOS · 主界面
// 对照 ZL2 安卓版首页：顶部标题栏 + 账户条 + 版本卡片区 + 右下角悬浮启动按钮
import SwiftUI

struct HomeScreen: View {
    let onOpenDrawer: () -> Void
    let onOpenAccount: () -> Void

    @AppStorage("accountName") private var accountName = "wzw2333"
    @AppStorage("accountType") private var accountType = "offline"

    @State private var selected: VersionInfo? = nil
    @State private var launching: VersionInfo? = nil

    private let versions: [VersionInfo] = [
        .init(id: "1.20.1-forge",  name: "1.20.1", loader: "Forge",  loaderVersion: "47.4.18"),
        .init(id: "1.21.4-forge",  name: "1.21.4", loader: "Forge",  loaderVersion: "54.1.0"),
        .init(id: "1.20.1-fabric", name: "1.20.1", loader: "Fabric", loaderVersion: "0.16.9"),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZLTheme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    accountBar
                    versionSection
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, 110)
            }

            launchButton
        }
        .fullScreenCover(item: $launching) { v in
            LaunchScreen(
                versionName: "\(v.name) \(v.loader)",
                isPresented: Binding(
                    get: { launching != nil },
                    set: { if !$0 { launching = nil } }
                )
            )
        }
    }

    // MARK: 顶部标题栏
    private var header: some View {
        HStack(alignment: .center) {
            Button { onOpenDrawer() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Zalith Launcher")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("Minecraft: Java Edition")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: 账户条
    private var accountBar: some View {
        Button { onOpenAccount() } label: {
            ZLCard {
                HStack(spacing: 12) {
                    Circle()
                        .fill(ZLTheme.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill")
                            .foregroundStyle(ZLTheme.primary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accountName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text(accountType == "offline" ? "离线账号" : "正版账号")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 版本列表
    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("游戏版本")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Text("\(versions.count) 个")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            ForEach(versions) { v in
                VersionCard(
                    name: v.name,
                    subtitle: "\(v.loader) \(v.loaderVersion)",
                    badge: v.loader
                ) {
                    selected = v
                }
                .overlay(
                    RoundedRectangle(cornerRadius: ZLTheme.cardRadius, style: .continuous)
                        .stroke(selected?.id == v.id ? ZLTheme.primary : Color.clear, lineWidth: 2)
                )
            }
        }
    }

    // MARK: 右下角悬浮启动按钮
    private var launchButton: some View {
        Button {
            launching = selected ?? versions.first
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("启动游戏").fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 54)
            .background(ZLTheme.primary)
            .clipShape(Capsule())
            .shadow(color: ZLTheme.primary.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

struct VersionInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let loader: String
    let loaderVersion: String
}
