// ZL2-iOS · 首页（依据真机截图还原）
// 真机布局：横屏 · 左上标题 · 右上三个图标 · 右侧浮动面板（账户/版本/启动）
import SwiftUI

struct HomeScreen: View {
    /// 点头像进账号页（原来账号页根本没有任何入口）
    var onAccount: () -> Void = {}
    @AppStorage("accountName") private var accountName = ""
    /// 存的是枚举原始值（offline/microsoft/authlib），显示时转中文
    @AppStorage("accountType") private var accountTypeRaw = ""

    private var accountType: String {
        switch accountTypeRaw {
        case "microsoft": return "微软账号"
        case "authlib":   return "外置认证"
        case "offline":   return "离线账号"
        default:          return "未登录，点头像去登录"
        }
    }

    @State private var launching = false
    // 真正的版本名由 onAppear 从已安装列表里取，不能写死
    @State private var selectedVersion = ""
    // 彩蛋：连点标题
    @State private var titleTaps = 0
    @State private var eggText: String?
    @State private var eggToken = 0
    @State private var didGreet = false
    // 彩蛋 2
    @State private var avatarSpinning = false
    @State private var iconBouncing = false
    @State private var versionTaps = 0
    @State private var secretIdx = 0
    @State private var blankTaps = 0
    // 可爱彩蛋

    var onMultiplayer: () -> Void = {}
    var onDownload: () -> Void = {}
    var onSettings: () -> Void = {}
    var onFileManager: () -> Void = {}
    @State private var showTaskMenu = false
    var onVersionSettings: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZLTheme.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { blankTap() }

