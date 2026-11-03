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
    var versionName: String = "1.20.1 Fabric 0.19.2"
    var initial: VersionContentKind = .overview
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var kind: VersionContentKind = .overview
    @State private var enabledMods: Set<String> = ["JEI", "JourneyMap", "Waystones"]

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
        .onAppear { kind = initial }
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
        case .mods:      modList
        case .resources: fileList("资源包", ["Programmer Art", "VM 汉化资源包", "Mod Resources"], "zip")
        case .saves:     fileList("存档", ["新的世界", "Silent Hills", "创造测试"], "folder")
        case .screens:   screenshotGrid
        case .servers:   serverList
        case .shaders:   shaderList
        }
    }

    // MARK: 概览
    private var overview: some View {
        VStack(spacing: ZLTheme.cardGap) {
            ZLCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("版本信息").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    infoRow("游戏版本", "1.20.1")
                    infoRow("加载器", "Fabric 0.19.2")
                    infoRow("渲染器", "MobileGlues")
                    infoRow("内存分配", "2048 MB")
                }
            }
            ZLCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("快捷入口").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    HStack(spacing: 10) {
                        quickButton("模组", .mods)
                        quickButton("资源包", .resources)
                        quickButton("存档", .saves)
                        quickButton("截图", .screens)
                        quickButton("服务器", .servers)
                        quickButton("光影", .shaders)
                    }
                }
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
            ZLGoldButton(title: "导入\(title)", icon: "square.and.arrow.down") { }
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
            ZLGoldButton(title: "添加服务器", icon: "plus") { }
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
            ZLGoldButton(title: "导入光影", icon: "square.and.arrow.down") { }
        }
    }
}
