// ZL2-iOS · 控制布局编辑器
// 对齐 ZL2：控件层 / 按钮·文本框·摇杆 / 外观样式 / 坐标与尺寸 / 点击事件
import SwiftUI

// MARK: - 控件类型
enum ControlKind: String, Codable, CaseIterable, Identifiable {
    case button = "按键"
    case text   = "文本框"
    case stick  = "摇杆"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .button: return "hand.tap.fill"
        case .text:   return "textformat"
        case .stick:  return "circle.circle.fill"
        }
    }
}

// MARK: - 点击事件
enum ControlAction: String, Codable, CaseIterable, Identifiable {
    case toggleMenu   = "切换菜单"
    case mouseLeft    = "鼠标左键"
    case mouseMiddle  = "鼠标中键"
    case mouseRight   = "鼠标右键"
    case wheelUp      = "单次滚轮上"
    case wheelDown    = "单次滚轮下"
    case sendText     = "发送文本"
    case none         = "无"
    var id: String { rawValue }
}

// MARK: - 可见场景
enum VisibleScene: String, Codable, CaseIterable, Identifiable {
    case always  = "总是可见"
    case inGame  = "游戏内可见"
    case outGame = "游戏外可见"
    var id: String { rawValue }
}

// MARK: - 控件
struct ControlItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ControlKind = .button
    var label: String = "按键"
    var x: Double = 0.5
    var y: Double = 0.5
    var width: Double = 0.08          // 相对屏幕宽
    var height: Double = 0.05         // 相对屏幕高
    var action: ControlAction = .toggleMenu
    var textToSend: String = ""
    var visibleScene: VisibleScene = .always
    var opacity: Double = 1.0
    var cornerRadius: Double = 12
    var lockable: Bool = false

    static let defaults: [ControlItem] = [
        .init(kind: .button, label: "W", x: 0.16, y: 0.70, width: 0.07, height: 0.07),
        .init(kind: .button, label: "A", x: 0.08, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "S", x: 0.16, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "D", x: 0.24, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "跳", x: 0.88, y: 0.80, width: 0.08, height: 0.08),
        .init(kind: .button, label: "蹲", x: 0.74, y: 0.88, width: 0.08, height: 0.07),
        .init(kind: .button, label: "背包", x: 0.90, y: 0.56, width: 0.08, height: 0.07),
        .init(kind: .stick, label: "摇杆", x: 0.42, y: 0.78, width: 0.14, height: 0.20),
    ]
}

// MARK: - 控件层
struct ControlLayer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [ControlItem]
    var hiddenByMouse = false
    var hiddenByGamepad = false
}

// MARK: - 布局文档
struct ControlLayoutDoc: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "我的布局"
    var author = ""
    var version = "1.0"
    var desc = ""
    var layers: [ControlLayer]

    static var `default`: ControlLayoutDoc {
        ControlLayoutDoc(name: "新的控制布局", layers: [
            ControlLayer(name: "基础", items: ControlItem.defaults)
        ])
    }
}

