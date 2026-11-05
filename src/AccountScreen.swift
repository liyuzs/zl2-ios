// ZL2-iOS · 账户页
// 对照 ZL2 的三种登录方式：微软正版 / 离线账号 / 外置认证服务器
import SwiftUI

struct AccountScreen: View {
    @AppStorage("accountType")     private var accountType = "offline"
    @AppStorage("accountName")     private var accountName = "wzw2333"
    @AppStorage("authServerURL")   private var authServerURL = ""

    @State private var draftName = ""
    @State private var draftServer = ""
    @State private var showAlert = false
    @State private var showMSLogin = false
    @State private var alertText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 账号列表（真机：卡片 + 添加按钮）
                accountCards
                current
                section("登录方式") {
                    methodRow("微软账号", "person.badge.key", "microsoft")
                    methodRow("离线账号", "person.fill", "offline")
                    methodRow("外置认证", "server.rack", "authlib")
                }
                if accountType == "microsoft" { microsoftForm }
                if accountType == "microsoft" {
                    NavigationLink(value: AppRoute.skinCape) {
                        HStack {
                            Image(systemName: "person.crop.rectangle")
                                .foregroundStyle(ZLTheme.primary)
                            Text("皮肤与披风").font(.system(size: 14))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                        }
                        .padding(14)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if accountType == "offline" { offlineForm }
                if accountType == "authlib" { authForm }
                hint("离线 ID 只支持大小写字母、数字和下划线；含其他字符时高版本 MC 无法进入游戏。")
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(ZLTheme.surface)
        // 添加账号：ZL2 是盖在页面上的 Dialog，不是 iOS 的底部 Sheet
        .overlay {
            if showAddAccount {
                ZLAddAccountDialog(
                    kind: $addAccountKind,
                    onCancel: cancelAddAccount,
                    onConfirm: confirmAddAccount,
                    onAddAuthServer: openAuthServerFromDialog
                )
                .transition(AnyTransition.opacity)
                .zIndex(2)
            }
        }
        .toolbar(showAddAccount ? Visibility.hidden : Visibility.visible, for: .navigationBar)
        .alert(alertText, isPresented: $showAlert) {
            Button("好", role: .cancel) { }
        }
        .sheet(isPresented: $showMSLogin) {
            MicrosoftLoginView { acc in
                accountName = acc.username
                accountType = "microsoft"
                AccountStore.shared.save(acc)
                AccountStore.shared.select(acc)
                alertText = "已登录微软账号：\(acc.username)"
                showAlert = true
            }
        }
    }

    // MARK: 微软账号
    private var microsoftForm: some View {
        VStack(spacing: 12) {
            ZLCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("微软正版账号").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("登录后可联机、使用正版皮肤与披风。不支持没有购买 Minecraft 的账号。")
                        .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ZLGoldButton(title: "微软登录", icon: "person.badge.key") {
                showMSLogin = true
            }
        }
    }

    // MARK: 账号卡片列表（真机：皮肤预览 + 名字 + 添加账号）
    @State private var showAddAccount = false
    @State private var showLocalLogin = false
    @State private var showAuthlibLogin = false
    @State private var addAccountKind: ZLAddAccountKind = .microsoft
    // 皮肤站登录状态
    @State private var authlibBusy = false
    @State private var authlibError: String?
    @State private var authlibSuccess: String?

    private var accountCards: some View {
        VStack(spacing: 10) {
            HStack {
                Text("账号列表").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Button { openAddAccount() } label: {
                    Label("添加账号", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(AccountStore.shared.accounts) { acc in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .frame(width: 44, height: 44)
                        .overlay(Text(String(acc.username.prefix(1))).font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ZLTheme.primary))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(acc.username).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text(acc.type == .microsoft ? "微软账号" : (acc.type == .authlib ? "外置认证" : "离线账号"))
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    if AccountStore.shared.current?.id == acc.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ZLTheme.success)
                    } else {
                        Button { AccountStore.shared.select(acc) } label: {
                            Text("切换").font(.system(size: 11))
                                .foregroundStyle(ZLTheme.primaryDeep)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if AccountStore.shared.accounts.isEmpty {
                Text("还没有账号，点右上角添加").font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showLocalLogin) {
            LocalLoginSheet { name, uuid in
                addOfflineAccount(named: name, uuid: uuid)
            }
        }
        .overlay(alignment: .top) {
            // 皮肤站登录的进度 / 结果提示
            if authlibBusy || authlibError != nil || authlibSuccess != nil {
                HStack(spacing: 8) {
                    if authlibBusy {
                        ProgressView().scaleEffect(0.7)
                        Text("正在登录皮肤站…")
                    } else if let e = authlibError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(ZLTheme.danger)
                        Text(e).lineLimit(2)
                    } else if let ok = authlibSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ZLTheme.success)
                        Text(ok)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(ZLTheme.surface))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { authlibError = nil; authlibSuccess = nil }
            }
        }
        .sheet(isPresented: $showAuthlibLogin) {
            AuthlibLoginSheet { server, email, password in
                // 真正的 Yggdrasil 认证：登录 → 拿角色名和皮肤
                guard let norm = ZLYggdrasilClient.normalize(server) else {
                    authlibBusy = false
                    authlibError = "皮肤站地址不对"
                    return
                }
                authlibBusy = true
                authlibError = nil
                Task {
                    do {
                        let client = ZLYggdrasilClient(server: norm)
                        let profile = try await client.login(email: email, password: password)

                        // 用皮肤站的角色名创建账号
                        _ = try? AccountStore.shared.addOffline(name: profile.name)
                        UserDefaults.standard.set(norm, forKey: "zl.authlib.server")
                        UserDefaults.standard.set(profile.id, forKey: "zl.authlib.uuid")

                        // 挂上 authlib-injector（让它把皮肤站身份注进游戏）
                        _ = await ZLAuthlibInjector.ensureDownloaded()

                        // 下载皮肤，离线模式也能显示
                        if let skinURL = profile.skinURL {
                            let dir = VersionRepository.shared.mcRoot
                                .appendingPathComponent("custom_skin", isDirectory: true)
                            _ = await ZLYggdrasilClient.downloadSkin(skinURL, to: dir)
                        }

                        await MainActor.run {
                            authlibBusy = false
                            authlibSuccess = "已登录：\(profile.name)"
                        }
                    } catch {
                        await MainActor.run {
                            authlibBusy = false
                            authlibError = ZLFriendlyError.text(error)
                        }
                    }
                }
            }
        }
    }

    // MARK: 添加账号弹窗

    private func openAddAccount() {
        addAccountKind = .microsoft
        withAnimation(.easeOut(duration: 0.16)) { showAddAccount = true }
    }

    private func cancelAddAccount() {
        withAnimation(.easeOut(duration: 0.16)) { showAddAccount = false }
    }

    private func confirmAddAccount() {
        let chosen = addAccountKind
        withAnimation(.easeOut(duration: 0.16)) { showAddAccount = false }
        // 等弹窗淡出后再拉起子流程，避免同一时刻触发两次 presentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch chosen {
            case .microsoft:
                showMSLogin = true
            case .offline:
                showLocalLogin = true
            case .authlib:
                showAuthlibLogin = true
            }
        }
    }

    private func openAuthServerFromDialog() {
        withAnimation(.easeOut(duration: 0.16)) { showAddAccount = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showAuthlibLogin = true
        }
    }

    /// 离线账号：LocalLoginDialog 允许自定义 UUID，这里一并尊重
    private func addOfflineAccount(named name: String, uuid: String?) {
        do {
            let userName = try OfflineAccountFactory.validatedUsername(name)
            let account: Account
            if let uuid, !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let compact = AccountUUID.compact(from: uuid)
                guard compact.count == 32,
                      compact.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil else {
                    alertText = "无效 UUID 格式"
                    showAlert = true
                    return
                }
                account = Account(type: .offline, username: userName, uuid: compact)
            } else {
                account = try OfflineAccountFactory.makeAccount(username: userName)
            }
            AccountStore.shared.save(account)
            accountName = account.username
            accountType = "offline"
        } catch {
            alertText = ZLFriendlyError.text(error)
            showAlert = true
        }
    }

