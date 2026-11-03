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

    private let tabs = ["用户须知", "房主教程", "房客教程"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "Terracotta | 陶瓦联机", active: .multiplayer,
                     onBack: onBack, onHome: onHome)

            // 左右分栏（真机：左教程 / 右操作）
            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                // 左栏：教程
                VStack(spacing: 0) {
                    // 标签栏（下划线选中）
                    HStack(spacing: 0) {
                        ForEach(tabs.indices, id: \.self) { i in
                            Button { tab = i } label: {
                                VStack(spacing: 4) {
                                    Text(tabs[i])
                                        .font(.system(size: 12, weight: tab == i ? .semibold : .regular))
                                        .foregroundStyle(tab == i ? ZLTheme.textPrimary : ZLTheme.textSecond)
                                    Rectangle()
                                        .fill(tab == i ? ZLTheme.primary : Color.clear)
                                        .frame(height: 2)
                                }
                                .frame(maxWidth: .infinity).frame(height: 40)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider().background(ZLTheme.cardStroke)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(tabs[tab])
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text(tutorialText)
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // 右栏：操作
                VStack(spacing: 0) {
                    // 启用开关
                    HStack {
                        Text("启用多人联机").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $enabled).labelsHidden().tint(ZLTheme.primary)
                    }
                    .padding(14)

                    Divider().background(ZLTheme.cardStroke)

                    // 分享日志
                    Button { showLog = true } label: {
                        HStack {
                            Text("分享联机核心日志").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)

                    Divider().background(ZLTheme.cardStroke)

                    // 关于
                    Button {
                        UIApplication.shared.open(URL(string: "https://easytier.cn/")!)
                    } label: {
                        HStack {
                            Text("关于 EasyTier").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)

                    // 启用后显示连接区
                    if enabled {
                        Divider().background(ZLTheme.cardStroke)
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Circle().fill(stateColor).frame(width: 7, height: 7)
                                Text(state.rawValue).font(.system(size: 11))
                                    .foregroundStyle(ZLTheme.textSecond)
                                Spacer()
                            }
                            TextField("房间码（留空创建）", text: $roomInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .autocapitalization(.allCharacters)
                                .padding(.horizontal, 10).frame(height: 32)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onChange(of: roomInput) { v in
                                    roomType = ZLRoomCode.parse(v)
                                }
                            HStack(spacing: 8) {
                                Button { createRoom() } label: {
                                    Text("创建").font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ZLTheme.textOnGold)
                                        .frame(maxWidth: .infinity).frame(height: 32)
                                        .background(ZLTheme.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                Button { joinRoom() } label: {
                                    Text("加入").font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ZLTheme.primaryDeep)
                                        .frame(maxWidth: .infinity).frame(height: 32)
                                        .background(ZLTheme.primarySoft)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(roomInput.isEmpty || roomType == nil)
                            }
                            if !myRoomCode.isEmpty {
                                HStack(spacing: 4) {
                                    Text(myRoomCode).font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(ZLTheme.primaryDeep)
                                    Button { UIPasteboard.general.string = myRoomCode } label: {
                                        Image(systemName: "doc.on.doc").font(.system(size: 9))
                                            .foregroundStyle(ZLTheme.primaryDeep)
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                }
                            }
                        }
                        .padding(14)
                    }
                }
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(width: 300)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { startTicker() }
        .onDisappear { ticker?.invalidate() }
        .sheet(isPresented: $showLog) { logSheet }
    }

    // MARK: 联机标签
    private var tutorialText: String {
        switch tab {
        case 0:
            return """
            陶瓦联机是第三方开源自由软件，您在使用过程中所遇到的问题请通过相关渠道进行反馈。
            陶瓦联机使用 P2P 技术，联机成功后房间内用户之间将直接连接，不会使用第三方服务器对您的流量进行转发。最终联机体验和参与联机者的网络情况有较大关系。
            在多人联机全过程中，您必须严格遵守您所在国家 / 地区的全部法律法规。
            """
        case 1:
            return """
            房主使用说明：
            1. 开启「启用多人联机」开关
            2. 点击「创建」按钮，等待生成房间码
            3. 把房间码发给朋友
            4. 进入游戏 → 对局域网开放
            5. 朋友输入房间码加入后即可在局域网列表看到你的世界
            """
        default:
            return """
            房客使用说明：
            1. 开启「启用多人联机」开关
            2. 在房间码输入框填入房主给你的码
            3. 点击「加入」按钮
            4. 等待连接成功后打开游戏
            5. 在多人游戏的局域网列表里找到房主的房间
            """
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
