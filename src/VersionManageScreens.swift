// ZL2-iOS · 版本管理补充
// 游戏目录管理 / 清理文件 / 复制重命名 / 三种格式导出
import SwiftUI

// MARK: - 游戏目录管理
// 真实的实例目录管理：每个目录 = <Documents>/instances/<名字>/.minecraft
// 切换后 VersionRepository 会同步切换根目录（版本列表 / 模组 / 存档 / 安装器都跟着走），
// 选择结果持久化，重启 App 仍然是上次的目录。
struct GameDirsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @StateObject private var store = GameDirectoryStore.shared
    @State private var showCreate = false
    @State private var newName = ""
    @State private var renameTarget: ZLGameInstance?
    @State private var renameName = ""
    @State private var deleteTarget: ZLGameInstance?
    @State private var showBrowser = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "游戏目录", onBack: onBack, onHome: onHome)
            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                currentPanel
                    .frame(width: 258)
                listPanel
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.leading, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { store.reload() }
        .alert("新建游戏目录", isPresented: $showCreate) {
            TextField("例如：生存 / 创造 / 1.20.1 模组", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") { createDir() }
        } message: {
            Text("会创建 instances/<名称>/.minecraft，并立即切换过去")
        }
        .alert("重命名目录", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("新名称", text: $renameName)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("确定") { doRename() }
        } message: {
            Text("只改文件夹名，目录里的游戏文件不会移动")
        }
        .alert("删除游戏目录", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) { doDelete() }
        } message: {
            Text("将删除「\(deleteTarget?.id ?? "")」及其中所有版本、模组与存档，无法恢复。")
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("好", role: .cancel) { }
        } message: {
            Text(errorText ?? "")
        }
        .sheet(isPresented: $showBrowser) {
            FileSelectorScreen(startURL: store.instancesRoot,
                               mode: .directory,
                               title: "选择游戏目录",
                               onBack: { showBrowser = false },
                               onHome: { showBrowser = false },
                               onSelect: { url in
                                   showBrowser = false
                                   adoptDir(url)
                               })
        }
    }

    // MARK: 当前目录

    private var currentPanel: some View {
        ZLCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill.badge.person.crop")
                        .font(.system(size: 17))
                        .foregroundStyle(ZLTheme.primary)
                    Text("当前游戏目录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.activeName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                    Text(store.active?.displayPath ?? "Documents/instances/\(store.activeName)/.minecraft")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    ZLTag(text: "\(store.active?.versionCount ?? 0) 个版本")
                    ZLTag(text: "使用中", color: ZLTheme.success)
                    Spacer()
                }

                Divider()

                Text("切换目录后，版本列表、模组、存档与后续安装都会使用新目录。")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)

                ZLGoldButton(title: "新建游戏目录", icon: "plus") { showCreate = true }

                Button { showBrowser = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("浏览 instances 目录")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(ZLTheme.primarySoft)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 目录列表

    private var listPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("全部目录").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("\(store.instances.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ZLTheme.surface)
                    .clipShape(Capsule())
                Spacer()
                Button { store.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 34, height: 30)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.instances.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 30))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                            Text("还没有游戏目录").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    ForEach(store.instances) { inst in
                        instanceRow(inst)
                    }
                }
                .padding(10)
            }
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func instanceRow(_ inst: ZLGameInstance) -> some View {
        let active = store.isActive(inst.id)
        return HStack(spacing: 12) {
            Image(systemName: active ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 17))
                .foregroundStyle(active ? ZLTheme.primary : ZLTheme.textSecond)

            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(active ? ZLTheme.primary : ZLTheme.textSecond)
                .frame(width: 38, height: 38)
                .background(active ? ZLTheme.primarySoft : ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(inst.id)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                        .lineLimit(1)
                    if active {
                        ZLTag(text: "使用中", color: ZLTheme.success)
                    }
                }
                Text("\(inst.versionCount) 个版本 · \(inst.displayPath)")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)

            Menu {
                Button {
                    if !active { store.activate(inst.id) }
                } label: {
                    Label(active ? "正在使用" : "切换到此目录", systemImage: "checkmark.circle")
                }
                .disabled(active)
                Button {
                    renameTarget = inst
                    renameName = inst.id
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                .disabled(inst.id == "default")
                Button(role: .destructive) {
                    deleteTarget = inst
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(inst.id == "default" || active)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 34, height: 32)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(11)
        .background(active ? ZLTheme.primarySoft.opacity(0.6) : ZLTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if !active { store.activate(inst.id) }
        }
    }

    // MARK: 操作

    private func createDir() {
        do {
            _ = try store.create(newName)
            newName = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func doRename() {
        guard let t = renameTarget else { return }
        do {
            try store.rename(t.id, to: renameName)
        } catch {
            errorText = error.localizedDescription
        }
        renameTarget = nil
    }

    private func doDelete() {
        guard let t = deleteTarget else { return }
        do {
            try store.delete(t.id)
        } catch {
            errorText = error.localizedDescription
        }
        deleteTarget = nil
    }

    private func adoptDir(_ url: URL) {
        // 选 instances 根目录本身没有意义
        if url.standardizedFileURL.path == store.instancesRoot.standardizedFileURL.path {
            errorText = "请选择或新建一个实例文件夹（instances 下的子目录）"
            return
        }
        do {
            _ = try store.adopt(url)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - 清理游戏文件
struct CleanFilesScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var phase = 0   // 0 未开始 1 扫描中 2 预览(待确认) 3 完成
    @State private var removed = 0
    @State private var freed = "0 MB"

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "清理游戏文件", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    ZLCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("扫描范围").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text("启动器只扫描当前游戏目录下的 versions / libraries / assets 文件夹，"
                                 + "对比所有已安装版本后，清理没有任何版本引用的文件。")
                                .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11)).foregroundStyle(ZLTheme.warning)
                                Text("操作前请备份重要数据，清理不可撤销。")
                                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }

                    if phase == 2 {
                        // 预览：告诉用户会删多少，等他确认
                        ZLCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("扫描结果").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text("可清理 \(removed) 个文件，可释放 \(freed)")
                                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                                Text("确认无误后再点下面的按钮，删除不可撤销")
                                    .font(.system(size: 11)).foregroundStyle(ZLTheme.warning)
                            }
                        }
                    }

                    if phase == 3 {
                        ZLCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("清理完成").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ZLTheme.success)
                                Text("已清除 \(removed) 个文件，释放 \(freed)")
                                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }

                    // 三段式：扫描（预览）→ 确认删除 → 完成
                    ZLGoldButton(title: phase == 1 ? "扫描中…" : (phase == 0 ? "开始扫描" : (phase == 2 ? "确认清理" : "再次扫描")),
                                 icon: phase == 1 ? "clock" : (phase == 2 ? "trash" : "magnifyingglass"),
                                 enabled: phase != 1) {
                        Task {
                            let repo = VersionRepository.shared
                            if phase == 2 {
                                // 用户看过预览后确认，才真正删除
                                phase = 1
                                let r = await Task.detached(priority: .userInitiated) {
                                    repo.cleanUnusedFiles(dryRun: false)
                                }.value
                                removed = r.removedFiles
                                freed = ByteCountFormatter.string(fromByteCount: r.freedBytes, countStyle: .file)
                                phase = 3
                                return
                            }
                            // 先干跑，只统计不删
                            phase = 1
                            let r = await Task.detached(priority: .userInitiated) {
                                repo.cleanUnusedFiles(dryRun: true)
                            }.value
                            removed = r.removedFiles
                            freed = ByteCountFormatter.string(fromByteCount: r.freedBytes, countStyle: .file)
                            phase = 2
                        }
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - 导出整合包（三种格式）
struct ExportPackScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var format = 1
    // 导出内容选择（对齐 ZL2 的 7 类文件夹）
    @State private var includeOptions = true
    @State private var includeResourcePacks = true
    @State private var includeMods = true
    @State private var includeSaves = true
    @State private var includeShaders = true
    @State private var includeConfig = true
    @State private var includeLauncher = false
    @State private var name = "我的整合包"
    @State private var version = "1.0.0"
    @State private var author = ""
    @State private var desc = ""
    @State private var minMemory = 1024.0
    @State private var includeRemote = false

    private let formats = ["MCBBS 整合包", "Modrinth 整合包", "CurseForge 整合包"]
    private let formatHints = [
        "可被 HMCL 等启动器导入",
        "可被常见第三方启动器导入",
        "可被 CurseForge 生态导入",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "导出整合包", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    ZLCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("格式").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            ForEach(formats.indices, id: \.self) { i in
                                Button { format = i } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: format == i ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(format == i ? ZLTheme.primary : ZLTheme.textSecond)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formats[i]).font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(ZLTheme.textPrimary)
                                            Text(formatHints[i]).font(.system(size: 10))
                                                .foregroundStyle(ZLTheme.textSecond)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    ZLCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("元数据").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            textField("整合包名称", $name)
                            textField("整合包版本", $version)
                            textField("作者", $author)
                            textField("描述", $desc)
                        }
                    }

                    ZLCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("最小分配内存").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            HStack {
                                Slider(value: $minMemory, in: 512...8192, step: 512)
                                    .tint(ZLTheme.primary)
                                Text("\(Int(minMemory)) MB").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ZLTheme.primaryDeep).frame(width: 76)
                            }
                            Toggle("一并打包远程资源（CurseForge）", isOn: $includeRemote)
                                .font(.system(size: 12))
                                .tint(ZLTheme.primary)
                        }
                    }

                    ZLGoldButton(title: "开始导出", icon: "square.and.arrow.up") { }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func textField(_ title: String, _ binding: Binding<String>) -> some View {
        TextField(title, text: binding)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12).frame(height: 38)
            .background(ZLTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    private func contentToggle(_ title: String, _ folder: String,
                               _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: binding).labelsHidden().tint(ZLTheme.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(folder).font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            Spacer()
        }
    }

}

