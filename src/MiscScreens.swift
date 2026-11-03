// ZL2-iOS · 剩余页面：搜索 / 导出 / 引导 / 崩溃日志 / 联机房间
import SwiftUI

// MARK: - 资源搜索（跨类型聚合搜索）
struct SearchScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var query = ""
    @State private var scope = 0
    private let scopes = ["全部", "模组", "整合包", "资源包", "光影"]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "搜索", active: .download, onBack: onBack, onHome: onHome)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ZLTheme.textSecond)
                    TextField("搜索模组、整合包、光影…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.leading, ZLTheme.screenPadding)
                .padding(.trailing, ZLTheme.screenPadding)
            }
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                ForEach(scopes.indices, id: \.self) { i in
                    ZLChip(title: scopes[i], selected: scope == i) { scope = i }
                }
                Spacer()
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 10) {
                    if query.isEmpty {
                        emptyHint
                    } else {
                        ForEach(results) { r in
                            resultRow(r)
                        }
                    }
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.5))
            Text("输入关键词开始搜索").font(.system(size: 14))
                .foregroundStyle(ZLTheme.textSecond)
            Text("支持 Modrinth / CurseForge 全站资源").font(.system(size: 12))
                .foregroundStyle(ZLTheme.textSecond.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var results: [AssetItem] {
        var all: [AssetItem] = []
        for k in [AssetKind.mod, .modpack, .resource, .shader] {
            all += SampleData.items(for: k).filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.subtitle.localizedCaseInsensitiveContains(query)
            }
        }
        return all
    }

    private func resultRow(_ item: AssetItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZLTheme.primarySoft)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "magnifyingglass")
                    .foregroundStyle(ZLTheme.primary))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text("\(item.author) · \(item.subtitle)")
                    .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    .lineLimit(1)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(ZLTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ZLTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 版本导出
struct ExportScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var selected: Set<String> = [".minecraft/versions", ".minecraft/mods"]
    private let options = [
        ("版本核心文件", ".minecraft/versions"),
        ("模组", ".minecraft/mods"),
        ("资源包", ".minecraft/resourcepacks"),
        ("光影", ".minecraft/shaderpacks"),
        ("存档", ".minecraft/saves"),
        ("配置文件", ".minecraft/config"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "导出整合包", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    ZLCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("选择要导出的内容").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            Text("导出的 zip 可以直接分享给别人导入").font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    ForEach(options, id: \.1) { name, path in
                        HStack(spacing: 12) {
                            Button {
                                if selected.contains(path) { selected.remove(path) }
                                else { selected.insert(path) }
                            } label: {
                                Image(systemName: selected.contains(path) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected.contains(path) ? ZLTheme.primary : ZLTheme.textSecond)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(path).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    ZLGoldButton(title: "导出并分享", icon: "square.and.arrow.up", enabled: !selected.isEmpty) { }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - 首次引导
struct WelcomeScreen: View {
    var onFinish: () -> Void = {}
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("cube.fill", "欢迎使用 ZL2", "开源的 Minecraft: Java 版启动器\n为 iOS 重新实现的界面"),
        ("wrench.and.screwdriver.fill", "先做个自检", "检查启动核心与 Java 运行时\n确保能正常启动游戏"),
        ("play.circle.fill", "准备开始", "下载一个游戏版本\n然后点击「启动游戏」"),
    ]

    var body: some View {
        ZStack {
            ZLTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: pages[page].0)
                        .font(.system(size: 56))
                        .foregroundStyle(ZLTheme.primary)
                    Text(pages[page].1)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(pages[page].2)
                        .font(.system(size: 14))
                        .foregroundStyle(ZLTheme.textSecond)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? ZLTheme.primary : ZLTheme.primarySoft)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                ZLGoldButton(title: page == pages.count - 1 ? "开始使用" : "下一步",
                             icon: page == pages.count - 1 ? "checkmark" : "arrow.right") {
                    if page < pages.count - 1 { page += 1 } else { onFinish() }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 崩溃日志
struct CrashLogScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var logs: [String] = [
        "[INFO] ZL2-iOS 启动",
        "[INFO] 核心状态: \(CoreBridge.isCoreLinked ? "已链接" : "未链接")",
        "[INFO] 运行时检查: \(CoreBridge.runtimeCheck() ? "通过" : "缺失")",
        "[INFO] 等待用户操作…",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "崩溃日志", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(logs.indices, id: \.self) { i in
                        Text(logs[i])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(ZLTheme.screenPadding)
            }
            HStack(spacing: 10) {
                ZLGoldButton(title: "复制日志", icon: "doc.on.doc") {
                    UIPasteboard.general.string = logs.joined(separator: "\n")
                }
                ZLGoldButton(title: "分享", icon: "square.and.arrow.up") { }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - 联机房间（房主 / 房客）
struct MultiplayerRoomScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var isHost = true
    @State private var code = ""
    @State private var roomCode = "—"

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "陶瓦联机", active: .multiplayer, onBack: onBack, onHome: onHome)
            HStack(spacing: ZLTheme.cardGap) {
                ZLCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("", selection: $isHost) {
                            Text("创建房间").tag(true)
                            Text("加入房间").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if isHost {
                            Text("邀请码").font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                            Text(roomCode)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(ZLTheme.primaryDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ZLTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            ZLGoldButton(title: "创建房间", icon: "person.badge.plus") {
                                roomCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
                            }
                        } else {
                            Text("输入房主给的邀请码").font(.system(size: 12))
                                .foregroundStyle(ZLTheme.textSecond)
                            TextField("6 位邀请码", text: $code)
                                .textFieldStyle(.plain)
                                .font(.system(size: 18, design: .monospaced))
                                .padding(12)
                                .background(ZLTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            ZLGoldButton(title: "加入房间", icon: "arrow.right.circle", enabled: code.count >= 4) { }
                        }
                    }
                }
                ZLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("连接状态").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ZLTheme.textPrimary)
                        HStack(spacing: 8) {
                            Circle().fill(ZLTheme.textSecond.opacity(0.4)).frame(width: 8, height: 8)
                            Text("未连接").font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
                        }
                        Divider()
                        Text("陶瓦联机基于 EasyTier P2P，房间内直连，不经过第三方服务器。")
                            .font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
                    }
                }
                .frame(width: 260)
            }
            .padding(ZLTheme.screenPadding)
            Spacer()
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
