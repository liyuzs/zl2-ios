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
    @State private var alertText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                current
                section("登录方式") {
                    methodRow("微软账号", "person.badge.key", "microsoft")
                    methodRow("离线账号", "person.fill", "offline")
                    methodRow("外置认证", "server.rack", "authlib")
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
