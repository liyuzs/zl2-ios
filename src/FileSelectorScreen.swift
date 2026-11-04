// ZL2-iOS · 文件 / 目录选择器
// 对照 ZL2 的 FileSelectorScreen.kt：左侧「上级 / 新建文件夹 / 选择当前目录」，
// 右侧文件列表。iOS 版限制在 App 沙盒的 Documents 内浏览——这是当前 App 唯一
// 能直接读写的位置；外部目录需要安全书签，等后续接入文件 App 时再加。
// 用途：新建游戏目录、挑选要导入的 jar / zip 等。
import SwiftUI

enum ZLFileSelectorMode: Equatable {
    case directory
    /// 只显示指定后缀的文件（空数组表示全部）
    case file(extensions: [String])

    var isDirectory: Bool {
        if case .directory = self { return true }
        return false
    }

    func allows(_ name: String) -> Bool {
        switch self {
        case .directory:
            return true
        case .file(let exts):
            guard !exts.isEmpty else { return true }
            let e = (name as NSString).pathExtension.lowercased()
            return exts.map { $0.lowercased() }.contains(e)
        }
    }
}

struct FileSelectorScreen: View {
    var startURL: URL? = nil
    var mode: ZLFileSelectorMode = .directory
    var title: String = "选择目录"
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onSelect: (URL) -> Void = { _ in }

    @State private var current: URL = FileSelectorScreen.documents
    @State private var entries: [FileEntry] = []
    @State private var selectedFile: URL?
    @State private var showHidden = false
    @State private var didInit = false
    @State private var showNewFolder = false
    @State private var newFolderName = "新建文件夹"
    @State private var errorText: String?

    private let fm = FileManager.default

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: title, onBack: onBack, onHome: onHome)
            pathBar
            toolbar
            list
            footer
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if !didInit {
                current = startURL ?? Self.documents
                didInit = true
            }
            reload()
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("取消", role: .cancel) { }
            Button("创建") { createFolder() }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("好", role: .cancel) { }
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: 路径

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.primary)
                ForEach(pathComponents, id: \.self) { part in
                    Text(part)
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                    if part != pathComponents.last {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 8)
        }
    }

    private var pathComponents: [String] {
        let root = Self.documents.path
        var s = current.path.replacingOccurrences(of: root, with: "")
        if s.isEmpty || s == "/" { return ["Documents"] }
        if s.hasPrefix("/") { s.removeFirst() }
        return ["Documents"] + s.split(separator: "/").map(String.init)
    }

    // MARK: 工具栏

    private var toolbar: some View {
        HStack(spacing: 8) {
            toolButton("chevron.up", "上级") { goUp() }
            toolButton("folder.badge.plus", "新建文件夹") { showNewFolder = true }
            toolButton(showHidden ? "eye" : "eye.slash", showHidden ? "隐藏文件" : "显示隐藏") {
                showHidden.toggle()
                reload()
            }
            Spacer()
            Text("\(displayEntries.count) 项")
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .padding(.bottom, 8)
    }

    private func toolButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 11))
            }
            .foregroundStyle(ZLTheme.textSecond)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 列表

    private var displayEntries: [FileEntry] {
        entries.filter { entry in
            if entry.isDir { return true }
            guard mode.allows(entry.name) else { return false }
            return true
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if displayEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: mode.isDirectory ? "folder" : "doc")
                            .font(.system(size: 30))
                            .foregroundStyle(ZLTheme.textSecond.opacity(0.35))
                        Text(mode.isDirectory ? "这个目录是空的" : "没有可选的文件")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
                ForEach(displayEntries) { e in
                    row(e)
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)
        }
    }

    private func row(_ e: FileEntry) -> some View {
        let isSelected = selectedFile == e.url
        return HStack(spacing: 12) {
            Image(systemName: e.isDir ? "folder.fill" : iconFor(e.name))
                .font(.system(size: 17))
                .foregroundStyle(e.isDir ? ZLTheme.primary : ZLTheme.textSecond)
                .frame(width: 36, height: 36)
                .background(e.isDir ? ZLTheme.primarySoft : ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(e.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !e.isDir {
                        Text(ByteCountFormatter.string(fromByteCount: e.size, countStyle: .file))
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    if let m = e.modified {
                        Text(m.formatted(date: .numeric, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                }
            }
            Spacer(minLength: 6)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ZLTheme.primary)
            } else if e.isDir {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(ZLTheme.textSecond.opacity(0.5))
            }
        }
        .padding(10)
        .background(isSelected ? ZLTheme.primarySoft : ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if e.isDir {
                selectedFile = nil
                current = e.url
                reload()
            } else if !mode.isDirectory {
                selectedFile = e.url
            }
        }
    }

    private func iconFor(_ name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "jar": return "shippingbox.fill"
        case "zip", "mrpack": return "doc.zipper"
        case "png", "jpg", "jpeg": return "photo.fill"
        case "json": return "curlybraces"
        case "txt", "log", "cfg", "toml": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    // MARK: 底部

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.isDirectory ? "当前目录" : "已选文件")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                Text(mode.isDirectory ? current.lastPathComponent
                                      : (selectedFile?.lastPathComponent ?? "—"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            ZLGoldButton(title: mode.isDirectory ? "选择此目录" : "选择此文件",
                         icon: "checkmark",
                         enabled: mode.isDirectory || selectedFile != nil) {
                confirm()
            }
            .frame(width: 190)
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .padding(.vertical, 10)
        .background(ZLTheme.surface)
    }

    private func confirm() {
        if mode.isDirectory {
            onSelect(current)
        } else if let f = selectedFile {
            onSelect(f)
        }
    }

    // MARK: 文件操作

    private func reload() {
        var opts: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
        if !showHidden { opts.insert(.skipsHiddenFiles) }
        guard let urls = try? fm.contentsOfDirectory(
            at: current,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: opts) else {
            entries = []
            return
        }
        var list: [FileEntry] = urls.compactMap { u in
            let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return FileEntry(url: u,
                             name: u.lastPathComponent,
                             isDir: v?.isDirectory ?? false,
                             size: Int64(v?.fileSize ?? 0),
                             modified: v?.contentModificationDate)
        }
        // 目录优先，再按名称
        list.sort { a, b in
            if a.isDir != b.isDir { return a.isDir }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        entries = list
    }

    private func goUp() {
        let parent = current.deletingLastPathComponent()
        guard parent.path.hasPrefix(Self.documents.path),
              parent.path != current.path else { return }
        current = parent
        selectedFile = nil
        reload()
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/") else {
            errorText = "文件夹名称不合法"
            return
        }
        let dst = current.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: dst.path) else {
            errorText = "同名文件夹已存在"
            return
        }
        do {
            try fm.createDirectory(at: dst, withIntermediateDirectories: false)
            reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
