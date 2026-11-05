// ZL2-iOS · 文件管理器
// 对齐 ZL2：目录浏览 / 前进后退 / 排序 / 隐藏文件 / 重命名 / 删除到回收站 / 属性
import SwiftUI
import Combine

struct FileEntry: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDir: Bool
    let size: Int64
    let modified: Date?
}

struct FileManagerScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    /// 从版本列表「浏览文件」进来时直接定位到该目录
    var initialPath: URL? = nil

    @State private var current: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
    }()
    @State private var entries: [FileEntry] = []
    @State private var history: [URL] = []
    @State private var forward: [URL] = []
    @State private var showHidden = false
    @State private var dirFirst = true
    @State private var ascending = true
    @State private var selection = Set<UUID>()
    @State private var renaming: FileEntry?
    @State private var newName = ""
    @State private var errorText: String?
    @State private var showNewFolder = false
    @State private var folderName = "新建文件夹"
    @State private var showProperty: FileEntry?
    @State private var isLoading = true
    @State private var loadError: String?

    private let fm = FileManager.default
    private var trashDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".trash", isDirectory: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            pathBar
            listView
            bottomBar
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            if let p = initialPath,
               FileManager.default.fileExists(atPath: p.path) {
                current = p
            }
            reload()
        }
        // ⌘R（iPad 键盘）重新读当前目录
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            reload()
        }
        .alert("重命名", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("新名称", text: $newName)
            Button("取消", role: .cancel) { renaming = nil }
            Button("确定") { doRename() }
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("名称", text: $folderName)
            Button("取消", role: .cancel) { }
            Button("创建") { doCreateFolder() }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) { Button("好", role: .cancel) { } } message: { Text(errorText ?? "") }
        .sheet(item: $showProperty) { e in
            FilePropertySheet(entry: e, parent: current)
        }
    }

    // 顶部工具栏
    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left").foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: 38, height: 34)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("文件管理器").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)

            Spacer()

            iconBtn("chevron.backward") { goBack() }
            iconBtn("chevron.forward") { goForward() }
            iconBtn("arrow.up") { goUp() }
            iconBtn(showHidden ? "eye" : "eye.slash") { showHidden.toggle(); reload() }
            Menu {
                Button("新建文件夹") { showNewFolder = true }
                Button(dirFirst ? "改为文件优先" : "改为目录优先") { dirFirst.toggle(); reload() }
                Button(ascending ? "改为降序" : "改为升序") { ascending.toggle(); reload() }
                Divider()
                Button("清空回收站", role: .destructive) { emptyTrash() }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 36, height: 34)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 52)
    }

    private func iconBtn(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 36, height: 34)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // 路径条
    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.primary)
                ForEach(pathComponents, id: \.self) { part in
                    Text(part).font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                    if part != pathComponents.last {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7)).foregroundStyle(ZLTheme.textSecond.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 6)
        }
    }

    private var pathComponents: [String] {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        var s = current.path.replacingOccurrences(of: root, with: "")
        if s.isEmpty || s == "/" { return ["Documents"] }
        if s.hasPrefix("/") { s.removeFirst() }
        return ["Documents"] + s.split(separator: "/").map(String.init)
    }

    // 列表
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if isLoading {
                    // 首屏骨架：读每个条目的属性（大小 / 修改时间）要一点时间
                    ZLSkeletonList(count: 6, height: 54)
                } else if let e = loadError {
                    errorState(e)
                } else if entries.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                        entryRow(e)
                            .popIn(delay: Double(min(idx, 12)) * 0.03)
                    }
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)
        }
        // iOS 原生下拉刷新
        .refreshable { reload() }
    }

    private func entryRow(_ e: FileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: e.isDir ? "folder.fill" : fileIcon(e.name))
                .font(.system(size: 18))
                .foregroundStyle(e.isDir ? ZLTheme.primary : ZLTheme.textSecond)
                .frame(width: 34, height: 34)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                HStack(spacing: 8) {
                    if !e.isDir {
                        Text(ByteCountFormatter.string(fromByteCount: e.size, countStyle: .file))
                            .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    }
                    if let m = e.modified {
                        Text(m.formatted(date: .numeric, time: .shortened))
                            .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    }
                }
            }
            Spacer()
            if selection.contains(e.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ZLTheme.primary)
            }
        }
        .padding(10)
        .background(selection.contains(e.id) ? ZLTheme.primarySoft : ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            if e.isDir {
                history.append(current)
                current = e.url
                forward.removeAll()
                selection.removeAll()
                reload()
            } else {
                if selection.contains(e.id) { selection.remove(e.id) }
                else { selection.insert(e.id) }
            }
        }
        .contextMenu {
            if e.isDir {
                Button("进入") { history.append(current); current = e.url; reload() }
            }
            if !e.isDir {
                ShareLink(item: e.url) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
            Button("属性") { showProperty = e }
            Button("重命名") { renaming = e; newName = e.name }
            Button("删除到回收站", role: .destructive) { trash(e) }
        }
    }

    private var emptyState: some View {
        ZLEmptyState(
            icon: "folder",
            title: "这个文件夹是空的",
            detail: "点右上角「⋯」新建文件夹，\n或者从其他 App 把文件分享到 ZL2 里",
            actionTitle: "新建文件夹",
            action: { showNewFolder = true })
    }

    /// 目录打不开时给个说法（以前这里静默显示成"空目录"）
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ZLTheme.warning)
            Text("这个文件夹打不开")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            HStack(spacing: 10) {
                Button {
                    ZLHaptic.light()
                    reload()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium))
                        Text("重试").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(ZLTheme.primaryDeep)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(ZLTheme.primarySoft)
                    .clipShape(Capsule())
                }
                .buttonStyle(ZLPressStyle())

                Button {
                    ZLHaptic.light()
                    goUp()
                } label: {
                    Text("返回上一级")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textSecond)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(ZLPressStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    // 底部批量操作
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text(selection.isEmpty ? "\(entries.count) 项" : "已选中 \(selection.count) 项")
                .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            Spacer()
            // iOS 原生分享（选中文件后出现）
            if !selectedFiles.isEmpty {
                ShareLink(items: selectedFiles.map(\.url)) {
                    Label(selectedFiles.count > 1 ? "分享 \(selectedFiles.count) 个文件" : "分享",
                          systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ZLTheme.primaryDeep)
            }
            if !selection.isEmpty {
                Button("删除") {
                    let picked = entries.filter { selection.contains($0.id) }
                    picked.forEach { trash($0) }
                    selection.removeAll()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.danger)
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 42)
    }

    /// 当前选中的文件（目录不参与分享）
    private var selectedFiles: [FileEntry] {
        entries.filter { selection.contains($0.id) && !$0.isDir }
    }

    // MARK: 逻辑
    private func reload() {
        var opts: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
        if !showHidden { opts.insert(.skipsHiddenFiles) }
        do {
            let urls = try fm.contentsOfDirectory(at: current,
                                                  includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                  options: opts)
            var list: [FileEntry] = urls.compactMap { u in
                let vals = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let isDir = vals?.isDirectory ?? false
                return FileEntry(url: u,
                                 name: u.lastPathComponent,
                                 isDir: isDir,
                                 size: Int64(vals?.fileSize ?? 0),
                                 modified: vals?.contentModificationDate)
            }
            list.sort { a, b in
                if dirFirst && a.isDir != b.isDir { return a.isDir }
                let r = a.name.localizedStandardCompare(b.name)
                return ascending ? r == .orderedAscending : r == .orderedDescending
            }
            entries = list
            loadError = nil
        } catch {
            entries = []
            loadError = "打不开「\(current.lastPathComponent)」：\(ZLFriendlyError.text(error))"
        }
        isLoading = false
    }

    private func goBack() {
        guard let prev = history.popLast() else { return }
        forward.append(current)
        current = prev
        reload()
    }

    private func goForward() {
        guard let next = forward.popLast() else { return }
        history.append(current)
        current = next
        reload()
    }

    private func goUp() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard current.path != docs.path else { return }
        history.append(current)
        current = current.deletingLastPathComponent()
        reload()
    }

    private func doRename() {
        guard let e = renaming else { return }
        let dst = current.appendingPathComponent(newName)
        do { try fm.moveItem(at: e.url, to: dst) }
        catch { errorText = ZLFriendlyError.text(error) }
        renaming = nil
        reload()
    }

    private func doCreateFolder() {
        let dst = current.appendingPathComponent(folderName)
        do { try fm.createDirectory(at: dst, withIntermediateDirectories: true) }
        catch { errorText = ZLFriendlyError.text(error) }
        reload()
    }

    private func trash(_ e: FileEntry) {
        do {
            try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
            let target = trashDir.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(e.name)")
            try fm.moveItem(at: e.url, to: target)
        } catch {
            errorText = ZLFriendlyError.text(error)
        }
        reload()
    }

    private func emptyTrash() {
        guard let items = try? fm.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: nil) else { return }
        for i in items { try? fm.removeItem(at: i) }
    }

    private func fileIcon(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jar": return "shippingbox.fill"
        case "json": return "curlybraces"
        case "png", "jpg", "jpeg": return "photo.fill"
        case "zip", "mrpack": return "doc.zipper"
        case "txt", "log", "cfg", "toml": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - 属性面板
struct FilePropertySheet: View {
    let entry: FileEntry
    let parent: URL
    @Environment(\.dismiss) private var dismiss
    @State private var computedSize: Int64 = 0
    @State private var fileCount = 0
    @State private var folderCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("信息") {
                    LabeledContent("名称", value: entry.name)
                    LabeledContent("类型", value: entry.isDir ? "文件夹" : "文件")
                    LabeledContent("路径", value: entry.url.path.replacingOccurrences(
                        of: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path,
                        with: "Documents"))
                    LabeledContent("大小", value: ByteCountFormatter.string(
                        fromByteCount: entry.isDir ? computedSize : entry.size, countStyle: .file))
                    if let m = entry.modified {
                        LabeledContent("修改时间", value: m.formatted(date: .numeric, time: .standard))
                    }
                    if entry.isDir {
                        LabeledContent("包含", value: "\(folderCount) 个文件夹 / \(fileCount) 个文件")
                    }
                }
            }
            .navigationTitle("属性")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task {
                guard entry.isDir,
                      let en = FileManager.default.enumerator(at: entry.url,
                                                              includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else { return }
                for case let u as URL in en {
                    let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                    if v?.isDirectory == true { folderCount += 1 }
                    else { fileCount += 1; computedSize += Int64(v?.fileSize ?? 0) }
                }
            }
        }
    }
}