// MARK: - 版本操作（复制/重命名/删除）
struct VersionActionSheet: View {
    let versionName: String
    @Binding var isPresented: Bool
    var onCopy: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var showRename = false
    @State private var newName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(versionName).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").foregroundStyle(ZLTheme.textSecond)
                }
                .buttonStyle(.plain)
            }
            .padding(ZLTheme.screenPadding)

            VStack(spacing: 8) {
                actionRow("复制版本", "doc.on.doc", "复制所有文件到新版本") { onCopy() }
                actionRow("重命名版本", "pencil", "修改显示名称") { showRename = true }
                actionRow("删除版本", "trash", "谨慎操作，不可撤销", danger: true) { showDeleteConfirm = true }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background)
        .alert("重命名版本", isPresented: $showRename) {
            TextField("新名称", text: $newName)
            Button("取消", role: .cancel) { }
            Button("确定") { onRename(); isPresented = false }
        } message: {
            Text("此名称的版本不能已存在")
        }
        .alert("删除版本", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) { onDelete(); isPresented = false }
        } message: {
            Text("将删除 \(versionName) 的全部文件，无法恢复。")
        }
    }

    private func actionRow(_ title: String, _ icon: String, _ desc: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(danger ? ZLTheme.danger : ZLTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(danger ? ZLTheme.danger : ZLTheme.textPrimary)
                    Text(desc).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                }
                Spacer()
            }
            .padding(10)
        }
        .buttonStyle(.plain)
    }
}
