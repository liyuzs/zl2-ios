// ZL2-iOS · 控制管理（设置 → 控制设置 → 控制管理）
// 真机：左侧布局列表 + 工具栏，右侧布局信息面板 + 分享/编辑
import SwiftUI
import UIKit

struct ControlLayoutMeta: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var author: String = ""
    var version: String = "1.0"
    var desc: String = ""
    var isDefault: Bool = false
}

struct ControlManageScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var layouts: [ControlLayoutMeta] = []
    @State private var selected: UUID?
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newAuthor = ""
    @State private var newVersion = "1.0"
    @State private var nameError = false
    @State private var nameErrorText = "该项不能为空"
    @State private var showEditor = false
    @State private var showImporter = false
    @State private var exportText = ""
    @State private var showExport = false
    @State private var importError: String?

    private let storeKey = "zl.control.layouts"
    // 对齐 ZL2 的 LayoutInfoCheck.kt
    private let nameLength = 64
    private let authorLength = 128
    private let versionLength = 32

    var body: some View {
        VStack(spacing: 0) {
            ZLTopBar(title: "控制管理", active: .settings, onBack: onBack, onHome: onHome)

            HStack(alignment: .top, spacing: ZLTheme.cardGap) {
                leftPanel
                rightPanel
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, ZLTheme.screenPadding)
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { load() }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("导入失败", isPresented: Binding(get: { importError != nil },
                                                set: { if !$0 { importError = nil } })) {
            Button("好", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .sheet(isPresented: $showExport) {
            VStack(spacing: 12) {
                Text("布局 JSON").font(.system(size: 15, weight: .semibold))
                    .padding(.top, 16)
                ScrollView {
                    Text(exportText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 320)
                .background(ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, ZLTheme.screenPadding)
                HStack(spacing: 10) {
                    Button("复制") {
                        UIPasteboard.general.string = exportText
                        showExport = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ZLTheme.textOnGold)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(ZLTheme.primary)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.bottom, 20)
            }
            .background(ZLTheme.background)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreate) { createSheet }
        .sheet(isPresented: $showEditor) {
            ControlEditorScreen(onBack: { showEditor = false }, onHome: { showEditor = false })
        }
    }

    // 左侧：工具栏 + 布局列表
    private var leftPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                toolButton("刷新", "arrow.clockwise") { load() }
                toolButton("导入", "square.and.arrow.down") { showImporter = true }
                toolButton("创建", "plus") { showCreate = true }
                toolButton("导出", "square.and.arrow.up") { exportCurrent() }
                Spacer()
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(layouts) { layout in
                        HStack(spacing: 10) {
                            Button { selected = layout.id } label: {
                                Image(systemName: selected == layout.id ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundStyle(selected == layout.id ? ZLTheme.primary : ZLTheme.textSecond)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(layout.name).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ZLTheme.textPrimary)
                                Text(layout.version).font(.system(size: 10))
                                    .foregroundStyle(ZLTheme.textSecond)
                            }
                            Spacer()
                            Image(systemName: "iphone")
                                .font(.system(size: 13)).foregroundStyle(ZLTheme.textSecond)
                            if !layout.isDefault {
                                Button {
                                    layouts.removeAll { $0.id == layout.id }
                                    if selected == layout.id { selected = layouts.first?.id }
                                    save()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13)).foregroundStyle(ZLTheme.danger)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(selected == layout.id ? ZLTheme.primarySoft : ZLTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // 右侧：布局信息面板
    private var rightPanel: some View {
        VStack(spacing: 10) {
            ZLCard {
                VStack(spacing: 12) {
                    infoRow("布局名称", currentMeta?.name ?? "—")
                    infoRow("布局创作者", currentMeta?.author.isEmpty == false ? currentMeta!.author : "—")
                    infoRow("布局版本", currentMeta?.version ?? "—")
                    infoRow("布局描述", currentMeta?.desc.isEmpty == false ? currentMeta!.desc : "没有描述")
                }
            }

            HStack(spacing: 10) {
                Button { share() } label: {
                    Text("分享")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { showEditor = true } label: {
                    Text("编辑控制布局")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.primaryDeep)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: 300)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZLTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func toolButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(ZLTheme.textSecond)
            .padding(.horizontal, 10).frame(height: 34)
            .background(ZLTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // 创建弹窗（真机：名称必填 + 字数计数）
    private var createSheet: some View {
        VStack(spacing: 14) {
            Text("新的控制布局").font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
                .padding(.top, 20)

            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("布局名称", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10).frame(height: 38)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(nameError ? ZLTheme.danger : Color.clear, lineWidth: 1.5)
                        )
                        .onChange(of: newName) { v in
                            nameError = false
                            if v.count > nameLength { newName = String(v.prefix(nameLength)) }
                        }
                    if nameError {
                        Text(nameErrorText).font(.system(size: 10))
                            .foregroundStyle(ZLTheme.danger)
                    }
                }

                TextField("布局创作者", text: $newAuthor)
                    .onChange(of: newAuthor) { v in
                        if v.count > authorLength { newAuthor = String(v.prefix(authorLength)) }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10).frame(height: 38)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                HStack {
                    Text("文本字数：\(newAuthor.count)/128")
                        .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    Spacer()
                }

                TextField("布局版本", text: $newVersion)
                    .onChange(of: newVersion) { v in
                        if v.count > versionLength { newVersion = String(v.prefix(versionLength)) }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10).frame(height: 38)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .padding(.horizontal, ZLTheme.screenPadding)

            HStack(spacing: 10) {
                Button { showCreate = false } label: {
                    Text("取消").font(.system(size: 14))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { create() } label: {
                    Text("创建").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZLTheme.textOnGold)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(ZLTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.bottom, 20)
        }
        .background(ZLTheme.background)
        .presentationDetents([.medium])
    }

    // MARK: 数据
    private var currentMeta: ControlLayoutMeta? {
        layouts.first { $0.id == selected }
    }

    private func create() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            nameError = true
            nameErrorText = "该项不能为空"
            return
        }
        guard trimmed.count <= nameLength else {
            nameError = true
            nameErrorText = "内容过长"
            return
        }
        let m = ControlLayoutMeta(name: newName, author: newAuthor, version: newVersion)
        layouts.append(m)
        selected = m.id
        save()
        newName = ""; newAuthor = ""; newVersion = "1.0"
        showCreate = false
    }

    private func share() {
        guard let m = currentMeta else { return }
        let text = """
        ZL2 控制布局
        名称：\(m.name)
        创作者：\(m.author)
        版本：\(m.version)
        描述：\(m.desc)
        """
        UIPasteboard.general.string = text
    }

    /// 导入 ZL2 布局文件
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "无法访问该文件"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let layout = ZLLayoutStore.load(url) else {
                importError = "不是有效的 ZL2 控制布局文件"
                return
            }
            // 转成编辑器模型并加入列表
            let doc = layout.toDoc()
            var m = ControlLayoutMeta(name: doc.name,
                                      author: doc.author,
                                      version: doc.version,
                                      desc: doc.desc)
            m.isDefault = false
            layouts.append(m)
            selected = m.id
            // 保存转换后的布局文件
            ZLLayoutStore.save(layout, as: doc.name)
            save()
        case .failure(let e):
            importError = e.localizedDescription
        }
    }

    /// 导出当前布局为 ZL2 格式
    private func exportCurrent() {
        guard let meta = currentMeta else { return }
        // 优先导出已经保存过的这份布局，避免用默认布局覆盖用户内容
        var layout: ZLControlLayout
        if let entry = ZLLayoutStore.list().first(where: { $0.name == meta.name }),
           let existing = ZLLayoutStore.load(entry.url) {
            layout = existing
        } else {
            layout = ZLControlLayout.from(doc: ControlLayoutDoc.default)
        }
        layout.info = ZLLayoutInfo(name: meta.name, author: meta.author,
                                   description: meta.desc, versionCode: 1,
                                   versionName: meta.version)
        guard let data = try? layout.exportJSON(),
              let text = String(data: data, encoding: .utf8) else {
            importError = "导出失败"
            return
        }
        exportText = text
        showExport = true
        ZLLayoutStore.save(layout, as: meta.name)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let list = try? JSONDecoder().decode([ControlLayoutMeta].self, from: data) {
            layouts = list
        }
        if layouts.isEmpty {
            layouts = [
                ControlLayoutMeta(name: "默认", author: "墨北MovTery", version: "1.0", isDefault: true),
                ControlLayoutMeta(name: "我", author: "", version: "1.0"),
            ]
        }
        if selected == nil { selected = layouts.first?.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(layouts) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
