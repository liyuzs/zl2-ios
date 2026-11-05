// ZL2-iOS · 运行日志
// 对照 ZL2 的 LogViewScreen.kt：只读查看日志文件，自动滚到末尾。
// iOS 版额外做了：日志文件切换（游戏 latest.log / ame.log / 崩溃报告）、
// 自动刷新、只看问题行、复制与分享。大文件只读末尾 4 MB。
import SwiftUI
import UIKit
import Combine

struct ZLLogFile: Identifiable {
    let id: String
    let name: String
    let url: URL
    let modified: Date?
    let size: Int64
    let group: String
}

struct LogViewScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var initialPath: String? = nil

    @State private var files: [ZLLogFile] = []
    @State private var selected: URL?
    @State private var lines: [String] = []
    // 初始值跟随设置里的「打开时自动刷新日志」
    @State private var autoRefresh = UserDefaults.standard.object(forKey: "showLogAutomatic") as? Bool ?? false
    @State private var autoScroll = true
    @State private var onlyProblems = false
    @State private var truncated = false
    @State private var status = ""
    @State private var loadError: String?
    @State private var lastSize: Int64 = -1
    @State private var lastModified: Date?
    /// 只有首屏用骨架；后面自动刷新不能闪
    @State private var isLoading = true

    private let fm = FileManager.default
    private let maxLines = 3000

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    /// 日志正文字号（设置里的 logTextSize，默认 15，限制 5~20）
    private var logFontSize: CGFloat {
        let v = UserDefaults.standard.object(forKey: "logTextSize") as? Int ?? 15
        return CGFloat(max(5, min(20, v)))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "运行日志", onBack: onBack, onHome: onHome)
            toolbar
            logArea
            bottomBar
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            scanFiles()
            load(scroll: true)
        }
        .onReceive(timer) { _ in
            guard autoRefresh else { return }
            if fileChanged {
                scanFiles()
                load(scroll: autoScroll)
            }
        }
        // ⌘R（iPad 键盘）立即重新读取日志
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            scanFiles()
            load(scroll: autoScroll)
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(groupedFiles.indices, id: \.self) { gi in
                    let group = groupedFiles[gi]
                    Section(header: Text(group.0)) {
                        ForEach(group.1) { f in
                            Button {
                                selected = f.url
                                load(scroll: true)
                            } label: {
                                if selected == f.url {
                                    Label(f.name, systemImage: "checkmark")
                                } else {
                                    Text(f.name)
                                }
                            }
                        }
                    }
                }
                if files.isEmpty {
                    Text("没有找到日志文件")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                    Text(selected?.lastPathComponent ?? "选择日志")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            pill("自动刷新", on: autoRefresh) {
                autoRefresh.toggle()
            }
            pill("只看问题", on: onlyProblems) {
                onlyProblems.toggle()
            }
            pill("自动滚动", on: autoScroll) {
                autoScroll.toggle()
            }

            Spacer()

            Button {
                load(scroll: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 34, height: 34)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                UIPasteboard.general.string = lines.joined(separator: "\n")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 34, height: 34)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(lines.isEmpty)

            if !lines.isEmpty {
                ShareLink(item: lines.joined(separator: "\n")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 34, height: 34)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .padding(.bottom, 8)
    }

    private func pill(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(on ? ZLTheme.success : ZLTheme.textSecond.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text(title).font(.system(size: 11))
            }
            .foregroundStyle(on ? ZLTheme.primaryDeep : ZLTheme.textSecond)
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(on ? ZLTheme.primarySoft : ZLTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日志内容

    private var logArea: some View {
        Group {
            if isLoading {
                // 首屏骨架：读末尾 4 MB + 拆成几千行要一会儿，比空白好
                ZLSkeletonList(count: 8, height: 12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if let e = loadError {
                ZLEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "读不了日志",
                    detail: e,
                    actionTitle: "重试",
                    action: { rescanAndLoad() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayLines.isEmpty {
                if onlyProblems {
                    ZLEmptyState(
                        icon: "checkmark.seal",
                        title: "没有 ERROR / WARN 行",
                        detail: "这次运行看起来挺干净。\n关掉「只看问题」可以看完整日志",
                        actionTitle: "看完整日志",
                        action: { onlyProblems = false })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZLEmptyState(
                        icon: "doc.text",
                        title: files.isEmpty ? "还没有日志文件" : "日志还是空的",
                        detail: files.isEmpty
                            ? "启动一次游戏，latest.log 会自动出现在这里；\n崩溃报告和启动器日志也会一起列出来"
                            : "这个文件现在是空的，游戏跑起来会一行行写进来。\n切回游戏玩一会儿，再点「重新读取」",
                        actionTitle: "重新读取",
                        action: { rescanAndLoad() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(displayLines.indices, id: \.self) { index in
                                Text(displayLines[index])
                                    .font(.system(size: logFontSize, design: .monospaced))
                                    .foregroundStyle(color(for: displayLines[index]))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(10)
                    }
                    .popIn()
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, ZLTheme.screenPadding)
                    .onChange(of: displayLines.count) { _ in
                        guard autoScroll, let last = displayLines.indices.last else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        guard autoScroll, let last = displayLines.indices.last else { return }
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var displayLines: [String] {
        guard onlyProblems else { return lines }
        return lines.filter { l in
            let u = l.uppercased()
            return u.contains("ERROR") || u.contains("WARN") || u.contains("FATAL")
                || u.contains("EXCEPTION") || u.contains("Caused by")
        }
    }

    private func color(for line: String) -> Color {
        let u = line.uppercased()
        if u.contains("ERROR") || u.contains("FATAL") || u.contains("EXCEPTION") || u.contains("Caused by") {
            return ZLTheme.danger
        }
        if u.contains("WARN") {
            return ZLTheme.warning
        }
        return ZLTheme.textSecond
    }

    // MARK: - 底部状态

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if truncated {
                Text("仅显示最后 \(maxLines) 行")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.warning)
            } else {
                Text("\(lines.count) 行")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            if !status.isEmpty {
                Text("·").foregroundStyle(ZLTheme.textSecond)
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
            }
            Spacer()
            if let s = selected {
                Text(s.path.replacingOccurrences(of: documents.path, with: "Documents"))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 32)
    }

    // MARK: - 文件

    private var documents: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var groupedFiles: [(String, [ZLLogFile])] {
        var order: [String] = []
        var map: [String: [ZLLogFile]] = [:]
        for f in files {
            if map[f.group] == nil { order.append(f.group) }
            map[f.group, default: []].append(f)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private var fileChanged: Bool {
        // 还没选中文件时也要继续扫：否则游戏刚写出的 latest.log 永远发现不了
        guard let url = selected else { return true }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return true }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mod = attrs[.modificationDate] as? Date
        return size != lastSize || mod != lastModified
    }

    /// 重新扫文件再读一次（重试用）
    private func rescanAndLoad() {
        scanFiles()
        load(scroll: true)
    }

    private func scanFiles() {
        var list: [ZLLogFile] = []
        let mc = VersionRepository.shared.mcRoot

        func add(_ url: URL, group: String) {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return }
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            list.append(ZLLogFile(id: url.path,
                                  name: url.lastPathComponent,
                                  url: url,
                                  modified: attrs[.modificationDate] as? Date,
                                  size: size,
                                  group: group))
        }

        // 游戏日志
        let logs = mc.appendingPathComponent("logs", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: logs,
                                                   includingPropertiesForKeys: [.contentModificationDateKey],
                                                   options: [.skipsHiddenFiles]) {
            for u in items where u.pathExtension.lowercased() == "log" || u.pathExtension.lowercased() == "txt" {
                add(u, group: "游戏日志")
            }
        }
        // 启动器核心日志
        let ame = documents.appendingPathComponent("ame.log")
        if fm.fileExists(atPath: ame.path) {
            add(ame, group: "启动器日志")
        }
        // 崩溃报告
        let crash = mc.appendingPathComponent("crash-reports", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: crash,
                                                   includingPropertiesForKeys: [.contentModificationDateKey],
                                                   options: [.skipsHiddenFiles]) {
            for u in items where u.pathExtension.lowercased() == "txt" {
                add(u, group: "崩溃报告")
            }
        }

        files = list.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }

        if let p = initialPath, fm.fileExists(atPath: p), selected == nil {
            selected = URL(fileURLWithPath: p)
        }
        if selected == nil {
            selected = files.first(where: { $0.name == "latest.log" })?.url ?? files.first?.url
        }
    }

    private func load(scroll: Bool) {
        guard let url = selected else {
            // 没有日志文件不算错误，交给空状态说明下一步
            loadError = nil
            lines = []
            truncated = false
            status = ""
            isLoading = false
            return
        }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else {
            loadError = "日志文件不存在：\(url.lastPathComponent)"
            lines = []
            isLoading = false
            return
        }
        lastSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        lastModified = attrs[.modificationDate] as? Date

        guard let text = readTail(url) else {
            loadError = "无法读取日志文件（可能被别的进程占用）"
            lines = []
            isLoading = false
            return
        }
        var all = text.components(separatedBy: "\n")
        if all.last == "" { all.removeLast() }
        truncated = all.count > maxLines
        if truncated { all = Array(all.suffix(maxLines)) }
        lines = all
        loadError = nil

        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        status = lastModified.map { "更新于 \(df.string(from: $0))" } ?? ""
        isLoading = false
    }

    /// 只读取文件末尾，避免超大日志把内存打满
    private func readTail(_ url: URL, maxBytes: Int = 4 * 1024 * 1024) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        do {
            let size = try fh.seekToEnd()
            let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
            try fh.seek(toOffset: start)
            let data = fh.readDataToEndOfFile()
            var s = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            if start > 0, let nl = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: nl)...])
            }
            return s
        } catch {
            return nil
        }
    }
}
