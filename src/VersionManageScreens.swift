// ZL2-iOS · 版本管理补充
// 游戏目录管理 / 清理文件 / 复制重命名 / 三种格式导出
import SwiftUI

// MARK: - 游戏目录管理
struct GameDirsScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var dirs: [String] = ["默认游戏目录"]
    @State private var showAdd = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "游戏目录", onBack: onBack, onHome: onHome)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(dirs.indices, id: \.self) { i in
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20)).foregroundStyle(ZLTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(ZLTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(dirs[i]).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(i == 0 ? "当前使用中" : "未激活")
                                    .font(.system(size: 11))
                                    .foregroundStyle(i == 0 ? ZLTheme.success : ZLTheme.textSecond)
                            }
                            Spacer()
                            if i != 0 {
                                Button {
                                    dirs.remove(at: i)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(ZLTheme.danger)
                                        .frame(width: 36, height: 36)
                                        .background(ZLTheme.surfaceAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    ZLGoldButton(title: "添加游戏目录", icon: "plus") { showAdd = true }
                }
                .padding(ZLTheme.screenPadding)
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("为该游戏目录命名", isPresented: $showAdd) {
            TextField("目录名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("添加") {
                if !newName.isEmpty && !dirs.contains(newName) {
                    dirs.append(newName)
                }
                newName = ""
            }
        } message: {
            Text("目录名不能重复")
        }
    }
}

// MARK: - 清理游戏文件
struct CleanFilesScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    @State private var phase = 0   // 0 未开始 1 扫描中 2 完成
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
                        ZLCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("清理完成").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ZLTheme.success)
                                Text("已清除 \(removed) 个文件，释放 \(freed)")
                                    .font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                            }
                        }
                    }

                    ZLGoldButton(title: phase == 1 ? "扫描中…" : (phase == 2 ? "再次扫描" : "开始扫描"),
                                 icon: phase == 1 ? "clock" : "magnifyingglass",
                                 enabled: phase != 1) {
                        Task {
                            phase = 1
                            try? await Task.sleep(nanoseconds: 900_000_000)
                            removed = Int.random(in: 12...86)
                            freed = "\(removed * 2) MB"
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
