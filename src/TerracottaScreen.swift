// ZL2-iOS · 陶瓦联机（Terracotta）
// 参考：ZL2 的 TerracottaAndroidAPI.java
// 说明：原生核心是预编译 .so（7.7MB），此处实现房间码校验与流程状态机
import SwiftUI

// MARK: - 房间类型（对齐 RoomType）
enum ZLRoomType: String, CaseIterable {
    case terracottaLegacy = "陶瓦经典"
    case pcl2ce = "PCL2 联机"
    case scaffolding = "脚手架"
}

// MARK: - 房间码解析
enum ZLRoomCode {
    /// 校验房间码，返回类型（nil = 无效）
    static func parse(_ code: String) -> ZLRoomType? {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !t.isEmpty else { return nil }

        // 陶瓦经典：4 组 4 位十六进制，中间用 - 分隔（共 19 字符）
        // 例：A1B2-C3D4-E5F6-7890
        if matchesTerracotta(t) { return .terracottaLegacy }

        // PCL2 联机：以数字开头的 6-8 位
        if matchesPCL2(t) { return .pcl2ce }

        // 脚手架：包含字母数字混合，长度 8-32
        if matchesScaffolding(t) { return .scaffolding }

        return nil
    }

    /// 陶瓦经典格式
    private static func matchesTerracotta(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { p in
            p.count == 4 && p.allSatisfy { $0.isHexDigit }
        }
    }

    /// PCL2 联机格式
    private static func matchesPCL2(_ s: String) -> Bool {
        guard s.count >= 6, s.count <= 8 else { return false }
        return s.allSatisfy { $0.isNumber }
    }