// MARK: - 编辑器
struct ControlEditorScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var doc = ControlLayoutDoc.default
    @State private var layerIndex = 0
    @State private var selected: UUID?
    @State private var editing = false
    @State private var showAddMenu = false
    @State private var showLayerList = false
    @State private var previewMode = 0   // 0 游戏内 1 游戏外
    @State private var snap = true

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                if showLayerList { layerPanel }
                canvas
            }
        }
        .background(ZLTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: Binding(
            get: { selected.flatMap { id in doc.layers.indices.contains(layerIndex) ? doc.layers[layerIndex].items.first(where: { $0.id == id }) : nil } },
            set: { if $0 == nil { selected = nil } }
        )) { item in
            ControlInspector(item: item) { updated in
                if doc.layers.indices.contains(layerIndex),
                   let idx = doc.layers[layerIndex].items.firstIndex(where: { $0.id == updated.id }) {
                    doc.layers[layerIndex].items[idx] = updated
                }
            }
        }
    }

    // 顶部工具栏
    private var topBar: some View {
        HStack(spacing: 10) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left").foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: 40, height: 36)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(doc.name).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)

            Spacer()

            Button { showLayerList.toggle() } label: {
                Label("控件层", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(showLayerList ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(showLayerList ? ZLTheme.primarySoft : ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { snap.toggle() } label: {
                Label("吸附", systemImage: "grid")
                    .font(.system(size: 12))
                    .foregroundStyle(snap ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(snap ? ZLTheme.primarySoft : ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { editing.toggle() } label: {
                Text(editing ? "完成" : "编辑")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZLTheme.textOnGold)
                    .padding(.horizontal, 18).frame(height: 34)
                    .background(editing ? ZLTheme.success : ZLTheme.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Menu {
                Button("添加按键") { addItem(.button) }
                Button("添加文本框") { addItem(.text) }
                Button("添加摇杆") { addItem(.stick) }
                Divider()
                Button("保存并退出") { onBack() }
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(ZLTheme.textOnGold)
                    .frame(width: 40, height: 34)
                    .background(ZLTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, ZLTheme.screenPadding)
        .frame(height: 56)
    }

    // 左侧控件层列表
    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("控件层").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZLTheme.textSecond)
                Spacer()
                Button {
                    doc.layers.append(ControlLayer(name: "新控件层", items: []))
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(ZLTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)

            ForEach(doc.layers.indices, id: \.self) { i in
                Button { layerIndex = i } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 12))
                        Text(doc.layers[i].name).font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text("\(doc.layers[i].items.count)")
                            .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    }
                    .foregroundStyle(layerIndex == i ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                    .padding(.horizontal, 10).frame(height: 36)
                    .background(layerIndex == i ? ZLTheme.primarySoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(width: 170)
        .background(ZLTheme.surface.opacity(0.5))
    }

    // 画布
    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                (previewMode == 0 ? Color(hex: 0x3A3F2E) : ZLTheme.background)
                    .ignoresSafeArea()

                if doc.layers.indices.contains(layerIndex) {
                    ForEach(doc.layers[layerIndex].items) { item in
                        controlView(item, in: geo.size)
                    }
                }

                // 悬浮菜单
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Button { previewMode = previewMode == 0 ? 1 : 0 } label: {
                            Label(previewMode == 0 ? "游戏外" : "游戏内", systemImage: "eye")
                                .font(.system(size: 11))
                                .foregroundStyle(ZLTheme.textSecond)
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(ZLTheme.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Text("点击控件可编辑属性 · 拖动调整位置")
                            .font(.system(size: 10)).foregroundStyle(ZLTheme.textSecond)
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func controlView(_ item: ControlItem, in size: CGSize) -> some View {
        let w = max(38, item.width * size.width)
        let h = max(30, item.height * size.height)
        return ZStack {
            switch item.kind {
            case .stick:
                Circle().stroke(ZLTheme.primary.opacity(0.6), lineWidth: 2)
                    .background(Circle().fill(ZLTheme.surface.opacity(0.25)))
                    .frame(width: w, height: w)
            case .text:
                Text(item.textToSend.isEmpty ? "文本" : item.textToSend)
                    .font(.system(size: 13)).foregroundStyle(ZLTheme.textPrimary)
                    .padding(.horizontal, 8).frame(minWidth: w, minHeight: h)
                    .background(ZLTheme.surface.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: item.cornerRadius, style: .continuous))
            case .button:
                Text(item.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: w, height: h)
                    .background(ZLTheme.surface.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: item.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: item.cornerRadius, style: .continuous)
                            .stroke(selected == item.id ? ZLTheme.primary : Color.clear, lineWidth: 2)
                    )
            }
        }
        .opacity(item.opacity)
        .position(x: item.x * size.width, y: item.y * size.height)
        .onTapGesture {
            if editing { selected = item.id }
        }
        .gesture(
            editing ? DragGesture().onChanged { v in
                guard doc.layers.indices.contains(layerIndex),
                      let idx = doc.layers[layerIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
                var nx = min(max(v.location.x / size.width, 0.03), 0.97)
                var ny = min(max(v.location.y / size.height, 0.03), 0.97)
                if snap {
                    nx = (nx * 50).rounded() / 50
                    ny = (ny * 50).rounded() / 50
                }
                doc.layers[layerIndex].items[idx].x = nx
                doc.layers[layerIndex].items[idx].y = ny
            } : nil
        )
    }

    private func addItem(_ kind: ControlKind) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        let item = ControlItem(kind: kind,
                               label: kind == .button ? "按键" : kind.rawValue,
                               x: 0.5, y: 0.5,
                               width: kind == .stick ? 0.14 : 0.08,
                               height: kind == .stick ? 0.20 : 0.06)
        doc.layers[layerIndex].items.append(item)
        selected = item.id
    }
}

// MARK: - 属性检查器
struct ControlInspector: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: ControlItem
    var onChange: (ControlItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $item.label)
                    Picker("类型", selection: $item.kind) {
                        ForEach(ControlKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    Picker("可见场景", selection: $item.visibleScene) {
                        ForEach(VisibleScene.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section("点击事件") {
                    Picker("动作", selection: $item.action) {
                        ForEach(ControlAction.allCases) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    if item.action == .sendText {
                        TextField("要发送的文本", text: $item.textToSend)
                    }
                }

                Section("坐标与尺寸") {
                    HStack {
                        Text("X")
                        Slider(value: $item.x, in: 0...1)
                        Text(String(format: "%.2f", item.x)).font(.caption)
                    }
                    HStack {
                        Text("Y")
                        Slider(value: $item.y, in: 0...1)
                        Text(String(format: "%.2f", item.y)).font(.caption)
                    }
                    HStack {
                        Text("宽")
                        Slider(value: $item.width, in: 0.03...0.4)
                    }
                    HStack {
                        Text("高")
                        Slider(value: $item.height, in: 0.02...0.4)
                    }
                }

                Section("外观") {
                    HStack {
                        Text("不透明度")
                        Slider(value: $item.opacity, in: 0.2...1)
                    }
                    HStack {
                        Text("圆角")
                        Slider(value: $item.cornerRadius, in: 0...40)
                    }
                }
            }
            .navigationTitle("控件属性")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onChange(item)
                        dismiss()
                    }
                }
            }
        }
    }
}
