// ZL2-iOS · 皮肤与披风
// 使用 MicrosoftAuth 的皮肤上传与披风切换 API
import SwiftUI
import PhotosUI

struct SkinCapeScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var profile: MinecraftProfile?
    @State private var loading = true
    @State private var errorText: String?
    @State private var variant = "classic"        // classic 粗臂 / slim 细臂
    @State private var pickerItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var message: String?
    @State private var selectedCape: String?

    private var token: String? { AccountStore.shared.current?.accessToken }
    private var isMicrosoft: Bool { AccountStore.shared.current?.type == .microsoft }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "皮肤与披风", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    if !isMicrosoft {
                        needLoginCard
                    } else if loading {
                        ProgressView().tint(ZLTheme.primary).padding(.top, 60)
                    } else if let p = profile {
                        skinCard(p)
                        variantCard
                        capeCard(p)
                        if let m = message {
                            Text(m).font(.system(size: 12))
                                .foregroundStyle(ZLTheme.success)
                        }
                        if let e = errorText {
                            Text(e).font(.system(size: 12))
                                .foregroundStyle(ZLTheme.danger)
                        }
                    } else {
                        errorCard
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var needLoginCard: some View {
        ZLCard {
            VStack(spacing: 8) {
                Image(systemName: "person.badge.key")
                    .font(.system(size: 32)).foregroundStyle(ZLTheme.textSecond)
                Text("需要微软正版账号").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("皮肤和披风保存在 Mojang 服务器，只有登录正版账号才能修改。")
                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func skinCard(_ p: MinecraftProfile) -> some View {
        ZLCard {
            VStack(spacing: 12) {
                Text("当前皮肤").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let skin = p.skins.first(where: { $0.state == "ACTIVE" }) ?? p.skins.first {
                    AsyncImage(url: skin.url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:
                            RoundedRectangle(cornerRadius: 10).fill(ZLTheme.primarySoft)
                                .frame(height: 120)
                                .overlay(ProgressView().tint(ZLTheme.primary))
                        }
                    }
                    .frame(maxHeight: 180)
                    Text(skin.variant == "slim" ? "细臂（Alex）" : "粗臂（Steve）")
                        .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(uploading ? "上传中…" : "更换皮肤", systemImage: "photo.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                }
                .disabled(uploading)

                Text("皮肤图片必须是 64×64 的 PNG")
                    .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
            }
        }
        .onChange(of: pickerItem) { _ in
            Task { await upload() }
        }
    }

    private var variantCard: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("手臂样式").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Picker("", selection: $variant) {
                    Text("粗臂").tag("classic")
                    Text("细臂").tag("slim")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func capeCard(_ p: MinecraftProfile) -> some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("披风").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)

                if p.capes.isEmpty {
                    Text("该账号没有可用披风").font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                } else {
                    ForEach(p.capes, id: \.id) { cape in
                        Button {
                            Task { await applyCape(cape.id) }
                        } label: {
                            HStack(spacing: 10) {
                                AsyncImage(url: cape.url) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFit()
                                    } else {
                                        Rectangle().fill(ZLTheme.primarySoft)
                                    }
                                }
                                .frame(width: 56, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text(cape.alias.isEmpty ? cape.id : cape.alias)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer()
                                Image(systemName: cape.state == "ACTIVE" ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(cape.state == "ACTIVE" ? ZLTheme.success : ZLTheme.textSecond)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Task { await applyCape("") }
                    } label: {
                        Text("移除披风").font(.system(size: 12))
                            .foregroundStyle(ZLTheme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var errorCard: some View {
        ZLCard {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ZLTheme.warning)
                Text(errorText ?? "无法获取档案").font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textSecond)
                Button("重试") { Task { await load() } }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.primaryDeep)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: 逻辑
    private func load() async {
        guard isMicrosoft, let tk = token else { loading = false; return }
        loading = true
        do {
            profile = try await MicrosoftAuth().fetchProfile(mcToken: tk)
            if let s = profile?.skins.first(where: { $0.state == "ACTIVE" }) {
                variant = s.variant
            }
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
        loading = false
    }

    private func upload() async {
        guard let item = pickerItem, let tk = token else { return }
        uploading = true
        message = nil
        errorText = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw MSAuthError.invalidResponse("无法读取图片")
            }
            try await MicrosoftAuth().uploadSkin(mcToken: tk, pngData: data, variant: variant)
            message = "皮肤上传成功，稍等片刻后刷新可见"
            profile = try await MicrosoftAuth().fetchProfile(mcToken: tk)
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
        uploading = false
        pickerItem = nil
    }

    private func applyCape(_ id: String) async {
        guard let tk = token else { return }
        do {
            try await MicrosoftAuth().setCape(mcToken: tk, capeID: id)
            message = id.isEmpty ? "已移除披风" : "已切换披风"
            profile = try await MicrosoftAuth().fetchProfile(mcToken: tk)
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
    }
}