    /// 脚手架格式
    private static func matchesScaffolding(_ s: String) -> Bool {
        guard s.count >= 8, s.count <= 32 else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// 规范化（去掉空格和多余分隔符）
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

// MARK: - 联机状态（对齐 getState）
enum ZLTerracottaState: String {
    case waiting = "等待中"
    case scanning = "正在创建房间"
    case guesting = "正在加入"
    case hosting = "房间已创建"
    case guestingConnected = "已加入房间"
    case error = "出错"
}

// MARK: - 联机主页面
struct TerracottaScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var tab = 0                 // 0 联机 1 用户须知 2 房主教程 3 房客教程
    @State private var enabled = false
    @State private var roomInput = ""
    @State private var playerName = ""
    @State private var state: ZLTerracottaState = .waiting
    @State private var roomType: ZLRoomType?
    @State private var myRoomCode = ""
    @State private var showLog = false
    @State private var logs: [String] = []
    @State private var ticker: Timer?

    private let tabs = ["联机", "用户须知", "房主教程", "房客教程"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "Terracotta | 陶瓦联机", active: .multiplayer,
                     onBack: onBack, onHome: onHome)

            // 标签
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button { tab = i } label: {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: tab == i ? .semibold : .regular))
                            .foregroundStyle(tab == i ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(tab == i ? ZLTheme.primarySoft : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 12) {
                    switch tab {
                    case 0: connectTab
                    case 1: noticeTab
                    case 2: hostTutorialTab
                    default: guestTutorialTab
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { startTicker() }
        .onDisappear { ticker?.invalidate() }
        .sheet(isPresented: $showLog) { logSheet }
    }

    // MARK: 联机标签
    private var connectTab: some View {
        VStack(spacing: 12) {
            // 启用开关
            ZLCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用多人联机").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("通过 P2P 虚拟局域网与其他玩家连接").font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Toggle("", isOn: $enabled).labelsHidden().tint(ZLTheme.primary)
                }
            }

            if enabled {
                // 状态
                ZLCard {
                    HStack(spacing: 10) {
                        Circle().fill(stateColor).frame(width: 8, height: 8)
                        Text(state.rawValue).font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Spacer()
                        if case .hosting = state, !myRoomCode.isEmpty {
                            Text(myRoomCode)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ZLTheme.primaryDeep)
                            Button {
                                UIPasteboard.general.string = myRoomCode
                            } label: {
                                Image(systemName: "doc.on.doc").font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.primaryDeep)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 昵称
                ZLCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("玩家昵称").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        TextField("用于在游戏中显示的名字", text: $playerName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, 10).frame(height: 36)
                            .background(ZLTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }

                // 房间码输入
                ZLCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("房间码").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        HStack(spacing: 8) {
                            TextField("输入房间码加入，或留空创建", text: $roomInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .autocapitalization(.allCharacters)
                                .padding(.horizontal, 10).frame(height: 38)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .onChange(of: roomInput) { v in
                                    roomType = ZLRoomCode.parse(v)
                                }
                        }
                        if !roomInput.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: roomType != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(roomType != nil ? ZLTheme.success : ZLTheme.danger)
                                Text(roomType?.rawValue ?? "无效的房间码")
                                    .font(.system(size: 10))
                                    .foregroundStyle(roomType != nil ? ZLTheme.success : ZLTheme.danger)
                            }
                        }
                    }
                }

                // 操作
                HStack(spacing: 10) {
                    Button { createRoom() } label: {
                        Text("创建房间")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.textOnGold)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button { joinRoom() } label: {
                        Text("加入房间")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(ZLTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(roomInput.isEmpty || roomType == nil)
                }

                // 辅助
                HStack(spacing: 10) {
                    Button { showLog = true } label: {
                        Label("联机日志", systemImage: "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(ZLTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIApplication.shared.open(URL(string: "https://easytier.cn/")!)
                    } label: {
                        Label("关于 EasyTier", systemImage: "questionmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(ZLTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stateColor: Color {
        switch state {
        case .waiting: return ZLTheme.textSecond
        case .scanning, .guesting: return ZLTheme.warning
        case .hosting, .guestingConnected: return ZLTheme.success
        case .error: return ZLTheme.danger
        }
    }

    // MARK: 教程标签
    private var noticeTab: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("用户须知").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(defaultNotice)
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    private var hostTutorialTab: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("房主使用说明").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("1. 确保已开启多人联机开关\n2. 点击「创建房间」\n3. 把生成的房间码发给朋友\n4. 在游戏内对局域网开放世界\n5. 朋友输入房间码即可加入")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    private var guestTutorialTab: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("房客使用说明").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("1. 确保已开启多人联机开关\n2. 在「房间码」输入房主给你的码\n3. 点击「加入房间」\n4. 打开游戏 → 多人游戏\n5. 在局域网列表里找到房主的房间")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    private var defaultNotice: String {
        """
        在启动器内启用并开启虚拟局域网功能后，启动游戏进入存档，在游戏内对局域网开放，即可将游戏房间共享给其他玩家，玩家加入后即可连接至房主的世界。
        """
    }

    // MARK: 日志
    private var logSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if logs.isEmpty {
                        Text("暂无日志").font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    ForEach(logs.indices, id: \.self) { i in
                        Text(logs[i])
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .navigationTitle("联机日志")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { showLog = false }
                }
            }
        }
    }

    // MARK: 动作（占位实现，原生核心需 .so）
    private func createRoom() {
        state = .scanning
        addLog("正在创建房间…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            myRoomCode = Self.generateRoomCode()
            state = .hosting
            addLog("房间已创建：\(myRoomCode)")
            addLog("提示：原生 P2P 核心（libterracotta.so）尚未接入 iOS，此为界面演示")
        }
    }

    private func joinRoom() {
        guard let type = roomType else { return }
        state = .guesting
        addLog("正在加入房间（\(type.rawValue)）：\(roomInput)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            state = .guestingConnected
            addLog("已连接")
            addLog("提示：原生 P2P 核心尚未接入 iOS，此为界面演示")
        }
    }

    private func addLog(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logs.append("[\(f.string(from: Date()))] \(s)")
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            // 轮询状态（原生核心接入后改为真实查询）
        }
    }

    private static func generateRoomCode() -> String {
        let chars = "0123456789ABCDEF"
        var parts: [String] = []
        for _ in 0..<4 {
            var s = ""
            for _ in 0..<4 { s.append(chars.randomElement()!) }
            parts.append(s)
        }
        return parts.joined(separator: "-")
    }
}
