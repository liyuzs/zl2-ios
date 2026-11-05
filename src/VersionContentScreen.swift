// ZL2-iOS · 版本内容管理
// 依据真机：一个版本下的 模组 / 资源包 / 存档 / 截图 / 服务器 / 光影
import SwiftUI

enum VersionContentKind: String, CaseIterable, Identifiable {
    case overview  = "概览"
    case mods      = "模组"
    case resources = "资源包"
    case saves     = "存档"
    case screens   = "截图"
    case servers   = "服务器"
    case shaders   = "光影"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview:  return "square.grid.2x2.fill"
        case .mods:      return "puzzlepiece.fill"
        case .resources: return "paintbrush.fill"
        case .saves:     return "folder.fill"
        case .screens:   return "photo.fill"
        case .servers:   return "server.rack"
        case .shaders:   return "sun.max.fill"
        }
    }
}

struct VersionContentScreen: View {
    var versionName: String = ""   // 由调用方传真实版本 ID
    var initial: VersionContentKind = .overview
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    /// 跳转到真实管理页（模组/存档/资源包管理）
    var onOpen: (AppRoute) -> Void = { _ in }

    @State private var kind: VersionContentKind = .overview
    @State private var enabledMods: Set<String> = ["JEI", "JourneyMap", "Waystones"]
    @State private var installed: [VersionRepository.InstalledVersion] = []
    @State private var actionVersion = ""
    @State private var showActions = false
    @State private var alertText = ""
    @State private var showAlert = false
    @State private var showFolder = false
    @State private var folderURL: URL?
    // 文件导入
    @State private var importing = false
    @State private var importTarget: String = "mods"
    @State private var importToast: String?
    @State private var showLog = false
    // 这两个是第 10 轮加 A4 时漏声明的（body 里用了但没定义）
    @State private var showExport = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "\(versionName) - \(kind.rawValue)",
                     onBack: onBack, onHome: onHome)

            HStack(alignment: .top, spacing: 0) {
                rail
                ScrollView {
                    VStack(spacing: ZLTheme.cardGap) {
                        content
                    }
                    .padding(.trailing, ZLTheme.screenPadding)
                    .padding(.bottom, ZLTheme.screenPadding)
                }
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showExport) {
            ExportPackScreen(onBack: { showExport = false }, onHome: { showExport = false })
        }
        .alert("删除版本", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                do {
                    try VersionRepository.shared.deleteVersion(versionName)
                    ZLHaptic.success()
                    onBack()
                } catch {
                    alertText = ZLFriendlyError.text(error)
                    showAlert = true
                }
            }
        } message: {
            Text("会删除 \(versionName) 的整个版本目录，不可恢复。")
        }
        .sheet(isPresented: $showFolder) {
            if let u = folderURL {
                FileManagerScreen(onBack: { showFolder = false },
                                  onHome: { showFolder = false },
                                  initialPath: u)
            }
        }
        .onAppear {
            kind = initial
            installed = VersionRepository.shared.listVersions()
        }
        .alert(alertText, isPresented: $showAlert) { Button("好", role: .cancel) { } }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { handleImport(urls) }
        }
        .overlay(alignment: .bottom) {
            if let importToast {
                Text(importToast)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showLog) {
            LogViewScreen(onBack: { showLog = false }, onHome: { showLog = false })
        }
        .sheet(isPresented: $showActions) {
            VersionActionSheet(versionName: actionVersion,
                               isPresented: $showActions,
                               onCopy: {
                                   let n = "\(actionVersion)-副本"
                                   do {
                                       try VersionRepository.shared.copyVersion(actionVersion, to: n)
                                       alertText = "已复制为 \(n)"
                                   } catch { alertText = ZLFriendlyError.text(error) }
                                   showAlert = true
                                   installed = VersionRepository.shared.listVersions()
                               },
                               onRename: {
                                   installed = VersionRepository.shared.listVersions()
                               },
                               onDelete: {
                                   do {
                                       try VersionRepository.shared.deleteVersion(actionVersion)
                                       alertText = "已删除 \(actionVersion)"
                                   } catch { alertText = ZLFriendlyError.text(error) }
                                   showAlert = true
                                   installed = VersionRepository.shared.listVersions()
                               })
        }
    }

    private var rail: some View {
        VStack(spacing: 6) {
            ForEach(VersionContentKind.allCases) { k in
                Button { kind = k } label: {
                    VStack(spacing: 4) {
                        Image(systemName: k.icon).font(.system(size: 18))
                        Text(k.rawValue).font(.system(size: 11))
                    }
                    .foregroundStyle(kind == k ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .frame(width: 74, height: 60)
                    .background(kind == k ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .frame(width: 90)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .overview:  overview
        case .mods:
            VStack(spacing: 12) {
                realPageHint("模组管理", icon: "puzzlepiece.fill") {
                    onOpen(.modsManager(versionName))
                }
                modList
            }
        case .resources:
            VStack(spacing: 12) {
                realPageHint("资源包管理", icon: "paintbrush.fill") {
                    onOpen(.resourceManager(versionName, 0))
                }
                fileList("资源包", ["Programmer Art", "VM 汉化资源包", "Mod Resources"], "zip")
            }
        case .saves:
            VStack(spacing: 12) {
                realPageHint("存档管理", icon: "folder.fill") {
                    onOpen(.savesManager(versionName))
                }
                fileList("存档", ["新的世界", "Silent Hills", "创造测试"], "folder")
            }
        case .screens:   screenshotGrid
        case .servers:   serverList
        case .shaders:   shaderList
        }
    }

    // MARK: 概览（真机结构：图标 + 版本管理 + 快捷操作）
    private var overview: some View {
        VStack(spacing: ZLTheme.cardGap) {
            // 自定义图标 + 版本名（视觉重点，开扫光 + 倾斜高光）
            ZLCard(sheen: true) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "cube.fill")
                            .font(.system(size: 28)).foregroundStyle(ZLTheme.primary))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(versionName).font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Button { } label: {
                            Text("自定义图标").font(.system(size: 12))
                                .foregroundStyle(ZLTheme.primaryDeep)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            // 版本管理
            ZLCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("版本管理").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    manageRow("重命名版本", "pencil") {
                        actionVersion = versionName
                        showActions = true
                    }
                    manageRow("导出整合包", "square.and.arrow.up") {
                        showExport = true
                    }
                    manageRow("运行日志", "doc.text") { showLog = true }
                    manageRow("删除版本", "trash", danger: true) {
                        actionVersion = versionName
                        showDeleteConfirm = true
                    }
                }
            }

            // 快捷操作：8 个文件夹
            ZLCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("快捷操作").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    let cols = [GridItem(.adaptive(minimum: 92), spacing: 8)]
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(folderItems, id: \.0) { name, icon in
                            Button { openFolder(name) } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: icon).font(.system(size: 17))
                                        .foregroundStyle(ZLTheme.primary)
                                    Text(name).font(.system(size: 10))
                                        .foregroundStyle(ZLTheme.textSecond)
                                }
                                .frame(maxWidth: .infinity).frame(height: 62)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var folderItems: [(String, String)] {
        [("版本文件夹", "cube.box"), ("存档文件夹", "folder"),
         ("资源包文件夹", "paintbrush"), ("光影包文件夹", "sun.max"),
         ("模组文件夹", "puzzlepiece"), ("屏幕截图文件夹", "photo"),
         ("日志文件夹", "doc.text"), ("崩溃报告文件夹", "exclamationmark.triangle")]
    }

    private func manageRow(_ title: String, _ icon: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14))
                    .foregroundStyle(danger ? ZLTheme.danger : ZLTheme.primary)
                    .frame(width: 26)
                Text(title).font(.system(size: 13))
                    .foregroundStyle(danger ? ZLTheme.danger : ZLTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
        .buttonStyle(.plain)
    }

    private func openFolder(_ kind: String) {
        // 原来算出 URL 就直接丢掉了（_ = url），8 个快捷操作全无反应
        guard let url = VersionRepository.shared.folder(
            for: kind.replacingOccurrences(of: "文件夹", with: ""),
            versionID: versionName) else {
            alertText = "这个版本还没有「\(kind)」目录，进一次游戏会自动创建"
            showAlert = true
            return
        }
        folderURL = url
        showFolder = true
    }

    /// 「这里显示的是示例，真实内容在管理页」的入口条
    private func realPageHint(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        ZLCard {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundStyle(ZLTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("下面只是示例").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text("真实内容请在「\(title)」里查看和管理")
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
                Button {
                    ZLHaptic.light()
                    action()
                } label: {
                    Text("打开").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Capsule().fill(ZLTheme.primarySoft))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium)).foregroundStyle(ZLTheme.textPrimary)
        }
    }

    private func quickButton(_ title: String, _ target: VersionContentKind) -> some View {
        Button { kind = target } label: {
            VStack(spacing: 5) {
                Image(systemName: target.icon).font(.system(size: 18))
                    .foregroundStyle(ZLTheme.primary)
                Text(title).font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(ZLTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 模组列表（带开关与前置依赖）
    private var modList: some View {
        VStack(spacing: 10) {
            ForEach(["JEI", "JourneyMap", "Waystones", "AppleSkin", "Dynamic FPS"], id: \.self) { name in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .frame(width: 42, height: 42)
                        .overlay(Image(systemName: "puzzlepiece.fill")
                            .foregroundStyle(ZLTheme.primary))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text(name == "Waystones" ? "前置：Balm" : "forge 1.20.1")
                            .font(.system(size: 11))
                            .foregroundStyle(name == "Waystones" ? ZLTheme.warning : ZLTheme.textSecond)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { enabledMods.contains(name) },
                        set: { on in
                            if on { enabledMods.insert(name) } else { enabledMods.remove(name) }
                        }
                    ))
                    .labelsHidden()
                    .tint(ZLTheme.primary)
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: 通用文件列表
    private func fileList(_ title: String, _ items: [String], _ ext: String) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.self) { name in
                HStack(spacing: 12) {
                    Image(systemName: ext == "zip" ? "doc.zipper" : "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ZLTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text(ext == "zip" ? "资源包 · 点击导入" : "存档文件夹")
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            ZLGoldButton(title: "导入\(title)", icon: "square.and.arrow.down") {
                beginImport(for: title)
            }
        }
    }

    // MARK: 截图网格
    private var screenshotGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 140), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ZLTheme.primarySoft)
                    .frame(height: 90)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "photo").font(.system(size: 20))
                                .foregroundStyle(ZLTheme.primary)
                            Text("截图 \(i + 1)").font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    )
            }
        }
    }

    // MARK: 服务器列表
    private var serverList: some View {
        VStack(spacing: 10) {
            ForEach(["Hypixel", "2b2t", "本地局域网"], id: \.self) { name in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ZLTheme.primarySoft)
                        .frame(width: 42, height: 42)
                        .overlay(Image(systemName: "server.rack")
                            .foregroundStyle(ZLTheme.primary))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text(name == "本地局域网" ? "192.168.x.x:25565" : "play.\(name.lowercased()).net")
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            ZLGoldButton(title: "添加服务器", icon: "plus") {
                alertText = "服务器列表在「多人游戏」页管理，\n在那里可以添加、编辑、测试连通性。"
                showAlert = true
            }
        }
    }

    // MARK: 光影列表
    private var shaderList: some View {
        VStack(spacing: 10) {
            ForEach(["BSL v10.11", "Complementary r5.3", "Chocapic13 Bliss"], id: \.self) { name in
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ZLTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("光影包 · 需 Oculus/Iris 支持")
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            ZLGoldButton(title: "导入光影", icon: "square.and.arrow.down") {
                beginImport(for: "光影")
            }
        }
    }

    // MARK: 文件导入

    /// 根据分组名决定导入到哪个目录
    private func beginImport(for title: String) {
        if title.contains("光影") { importTarget = "shaderpacks" }
        else if title.contains("资源包") { importTarget = "resourcepacks" }
        else { importTarget = "mods" }
        importing = true
    }

    private func handleImport(_ urls: [URL]) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        _ = docs
        let dir = VersionRepository.shared.mcRoot.appendingPathComponent(importTarget, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var ok = 0
        for src in urls {
            let dst = dir.appendingPathComponent(src.lastPathComponent)
            // 需要先取得安全访问权限（别的 App 目录里的文件）
            let scoped = src.startAccessingSecurityScopedResource()
            defer { if scoped { src.stopAccessingSecurityScopedResource() } }
            if (try? fm.copyItem(at: src, to: dst)) != nil { ok += 1 }
        }
        importToast = ok > 0 ? "已导入 \(ok) 个文件" : "导入失败"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { importToast = nil }
    }
}