    // MARK: 当前账户
    private var current: some View {
        ZLCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(ZLTheme.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(ZLTheme.primary))
                VStack(alignment: .leading, spacing: 3) {
                    Text(accountName).font(.system(size: 16, weight: .semibold))
                    Text(typeName).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Text("当前")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.success)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(ZLTheme.success.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var typeName: String {
        switch accountType {
        case "microsoft": return "微软正版账号"
        case "authlib":   return "外置认证服务器"
        default:          return "离线账号"
        }
    }

    // MARK: 离线登录
    private var offlineForm: some View {
        section("离线登录") {
            ZLTextField(placeholder: "游戏 ID", text: $draftName)
            ZLPrimaryButton(title: "保存并使用", icon: "checkmark") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { alertText = "ID 不能为空"; showAlert = true; return }
                do {
                    // 走统一账户服务：校验 + 生成离线 UUID + 持久化 + 同步旧键
                    let account = try AccountStore.shared.addOffline(name: name)
                    accountName = account.username
                    accountType = "offline"
                } catch {
                    alertText = ZLFriendlyError.text(error)
                    showAlert = true
                }
            }
        }
    }

    // MARK: 外置认证
    private var authForm: some View {
        section("外置认证") {
            ZLTextField(placeholder: "例如 https://littleskin.cn/api/yggdrasil", text: $draftServer)
            ZLPrimaryButton(title: "验证并保存", icon: "network") {
                let url = draftServer.trimmingCharacters(in: .whitespaces)
                guard url.hasPrefix("http") else { alertText = "地址需以 http(s):// 开头"; showAlert = true; return }
                authServerURL = url
                accountType = "authlib"
            }
            hint("认证服务器地址由皮肤站或服务器官网提供，确认后再返回登录。")
        }
    }

    // MARK: 组件
    private func methodRow(_ title: String, _ icon: String, _ type: String) -> some View {
        Button {
            accountType = type
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(ZLTheme.primary)
                Text(title).font(.system(size: 14)).foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                if accountType == type {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(ZLTheme.success)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZLTheme.textSecond).padding(.leading, 4)
            ZLCard { VStack(alignment: .leading, spacing: 12) { content() } }
        }
    }

    private func hint(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
    }
}

// 通用输入框
struct ZLTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 14))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ZLTheme.cardStroke, lineWidth: 1))
    }
}

