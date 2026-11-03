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

    private var accountCards: some View {
        VStack(spacing: 10) {
            HStack {
                Text("账号列表").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Button { showAddAccount = true } label: {
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
        .sheet(isPresented: $showAddAccount) {
            addAccountSheet
        }
        .sheet(isPresented: $showLocalLogin) {
            LocalLoginSheet { name, _ in
                _ = try? AccountStore.shared.addOffline(name: name)
            }
        }
        .sheet(isPresented: $showAuthlibLogin) {
            AuthlibLoginSheet { server, email, _ in
                // 外置认证：先按离线创建，后续补 Yggdrasil 验证
                _ = try? AccountStore.shared.addOffline(name: email)
                UserDefaults.standard.set(server, forKey: "zl.authlib.server")
            }
        }
    }

    private var addAccountSheet: some View {
        VStack(spacing: 14) {
            Text("添加账号").font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Button { showAddAccount = false; accountType = "microsoft" } label: {
                    addRow("微软账号", "person.badge.key", "登录正版账号")
                }
                .buttonStyle(.plain)
                Button { showAddAccount = false; showLocalLogin = true } label: {
                    addRow("离线账号", "person.fill", "指定用户名与皮肤")
                }
                .buttonStyle(.plain)
                Button { showAddAccount = false; showAuthlibLogin = true } label: {
                    addRow("认证服务器", "server.rack", "LittleSkin 等外置认证")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ZLTheme.screenPadding)

            Button { showAddAccount = false } label: {
                Text("关闭").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(ZLTheme.primarySoft)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 20)
        }
        .background(ZLTheme.background)
        .presentationDetents([.medium])
    }

    private func addRow(_ title: String, _ icon: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16))
                .foregroundStyle(ZLTheme.primary)
                .frame(width: 40, height: 40)
                .background(ZLTheme.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(desc).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    alertText = error.localizedDescription
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
            if type == "microsoft" {
                alertText = "微软登录需要接入 OAuth，核心接入后再开放"
                showAlert = true
            } else {
                accountType = type
            }
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
