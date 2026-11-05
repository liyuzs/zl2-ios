// ZL2-iOS · 版本列表页（真机截图还原）
// 结构：左侧游戏目录面板 + 中间列表（筛选芯片 + 版本卡片）
//       底部：添加游戏目录 / 清理游戏文件
import SwiftUI
import Combine

/// 浏览某个版本目录用（sheet(item:) 需要 Identifiable）
private struct VersionFolderRef: Identifiable {
    let id = UUID()
    let url: URL
}

struct VersionListScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    var onMultiplayer: () -> Void = {}
    var onDownload: () -> Void = {}
    var onSettings: () -> Void = {}
    var onOpenVersion: (String) -> Void = { _ in }

    @State private var versions: [VersionRepository.InstalledVersion] = []
    @State private var filter = 0            // 0 全部 1 原版 2 可安装模组
    @State private var selected: String?
    @State private var actionVersion = ""
    @State private var showActions = false
    @State private var alertText = ""
    @State private var showAlert = false
    @State private var showDirs = false
    @State private var showClean = false
    // iOS 原生交互：长按菜单 / 下拉刷新 / ⌘R
    @State private var launchedID = ""
    @State private var showLaunch = false
    @State private var deleteTarget: String?
    @State private var browsing: VersionFolderRef?
    @State private var toast: String?
    @State private var isLoading = true
    @State private var loadError: String?
    /// 版本元信息缓存，避免每次界面刷新都读磁盘
    @State private var metaCache: [String: String] = [:]
    /// 置顶的版本 ID（持久化在 UserDefaults）
    @State private var pinned: [String] = UserDefaults.standard.stringArray(forKey: "zl.pinned.versions") ?? []

    private let filters = ["全部", "原版", "可安装模组"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "版本列表",
                     showBack: true,
                     onBack: onBack,
                     onHome: onHome,
                     onMultiplayer: onMultiplayer,
                     onDownload: onDownload,
                     onSettings: onSettings)

            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                leftPanel
                rightList
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { reload() }
        .alert(alertText, isPresented: $showAlert) { Button("好", role: .cancel) { } }
        .sheet(isPresented: $showActions) {
            VersionActionSheet(versionName: actionVersion,
                               isPresented: $showActions,
                               onCopy: {
                                   do {
                                       try VersionRepository.shared.copyVersion(actionVersion, to: "\(actionVersion)-副本")
                                       alertText = "已复制版本"
                                   } catch { alertText = ZLFriendlyError.text(error) }
                                   showAlert = true
                                   reload()
                               },
                               onRename: { reload() },
                               onDelete: {
                                   do {
                                       try VersionRepository.shared.deleteVersion(actionVersion)
                                       alertText = "已删除 \(actionVersion)"
                                   } catch { alertText = ZLFriendlyError.text(error) }
                                   showAlert = true
                                   reload()
                               })
        }
        .sheet(isPresented: $showDirs) {
            GameDirsScreen(onBack: { showDirs = false }, onHome: { showDirs = false })
        }
        .onChange(of: showDirs) { open in
            // 从游戏目录页返回后，可能已经切换了实例，重新扫描版本
            if !open { reload() }
        }
        .sheet(isPresented: $showClean) {
            CleanFilesScreen(onBack: { showClean = false }, onHome: { showClean = false })
        }
        // 长按菜单里的「启动」
        .fullScreenCover(isPresented: $showLaunch) {
            LaunchScreen(versionName: launchedID,
                         versionID: launchedID,
                         isPresented: $showLaunch)
        }
        // 长按菜单里的「浏览文件」
        .sheet(item: $browsing) { f in
            FileManagerScreen(initialPath: f.url,
                              onBack: { browsing = nil },
                              onHome: { browsing = nil })
        }
        // 长按菜单里的「删除」
        .confirmationDialog("删除版本",
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button("删除「\(deleteTarget ?? "")」", role: .destructive) {
                let id = deleteTarget
                deleteTarget = nil
                if let id { deleteVersion(id) }
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("该版本及其全部文件都会被删除，无法恢复。")
        }
        .overlay(alignment: .top) { toastView }
        // ⌘R（iPad 键盘）刷新当前页
        .onReceive(NotificationCenter.default.publisher(for: .zlRefreshRequested)) { _ in
            reload()
        }
    }

    // 左侧：游戏目录 + 底部两个按钮
    private var leftPanel: some View {
        VStack(spacing: 10) {
            // 游戏目录（米金块）
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.primary)
                    Text(VersionRepository.shared.instanceName == "default"
                         ? "默认游戏目录"
                         : VersionRepository.shared.instanceName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                Text(VersionRepository.shared.mcRoot.path
                    .replacingOccurrences(of: NSHomeDirectory(), with: ""))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ZLTheme.primaryDeep.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ZLTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer()

            // 底部两个按钮
            VStack(spacing: 8) {
                Button { showDirs = true } label: {
                    Text("添加游戏目录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { showClean = true } label: {
                    Text("清理游戏文件")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.primarySoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 190)
    }

    // 右侧：工具栏 + 列表
    private var rightList: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { reload() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12))
                        Text("刷新").font(.system(size: 12))
                    }
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { onDownload() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 12))
                        Text("安装新游戏").font(.system(size: 12))
                    }
                    .foregroundStyle(ZLTheme.textSecond)
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                ForEach(filters.indices, id: \.self) { i in
                    Button { filter = i } label: {
                        Text("\(filters[i]) · (\(count(for: i)))")
                            .font(.system(size: 11, weight: filter == i ? .semibold : .regular))
                            .foregroundStyle(filter == i ? ZLTheme.textOnGold : ZLTheme.textSecond)
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(filter == i ? ZLTheme.primary : ZLTheme.surfaceAlt)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    if isLoading {
                        // 首屏骨架：扫 versions 目录 + 统计每个版本的大小
                        ZLSkeletonList(count: 4, height: 64)
                    } else if let e = loadError {
                        errorState(e)
                    } else if current.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(current.enumerated()), id: \.element.id) { idx, v in
                            row(v)
                                .popIn(delay: Double(min(idx, 10)) * 0.035)
                        }
                    }
                }
                .padding(10)
            }
            // iOS 原生下拉刷新（重扫 versions 目录）
            .refreshable { reload() }
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func row(_ v: VersionRepository.InstalledVersion) -> some View {
        HStack(spacing: 12) {
            Button {
                selected = v.id
            } label: {
                Image(systemName: selected == v.id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected == v.id ? ZLTheme.primary : ZLTheme.textSecond)
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ZLTheme.primarySoft)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "cube.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ZLTheme.primary))

            VStack(alignment: .leading, spacing: 2) {
                Text(v.id).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textPrimary).lineLimit(1)
                HStack(spacing: 8) {
                    if let j = versionMeta(v.id) {
                        Text(j).font(.system(size: 10))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Text(ByteCountFormatter.string(fromByteCount: v.sizeBytes, countStyle: .file))
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                }
            }
            Spacer()

            Button {
                ZLHaptic.light()
                if let i = pinned.firstIndex(of: version.id) {
                    pinned.remove(at: i)
                } else {
                    pinned.insert(version.id, at: 0)
                }
                // 持久化
                UserDefaults.standard.set(pinned, forKey: "zl.pinned.versions")
                reload()
            } label: {
                Image(systemName: pinned.contains(version.id) ? "pin.fill" : "pin")
                    .font(.system(size: 15))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 38, height: 34)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { onOpenVersion(v.id) } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 15))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 38, height: 34)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                actionVersion = v.id
                showActions = true
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 38, height: 34)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ZLTheme.primarySoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        // iOS 长按菜单（iPad / 触屏都可用）
        .contextMenu {
            Button { startLaunch(v.id) } label: {
                Label("启动", systemImage: "play.fill")
            }
            Button { onOpenVersion(v.id) } label: {
                Label("设置", systemImage: "gearshape")
            }
            Button { browseFiles(v.id) } label: {
                Label("浏览文件", systemImage: "folder")
            }
            Button { copyVersionID(v.id) } label: {
                Label("复制 ID", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) { deleteTarget = v.id } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: 数据
    private var current: [VersionRepository.InstalledVersion] {
        let base: [VersionRepository.InstalledVersion]
        switch filter {
        case 1: base = versions.filter { !$0.id.lowercased().contains("fabric") && !$0.id.lowercased().contains("forge") }
        case 2: base = versions.filter { $0.id.lowercased().contains("fabric") || $0.id.lowercased().contains("forge") }
        default: base = versions
        }
        // 置顶的排最前，其余保持原顺序
        guard !pinned.isEmpty else { return base }
        let pinnedSet = Set(pinned)
        let top = pinned.compactMap { id in base.first { $0.id == id } }
        let rest = base.filter { !pinnedSet.contains($0.id) }
        return top + rest
    }

    private func count(for i: Int) -> Int {
        switch i {
        case 1: return versions.filter { !$0.id.lowercased().contains("fabric") && !$0.id.lowercased().contains("forge") }.count
        case 2: return versions.filter { $0.id.lowercased().contains("fabric") || $0.id.lowercased().contains("forge") }.count
        default: return versions.count
        }
    }

    /// 版本简介：优先走缓存，没缓存才读磁盘并写入缓存
    private func versionMeta(_ id: String) -> String? {
        if let cached = metaCache[id] { return cached.isEmpty ? nil : cached }
        let p = VersionRepository.shared.versionsDir.appendingPathComponent("\(id)/\(id).json")
        guard let d = try? Data(contentsOf: p),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        var parts: [String] = []
        if let t = o["type"] as? String { parts.append(t) }
        if let mc = o["mainClass"] as? String, mc.contains("fabric") { parts.append("Fabric") }
        let text = parts.joined(separator: " · ")
        // 写入缓存（用异步避免修改状态时的警告）
        DispatchQueue.main.async { metaCache[id] = text }
        return text.isEmpty ? nil : text
    }

    @ViewBuilder
    private var emptyState: some View {
        if versions.isEmpty {
            ZLEmptyState(
                icon: "cube",
                title: "还没有安装任何版本",
                detail: "点上方「安装新游戏」下载一个版本；\n装好后会出现在这里，点齿轮可以调内存和 JVM 参数",
                actionTitle: "安装新游戏",
                action: { onDownload() })
        } else {
            ZLEmptyState(
                icon: "line.3.horizontal.decrease",
                title: "这一类里没有版本",
                detail: "「\(filters[filter])」下面暂时没有已安装的版本，\n切回「全部」看看",
                actionTitle: "看全部",
                action: { filter = 0 })
        }
    }

    /// versions 目录没了 / 读不了时，别再显示成"没有安装版本"
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ZLTheme.warning)
            Text("版本列表没能读出来")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                ZLInteraction.haptic(.light)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }

    private func reload() {
        metaCache.removeAll()
        // listVersions() 内部把错误吞掉了，这里先探一下目录，好区分"空"和"读不了"
        let dir = VersionRepository.shared.versionsDir
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) || !isDir.boolValue {
            versions = []
            loadError = "找不到 versions 目录（\(dir.lastPathComponent)），\n可能游戏目录被删了，重选一个游戏目录再试。"
        } else if !FileManager.default.isReadableFile(atPath: dir.path) {
            versions = []
            loadError = "没有读取 versions 目录的权限。"
        } else {
            versions = VersionRepository.shared.listVersions()
            loadError = nil
        }
        isLoading = false
    }

    // MARK: - iOS 交互动作

    private func startLaunch(_ id: String) {
        ZLInteraction.haptic(.medium)
        launchedID = id
        showLaunch = true
    }

    private func browseFiles(_ id: String) {
        ZLInteraction.haptic(.light)
        let dir = VersionRepository.shared.folder(for: "版本", versionID: id)
            ?? VersionRepository.shared.versionsDir
        browsing = VersionFolderRef(url: dir)
    }

    private func copyVersionID(_ id: String) {
        ZLInteraction.haptic(.light)
        ZLInteraction.copy(id)
        showToast("已复制版本 ID：\(id)")
    }

    private func deleteVersion(_ id: String) {
        do {
            try VersionRepository.shared.deleteVersion(id)
            showToast("已删除 \(id)")
        } catch {
            showToast(ZLFriendlyError.text(error))
        }
        if selected == id { selected = nil }
        reload()
    }

    // MARK: - 轻提示

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(ZLTheme.primaryDeep))
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard toast == text else { return }
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        }
    }
}
