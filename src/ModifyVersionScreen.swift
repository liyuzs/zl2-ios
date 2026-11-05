// ZL2-iOS · 修改版本
// 参考：ZL2 的 ModifyVersionScreen.kt（847 行）
// 功能：改名、切换 Minecraft 版本、换加载器、变更预览
import SwiftUI

struct ModifyVersionScreen: View {
    var versionID: String
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onDone: () -> Void = {}

    @State private var newName: String = ""
    @State private var originalMC: String = ""
    @State private var selectedMC: String? = nil
    @State private var originalLoader: String = ""
    @State private var selectedLoader: String = ""
    @State private var showMCList = false
    @State private var showLoaderList = false
    @State private var mcVersions: [String] = []
    @State private var loading = false
    @State private var working = false
    @State private var resultText: String?
    @State private var showResult = false

    private let loaders = ["原版", "Fabric", "Forge", "NeoForge", "Quilt"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "修改版本", onBack: onBack, onHome: onHome)

            ScrollView {
                VStack(spacing: 12) {
                    // 名称
                    ZLCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("版本名称").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            TextField("输入新名称", text: $newName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(.horizontal, 10).frame(height: 38)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            Text("此处可修改该版本的名称").font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }

                    // Minecraft 版本
                    ZLCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Minecraft 版本").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer()
                                Text(selectedMC ?? originalMC)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ZLTheme.primaryDeep)
                                Button { showMCList = true } label: {
                                    Image(systemName: "chevron.right").font(.system(size: 11))
                                        .foregroundStyle(ZLTheme.textSecond)
                                }
                                .buttonStyle(.plain)
                            }
                            if selectedMC != nil && selectedMC != originalMC {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ZLTheme.warning)
                                    Text("部分加载器可能并不支持该版本，可为新版本重新选择加载器。")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ZLTheme.textSecond)
                                }
                            }
                        }
                    }

                    // 加载器
                    ZLCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("模组加载器").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Spacer()
                                Menu {
                                    ForEach(loaders, id: \.self) { l in
                                        Button(l) { selectedLoader = l }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedLoader.isEmpty ? originalLoader : selectedLoader)
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: "chevron.down").font(.system(size: 9))
                                    }
                                    .foregroundStyle(ZLTheme.primaryDeep)
                                }
                            }
                        }
                    }

                    // 变更预览
                    if hasChanges {
                        ZLCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("将为该版本应用以下变更：")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                if !newName.isEmpty && newName != versionID {
                                    changeRow("重命名", "\(versionID) → \(newName)", "pencil")
                                }
                                if let m = selectedMC, m != originalMC {
                                    changeRow("Minecraft", "\(originalMC) → \(m)", "cube")
                                }
                                if !selectedLoader.isEmpty && selectedLoader != originalLoader {
                                    changeRow("加载器", "\(originalLoader) → \(selectedLoader)", "puzzlepiece")
                                }
                            }
                        }
                    }

                    Button { applyChanges() } label: {
                        HStack(spacing: 6) {
                            if working { ProgressView().tint(ZLTheme.textOnGold) }
                            Text(working ? "修改中…" : "开始修改")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(hasChanges ? ZLTheme.primary : ZLTheme.textSecond.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChanges || working)
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadVersionInfo() }
        .sheet(isPresented: $showMCList) {
            MCVersionPicker(versions: mcVersions, current: selectedMC ?? originalMC) { v in
                selectedMC = v
                showMCList = false
            }
        }
        .alert("修改结果", isPresented: $showResult) {
            Button("好", role: .cancel) { }
        } message: {
            Text(resultText ?? "")
        }
    }

    private var hasChanges: Bool {
        let nameChanged = !newName.isEmpty && newName != versionID
        let mcChanged = selectedMC != nil && selectedMC != originalMC
        let loaderChanged = !selectedLoader.isEmpty && selectedLoader != originalLoader
        return nameChanged || mcChanged || loaderChanged
    }

    private func changeRow(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12))
                .foregroundStyle(ZLTheme.primary).frame(width: 20)
            Text(title).font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary).frame(width: 80, alignment: .leading)
            Text(detail).font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond).lineLimit(1)
            Spacer()
        }
    }

    // MARK: 数据
    private func loadVersionInfo() async {
        let jsonURL = VersionRepository.shared.versionsDir
            .appendingPathComponent("\(versionID)/\(versionID).json")
        if let d = try? Data(contentsOf: jsonURL),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            // MC 版本可能在 id 或 inheritsFrom
            originalMC = (o["inheritsFrom"] as? String) ?? versionID
            if let mc = o["id"] as? String { originalMC = mc }
            // 加载器判断
            let mainClass = (o["mainClass"] as? String) ?? ""
            if mainClass.contains("fabric") { originalLoader = "Fabric" }
            else if mainClass.contains("neoforge") { originalLoader = "NeoForge" }
            else if mainClass.contains("forge") { originalLoader = "Forge" }
            else if mainClass.contains("quilt") { originalLoader = "Quilt" }
            else { originalLoader = "原版" }
        }

        // 拉取 MC 版本列表
        loading = true
        do {
            let api = MojangAPI()
            let manifest = try await api.fetchManifest()
            mcVersions = manifest.versions.map { $0.id }
        } catch {
            mcVersions = []
        }
        loading = false
    }

    private func applyChanges() {
        working = true
        Task {
            var messages: [String] = []
            do {
                if !newName.isEmpty && newName != versionID {
                    try VersionRepository.shared.renameVersion(versionID, to: newName)
                    messages.append("已重命名为 \(newName)")
                }
                if let m = selectedMC, m != originalMC {
                    messages.append("Minecraft 版本将改为 \(m)（需重新下载资源）")
                }
                if !selectedLoader.isEmpty && selectedLoader != originalLoader {
                    messages.append("加载器将改为 \(selectedLoader)（需安装）")
                }
                messages.append("提示：完整切换需要重新下载核心文件，请在下载中心操作。")
                resultText = messages.joined(separator: "\n")
            } catch {
                resultText = "修改版本时发生错误：\(ZLFriendlyError.text(error))"
            }
            working = false
            showResult = true
        }
    }
}

// MARK: - MC 版本选择器
struct MCVersionPicker: View {
    let versions: [String]
    let current: String
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if versions.isEmpty {
                    ProgressView("加载版本列表…")
                } else {
                    List {
                        ForEach(filtered, id: \.self) { v in
                            Button {
                                onPick(v)
                            } label: {
                                HStack {
                                    Text(v).font(.system(size: 14))
                                    Spacer()
                                    if v == current {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(ZLTheme.primary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .searchable(text: $search, prompt: "搜索版本")
                }
            }
            .navigationTitle("选择 Minecraft 版本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var filtered: [String] {
        guard !search.isEmpty else { return versions }
        return versions.filter { $0.localizedCaseInsensitiveContains(search) }
    }
}
