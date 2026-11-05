// ZL2-iOS · 微软账号登录界面
// 设备码流程：显示 code → 用户去网页确认 → 轮询 → 登录成功
import SwiftUI
import UIKit

struct MicrosoftLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var info: DeviceCodeInfo?
    @State private var status = ""
    @State private var running = false
    @State private var errorText: String?
    @State private var profile: MinecraftProfile?
    @State private var saved = false

    var onSuccess: (Account) -> Void = { _ in }

    private let auth = MicrosoftAuth()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("微软账号登录").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 34, height: 34)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(ZLTheme.screenPadding)

            ScrollView {
                VStack(spacing: 14) {
                    if let p = profile {
                        successCard(p)
                    } else if let info {
                        codeCard(info)
                    } else {
                        introCard
                    }

                    if let e = errorText {
                        ZLCard {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(ZLTheme.danger)
                                Text(e).font(.system(size: 12))
                                    .foregroundStyle(ZLTheme.textPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
            }

            VStack(spacing: 10) {
                if profile == nil {
                    ZLGoldButton(title: running ? (status.isEmpty ? "等待中…" : status) : "开始登录",
                                 icon: running ? "clock" : "person.badge.key",
                                 enabled: !running) {
                        Task { await start() }
                    }
                } else {
                    ZLGoldButton(title: saved ? "完成" : "保存并使用", icon: "checkmark") {
                        if let p = profile, let acc = pendingAccount {
                            onSuccess(acc)
                            saved = true
                            dismiss()
                        }
                    }
                }
                Text("登录过程在浏览器完成，启动器只保存令牌，不接触你的密码。")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    .multilineTextAlignment(.center)
            }
            .padding(ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
    }

    @State private var pendingAccount: Account?

    private var introCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("登录流程").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                stepRow("1", "点击「开始登录」，启动器获取设备码")
                stepRow("2", "复制设备码，在浏览器打开 microsoft.com/link")
                stepRow("3", "输入设备码并完成微软账号登录")
                stepRow("4", "回到这里，会自动完成 Minecraft 验证")
            }
        }
    }

    private func stepRow(_ n: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(n).font(.system(size: 10, weight: .bold))
                .foregroundStyle(ZLTheme.textOnGold)
                .frame(width: 18, height: 18)
                .background(ZLTheme.primary)
                .clipShape(Circle())
            Text(t).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func codeCard(_ info: DeviceCodeInfo) -> some View {
        ZLCard {
            VStack(spacing: 12) {
                Text("设备码").font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                Text(info.userCode)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .tracking(3)
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = info.userCode
                        status = "已复制"
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(ZLTheme.primaryDeep)
                            .padding(.horizontal, 16).frame(height: 38)
                            .background(ZLTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: info.verificationUri) ?? URL(string: "https://microsoft.com/link")!) {
                        Label("打开网页", systemImage: "safari")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 38)
                            .background(ZLTheme.primary)
                            .clipShape(Capsule())
                    }
                }
                if running {
                    HStack(spacing: 8) {
                        ProgressView().tint(ZLTheme.primary)
                        Text(status.isEmpty ? "等待网页确认…" : status)
                            .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func successCard(_ p: MinecraftProfile) -> some View {
        ZLCard {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40)).foregroundStyle(ZLTheme.success)
                Text("登录成功").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(p.name).font(.system(size: 15)).foregroundStyle(ZLTheme.primaryDeep)
                Text("UUID：\(p.id)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ZLTheme.textSecond)
                HStack(spacing: 6) {
                    Text("皮肤 \(p.skins.count)").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                    Text("披风 \(p.capes.count)").font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func start() async {
        running = true
        errorText = nil
        status = ""
        do {
            let result = try await auth.signIn { info in
                Task { @MainActor in self.info = info }
            } onWaiting: {
                Task { @MainActor in
                    if status != "已复制" { status = "等待网页确认…" }
                }
            }
            await MainActor.run {
                self.profile = result.profile
                self.pendingAccount = result.account
                self.running = false
                self.status = ""
            }
        } catch {
            await MainActor.run {
                self.errorText = ZLFriendlyError.text(error)
                self.running = false
            }
        }
    }
}