            // 顶部：标题 + 右侧图标
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CraftLauncher")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("非官方 iOS 移植版 · 基于 Zalith Launcher 2")
                            .font(.system(size: 9))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
                    }
                    .padding(.leading, ZLTheme.screenPadding)
                    .onTapGesture { titleTap() }

                    Spacer()

                    HStack(spacing: 8) {
                        ZLTaskRailButton { showTaskMenu = true }
                        topButton("folder", action: onFileManager)
                        topButton("person.2", action: onMultiplayer)
                        topButton("arrow.down.to.line", action: onDownload)
                        topButton("gearshape", action: onSettings)
                    }
                    .padding(.trailing, ZLTheme.screenPadding)
                }
                .frame(height: 46)
                Spacer()
            }

            // 右侧浮动面板（下移，避免遮住顶部图标）
            HStack {
                Spacer()
                panel
                    .frame(width: 340)
                    .popIn(delay: 0.05)
                    .padding(.trailing, ZLTheme.screenPadding)
                    .padding(.top, 66)
                    .padding(.bottom, 14)
            }
        }
        .overlay(alignment: .top) {
            if let eggText {
                Text(eggText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(ZLTheme.primaryDeep)
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    )
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(eggToken)
            }
        }
        .fullScreenCover(isPresented: $launching) {
            LaunchScreen(versionName: selectedVersion,
                         versionID: selectedVersion,
                         isPresented: Binding(get: { launching }, set: { if !$0 { launching = false } }))
        }
        .sheet(isPresented: $showTaskMenu) {
            ZLTaskMenu(onClose: { showTaskMenu = false })
        }
        // Siri / 快捷指令要求自动启动
        .onReceive(NotificationCenter.default.publisher(for: .zlAutoLaunch)) { _ in
            guard !selectedVersion.isEmpty, !selectedVersion.hasPrefix("还没有") else { return }
            ZLHaptic.success()
            launching = true
        }
        .onAppear {
            // 每次都从磁盘读一遍已安装版本（切过目录也能跟上）
            refreshInstalledVersion()
            // 深夜第一次进来自动打个招呼（小彩蛋）
            if !didGreet {
                didGreet = true
                // 节日优先，其次深夜
                if let f = ZLFestival.greeting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showEgg(f, duration: 3.4)
                    }
                }
            }
        }
    }

    // MARK: - 彩蛋

    private func titleTap() {
        titleTaps += 1
        ZLHaptic.selection()
        guard let msg = ZLEasterEgg.message(for: titleTaps) else { return }
        ZLHaptic.light()
        showEgg(msg, duration: 3.0)
        let token = eggToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard eggToken == token else { return }
            if titleTaps >= ZLEasterEgg.clicks.count { titleTaps = 0 }
        }
    }

    // MARK: - 彩蛋 2：版本号连点

    private func versionTap() {
        versionTaps += 1
        ZLHaptic.selection()

        // 第 5 下开始吐隐藏信息
        if versionTaps >= 5 {
            let idx = versionTaps - 4
            if let line = ZLSecretInfo.line(for: idx) {
                showEgg(line, duration: 3.0)
            } else {
                versionTaps = 0
            }
        }
        // 8 秒内不继续点就重置
        let token = eggToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            guard eggToken == token else { return }
            if versionTaps < 5 { versionTaps = 0 }
        }
    }

    /// 统一显示一条彩蛋提示
    private func showEgg(_ text: String, duration: TimeInterval) {
        eggToken += 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { eggText = text }
        let token = eggToken
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard eggToken == token else { return }
            withAnimation(.easeOut(duration: 0.22)) { eggText = nil }
        }
    }

    // MARK: - 彩蛋 3：点空白处

    private static let blankMessages = [
        "这里什么都没有",
        "真的什么都没有",
        "别点了，去玩游戏吧",
        "好吧，你赢了 ✨",
        "彩蛋已解锁：祝你今天顺利"
    ]

    private func blankTap() {
        blankTaps += 1
        let i = blankTaps - 1
        guard Self.blankMessages.indices.contains(i) else {
            blankTaps = 0
            return
        }
        ZLHaptic.light()
        showEgg(Self.blankMessages[i], duration: 2.2)
    }

    private func topButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            ZLHaptic.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 38, height: 32)
                .background(Color.clear)
        }
        .buttonStyle(ZLQPressStyle(scale: 0.88))
    }

    // MARK: 右侧面板（真机：一张大圆角白卡包住账户+版本+启动）
    private var panel: some View {
        VStack(spacing: 14) {
            // 账户
            VStack(spacing: 8) {
                skinAvatar
                    .frame(width: 96, height: 96)
                    .spinWhen($avatarSpinning)
                    .onLongPressGesture(minimumDuration: 0.35) {
                        ZLHaptic.rigid()
                        avatarSpinning = true
                    }
                Text(accountName.isEmpty ? "未登录" : accountName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(accountType)
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                Button {
                    ZLHaptic.light()
                    onAccount()
                } label: {
                    Text(accountName.isEmpty ? "去登录" : "切换账号")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(ZLTheme.primarySoft))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // 版本卡片
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ZLTheme.primarySoft)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "cube.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ZLTheme.primary)
                            .bounceWhen($iconBouncing)
                    )
                    .onTapGesture {
                        ZLHaptic.light()
                        iconBouncing = true
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedVersion.isEmpty ? "还没有安装版本" : selectedVersion)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                        .onTapGesture { versionTap() }
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
            .contextMenu {
                Button {
                    ZLHaptic.medium()
                    launching = true
                } label: { Label(ZLQuickActions.play, systemImage: "play.fill") }

                Button {
                    ZLHaptic.light()
                    onVersionSettings()
                } label: { Label(ZLQuickActions.settings, systemImage: "gearshape") }

                Button {
                    ZLHaptic.light()
                    onFileManager()
                } label: { Label(ZLQuickActions.files, systemImage: "folder") }

                Button {
                    let id = selectedVersion.components(separatedBy: " ").first ?? selectedVersion
                    ZLClipboard.copy(id, label: "版本 ID")
                } label: { Label(ZLQuickActions.copyID, systemImage: "doc.on.doc") }
            }

            // 启动
            // 没装版本时禁用，避免点了必然失败
            ZLGoldButton(title: hasInstalledVersion ? "启动游戏" : "先去下载版本",
                         icon: hasInstalledVersion ? "play.fill" : "arrow.down.circle",
                         enabled: hasInstalledVersion) {
                guard hasInstalledVersion else { return }
                launching = true
            }
            .breathingGlow(hasInstalledVersion ? ZLTheme.primary : ZLTheme.textSecond)
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

    /// 从已安装版本里选一个作为首页显示/启动用的版本
    /// 是否真的装了版本（首页显示名不是占位文案）
    private var hasInstalledVersion: Bool {
        !selectedVersion.isEmpty && !selectedVersion.hasPrefix("还没有")
    }

    private func refreshInstalledVersion() {
        let list = VersionRepository.shared.listVersions()
        guard !list.isEmpty else {
            selectedVersion = "还没有安装版本"
            return
        }
        // 已有选中且仍然存在，就保留
        if !selectedVersion.isEmpty,
           list.contains(where: { selectedVersion == $0.id }) {
            return
        }
        // 否则取第一个（列表已按修改时间排序）
        selectedVersion = list[0].id
    }
}