// MARK: - 离线登录（对齐 ZL2 的 LocalLoginDialog）
struct LocalLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onLogin: (String, String?) -> Void   // 用户名, UUID
    @State private var userName = ""
    @State private var editUUID = false
    @State private var uuid = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("用户名") {
                    TextField("输入用户名（3-16 字符）", text: $userName)
                        .onChange(of: userName) { _ in error = nil }
                    if let e = error {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
                Section("UUID（可选）") {
                    Toggle("自定义 UUID", isOn: $editUUID)
                    if editUUID {
                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $uuid)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("将根据用户名自动生成离线 UUID")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("登录") {
                        let t = userName.trimmingCharacters(in: .whitespaces)
                        guard t.count >= 3, t.count <= 16 else {
                            error = "用户名长度需在 3-16 字符之间"
                            return
                        }
                        onLogin(t, editUUID && !uuid.isEmpty ? uuid : nil)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("离线登录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 外置服务器登录（对齐 ZL2 的 OtherServerLoginDialog）
struct AuthlibLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onLogin: (String, String, String) -> Void   // 服务器地址, 邮箱, 密码
    @State private var server = "https://littleskin.cn/api/yggdrasil"
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("认证服务器") {
                    TextField("服务器地址", text: $server)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                    Text("支持 LittleSkin、Blessing Skin 等 Yggdrasil 服务")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("账号") {
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("密码", text: $password)
                }
                if let e = error {
                    Section { Text(e).font(.caption).foregroundStyle(.red) }
                }
                Section {
                    Button("登录") {
                        guard !email.isEmpty, !password.isEmpty else {
                            error = "请填写邮箱和密码"
                            return
                        }
                        onLogin(server, email, password)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("外置登录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 添加账号弹窗（ZL2 Dialog 样式，非 iOS Sheet）

enum ZLAddAccountKind: String, CaseIterable, Identifiable {
    case microsoft = "microsoft"
    case offline = "offline"
    case authlib = "authlib"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microsoft: return "Microsoft 账号"
        case .offline:   return "离线账号"
        case .authlib:   return "外置登录"
        }
    }

    var subtitle: String {
        switch self {
        case .microsoft: return "登录正版账号，可玩所有服务器"
        case .offline:   return "不联网，仅本地游玩"
        case .authlib:   return "第三方验证服务器（Authlib）"
        }
    }

    var icon: String {
        switch self {
        case .microsoft: return "person.badge.key.fill"
        case .offline:   return "person.fill"
        case .authlib:   return "network"
        }
    }
}

struct ZLAddAccountDialog: View {
    @Binding var kind: ZLAddAccountKind
    var onCancel: () -> Void
    var onConfirm: () -> Void
    var onAddAuthServer: () -> Void

    var body: some View {
        ZStack {
            // 半透明遮罩（点遮罩关闭）
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                Text("添加账号")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                Text("选择登录方式")
                    .font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.bottom, 16)

                VStack(spacing: 8) {
                    ForEach(ZLAddAccountKind.allCases) { k in
                        Button {
                            kind = k
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: k.icon)
                                    .font(.system(size: 17))
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(k.title).font(.system(size: 14, weight: .medium))
                                    Text(k.subtitle).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                                }
                                Spacer()
                                Image(systemName: kind == k ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(kind == k ? ZLTheme.primaryDeep : ZLTheme.textSecond.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(kind == k ? ZLTheme.primarySoft : ZLTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if kind == .authlib {
                    Button("管理验证服务器", action: onAddAuthServer)
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.top, 10)
                }

                HStack(spacing: 10) {
                    Button("取消", action: onCancel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ZLTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("添加", action: onConfirm)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ZLTheme.primaryDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 340)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 28)
        }
    }
}
