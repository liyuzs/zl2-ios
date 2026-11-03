// ZL2-iOS · 版本列表页（真机截图还原）
// 结构：左侧游戏目录面板 + 中间列表（筛选芯片 + 版本卡片）
//       底部：添加游戏目录 / 清理游戏文件
import SwiftUI

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
                                   } catch { alertText = error.localizedDescription }
                                   showAlert = true
                                   reload()
                               },
                               onRename: { reload() },
                               onDelete: {
                                   do {
                                       try VersionRepository.shared.deleteVersion(actionVersion)
                                       alertText = "已删除 \(actionVersion)"
                                   } catch { alertText = error.localizedDescription }
                                   showAlert = true
                                   reload()
                               })
        }
        .sheet(isPresented: $showDirs) {
            GameDirsScreen(onBack: { showDirs = false }, onHome: { showDirs = false })
        }
        .sheet(isPresented: $showClean) {
            CleanFilesScreen(onBack: { showClean = false }, onHome: { showClean = false })
        }
    }

    // 左侧：游戏目录 + 底部两个按钮
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZLCard(padding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ZLTheme.primary)
                        Text("默认游戏目录")
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
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(2)
                }
            }

            Spacer()

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

                Button { } label: {
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
                    ZLChip(title: "\(filters[i]) · (\(count(for: i)))",
                           selected: filter == i) { filter = i }
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    if current.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "cube").font(.system(size: 30))
                                .foregroundStyle(ZLTheme.textSecond.opacity(0.4))
                            Text("没有安装版本").font(.system(size: 13))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    ForEach(current, id: \.id) { v in
                        row(v)
                    }
                }
                .padding(.bottom, 6)
            }
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

            Button { } label: {
                Image(systemName: "pin").font(.system(size: 15))
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
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: 数据
    private var current: [VersionRepository.InstalledVersion] {
        switch filter {
        case 1: return versions.filter { !$0.id.lowercased().contains("fabric") && !$0.id.lowercased().contains("forge") }
        case 2: return versions.filter { $0.id.lowercased().contains("fabric") || $0.id.lowercased().contains("forge") }
        default: return versions
        }
    }

    private func count(for i: Int) -> Int {
        switch i {
        case 1: return versions.filter { !$0.id.lowercased().contains("fabric") && !$0.id.lowercased().contains("forge") }.count
        case 2: return versions.filter { $0.id.lowercased().contains("fabric") || $0.id.lowercased().contains("forge") }.count
        default: return versions.count
        }
    }

    private func versionMeta(_ id: String) -> String? {
        // 从版本 json 里读 mainClass 之类的简短信息
        let p = VersionRepository.shared.versionsDir.appendingPathComponent("\(id)/\(id).json")
        guard let d = try? Data(contentsOf: p),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        var parts: [String] = []
        if let t = o["type"] as? String { parts.append(t) }
        if let mc = o["mainClass"] as? String, mc.contains("fabric") { parts.append("Fabric") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func reload() {
        versions = VersionRepository.shared.listVersions()
    }
}
