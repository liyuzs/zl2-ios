// ZL2-iOS · 控制布局编辑器（完整版）
// 对齐 ZL2：控件层 / 按钮·文本框·摇杆 / 外观样式与样式收藏柜 / 摇杆详细配置 /
//          控件复制（当前层·指定层）/ 控件层属性 / 布局 JSON 导入导出
import SwiftUI
import Foundation

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

// MARK: - 文本对齐（对齐 ZL2 的 TextAlignment）
enum ControlTextAlignment: String, Codable, CaseIterable, Identifiable {
    case left   = "左"
    case center = "中"
    case right  = "右"
    var id: String { rawValue }
}

// MARK: - 四角圆角（四个角可分别设置）
struct ControlCorners: Codable, Equatable {
    var topLeft: Double
    var topRight: Double
    var bottomLeft: Double
    var bottomRight: Double

    init(topLeft: Double = 12, topRight: Double = 12, bottomLeft: Double = 12, bottomRight: Double = 12) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    static func uniform(_ value: Double) -> ControlCorners {
        ControlCorners(topLeft: value, topRight: value, bottomLeft: value, bottomRight: value)
    }

    var maxValue: Double { max(max(topLeft, topRight), max(bottomLeft, bottomRight)) }

    func value(at index: Int) -> Double {
        switch index {
        case 0:  return topLeft
        case 1:  return topRight
        case 2:  return bottomLeft
        default: return bottomRight
        }
    }

    mutating func setValue(_ newValue: Double, at index: Int) {
        switch index {
        case 0:  topLeft = newValue
        case 1:  topRight = newValue
        case 2:  bottomLeft = newValue
        default: bottomRight = newValue
        }
    }

    enum CodingKeys: String, CodingKey {
        case topLeft, topRight, bottomLeft, bottomRight
    }
}

extension ControlCorners {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = container.zlValue(.topLeft, 12.0)
        topLeft = fallback
        topRight = container.zlValue(.topRight, fallback)
        bottomLeft = container.zlValue(.bottomLeft, fallback)
        bottomRight = container.zlValue(.bottomRight, fallback)
    }
}

// MARK: - 四角可分别设置的圆角形状
struct ControlCornerShape: Shape {
    var corners: ControlCorners

    func path(in rect: CGRect) -> Path {
        let limit = Double(min(rect.width, rect.height)) / 2
        let tl = CGFloat(min(max(0, corners.topLeft), limit))
        let tr = CGFloat(min(max(0, corners.topRight), limit))
        let bl = CGFloat(min(max(0, corners.bottomLeft), limit))
        let br = CGFloat(min(max(0, corners.bottomRight), limit))

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 容错解码（老布局 / 手工编辑的 JSON 缺少字段时用默认值）
extension KeyedDecodingContainer {
    func zlValue<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

// MARK: - 外观配色（颜色统一用 0xRRGGBB 存，方便 Codable）
struct ControlColorOption: Identifiable {
    let hex: UInt32
    var name: String
    var id: UInt32 { hex }
}

enum ControlColorPalette {
    static let options: [ControlColorOption] = [
        ControlColorOption(hex: 0xFFFFFF, name: "白"),
        ControlColorOption(hex: 0xF7F3E6, name: "象牙"),
        ControlColorOption(hex: 0xEDE3C8, name: "米黄"),
        ControlColorOption(hex: 0xB99B4A, name: "橄榄金"),
        ControlColorOption(hex: 0x8E7433, name: "深金"),
        ControlColorOption(hex: 0x4A7C3F, name: "苔绿"),
        ControlColorOption(hex: 0x3A3F2E, name: "墨绿"),
        ControlColorOption(hex: 0x2F6B8B, name: "湖蓝"),
        ControlColorOption(hex: 0xB3402F, name: "砖红"),
        ControlColorOption(hex: 0xC08A2E, name: "琥珀"),
        ControlColorOption(hex: 0x7A5C3E, name: "木褐"),
        ControlColorOption(hex: 0xDCEFE3, name: "薄荷"),
        ControlColorOption(hex: 0x9A958A, name: "雾灰"),
        ControlColorOption(hex: 0x5A5544, name: "橄榄灰"),
        ControlColorOption(hex: 0x2C2A20, name: "深灰"),
        ControlColorOption(hex: 0x1B1B1B, name: "近黑"),
        ControlColorOption(hex: 0x000000, name: "纯黑"),
        ControlColorOption(hex: 0xF2F2F2, name: "浅灰")
    ]
}

// MARK: - 控件外观样式
struct ControlAppearance: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "默认样式"
    /// 正常态不透明度
    var normalOpacity: Double = 0.85
    /// 按下态不透明度
    var pressedOpacity: Double = 1.0
    /// 背景色
    var backgroundHex: UInt32 = 0xF7F3E6
    /// 内容（文字 / 图标）色
    var contentHex: UInt32 = 0x2C2A20
    /// 边框粗细
    var borderWidth: Double = 1.0
    /// 边框色
    var borderHex: UInt32 = 0xCFC8B4
    /// 四角圆角
    var corners: ControlCorners = ControlCorners.uniform(12)
    /// 是否启用动画过渡
    var animated: Bool = true
    /// 是否区分暗色主题
    var separateDark: Bool = false
    var darkBackgroundHex: UInt32 = 0x1F1E1A
    var darkContentHex: UInt32 = 0xEFE9D6
    var darkBorderHex: UInt32 = 0x5A5544
    var darkNormalOpacity: Double = 0.80
    var darkPressedOpacity: Double = 0.95

    static let `default` = ControlAppearance()

    enum CodingKeys: String, CodingKey {
        case id, name, normalOpacity, pressedOpacity, backgroundHex, contentHex,
             borderWidth, borderHex, corners, animated, separateDark,
             darkBackgroundHex, darkContentHex, darkBorderHex,
             darkNormalOpacity, darkPressedOpacity
    }

    var backgroundColor: Color { Color(hex: backgroundHex) }
    var contentColor: Color { Color(hex: contentHex) }
    var borderColor: Color { Color(hex: borderHex) }
    var darkBackgroundColor: Color { Color(hex: darkBackgroundHex) }
    var darkContentColor: Color { Color(hex: darkContentHex) }
    var darkBorderColor: Color { Color(hex: darkBorderHex) }

    /// 按当前配色（浅色 / 暗色）解析出真正用来绘制的值
    func resolved(dark: Bool) -> ResolvedControlAppearance {
        let useDark = dark && separateDark
        return ResolvedControlAppearance(
            opacity: useDark ? darkNormalOpacity : normalOpacity,
            pressedOpacity: useDark ? darkPressedOpacity : pressedOpacity,
            background: Color(hex: useDark ? darkBackgroundHex : backgroundHex),
            content: Color(hex: useDark ? darkContentHex : contentHex),
            borderColor: Color(hex: useDark ? darkBorderHex : borderHex),
            borderWidth: borderWidth,
            corners: corners,
            animated: animated
        )
    }

    var summary: String {
        String(format: "不透明度 %.2f / 按下 %.2f · 圆角 %.0f · 边框 %.0f",
               normalOpacity, pressedOpacity, corners.maxValue, borderWidth)
    }

    // 内置样式预设
    static let presets: [ControlAppearance] = [
        make("象牙白", 0xF7F3E6, 0x2C2A20, 0xCFC8B4, corners: 12, opacity: 0.85),
        make("橄榄金", 0xB99B4A, 0xFFF8E4, 0x8E7433, corners: 14, opacity: 0.90),
        make("薄荷绿", 0xDCEFE3, 0x24402E, 0x9CC3A9, corners: 18, opacity: 0.88),
        make("砖红", 0xB3402F, 0xFFF1EB, 0x7E2A1E, corners: 10, opacity: 0.90),
        make("木质", 0x8C6B47, 0x2B1D10, 0x5E452B, corners: 8, opacity: 0.92),
        make("暗夜玻璃", 0x1B1B1B, 0xF2F2F2, 0x444444, corners: 16, opacity: 0.75,
             separateDark: true, darkBackground: 0x303030, darkContent: 0xFFFFFF, darkBorder: 0x6B6B6B)
    ]

    private static func make(_ name: String,
                             _ background: UInt32,
                             _ content: UInt32,
                             _ border: UInt32,
                             corners: Double = 12,
                             opacity: Double = 0.85,
                             separateDark: Bool = false,
                             darkBackground: UInt32 = 0x1F1E1A,
                             darkContent: UInt32 = 0xEFE9D6,
                             darkBorder: UInt32 = 0x5A5544) -> ControlAppearance {
        var style = ControlAppearance()
        style.name = name
        style.backgroundHex = background
        style.contentHex = content
        style.borderHex = border
        style.corners = ControlCorners.uniform(corners)
        style.normalOpacity = opacity
        style.pressedOpacity = min(1.0, opacity + 0.15)
        style.separateDark = separateDark
        style.darkBackgroundHex = darkBackground
        style.darkContentHex = darkContent
        style.darkBorderHex = darkBorder
        style.darkNormalOpacity = max(0.2, opacity - 0.05)
        style.darkPressedOpacity = min(1.0, opacity + 0.1)
        return style
    }
}

extension ControlAppearance {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.zlValue(.id, UUID())
        name = container.zlValue(.name, "自定义样式")
        normalOpacity = container.zlValue(.normalOpacity, 0.85)
        pressedOpacity = container.zlValue(.pressedOpacity, 1.0)
        backgroundHex = container.zlValue(.backgroundHex, UInt32(0xF7F3E6))
        contentHex = container.zlValue(.contentHex, UInt32(0x2C2A20))
        borderWidth = container.zlValue(.borderWidth, 1.0)
        borderHex = container.zlValue(.borderHex, UInt32(0xCFC8B4))
        corners = container.zlValue(.corners, ControlCorners.uniform(12))
        animated = container.zlValue(.animated, true)
        separateDark = container.zlValue(.separateDark, false)
        darkBackgroundHex = container.zlValue(.darkBackgroundHex, UInt32(0x1F1E1A))
        darkContentHex = container.zlValue(.darkContentHex, UInt32(0xEFE9D6))
        darkBorderHex = container.zlValue(.darkBorderHex, UInt32(0x5A5544))
        darkNormalOpacity = container.zlValue(.darkNormalOpacity, 0.80)
        darkPressedOpacity = container.zlValue(.darkPressedOpacity, 0.95)
    }
}

/// 解析后的外观（绘制用）
struct ResolvedControlAppearance {
    var opacity: Double
    var pressedOpacity: Double
    var background: Color
    var content: Color
    var borderColor: Color
    var borderWidth: Double
    var corners: ControlCorners
    var animated: Bool
}

// MARK: - 摇杆方向事件
enum StickDirectionMode: String, Codable, CaseIterable, Identifiable {
    case eight = "八向"
    case four  = "四向"
    var id: String { rawValue }
    var tickCount: Int { self == .eight ? 8 : 4 }
}

// MARK: - 摇杆操控方式
enum StickTriggerMode: String, Codable, CaseIterable, Identifiable {
    case drag  = "拖动触发"
    case touch = "触碰触发"
    var id: String { rawValue }
}

// MARK: - 摇杆详细配置
struct ControlStickConfig: Codable, Equatable {
    /// 方向事件：8 向 / 4 向
    var directionMode: StickDirectionMode = .eight
    /// 摇杆大小（倍率）
    var size: Double = 1.0
    /// 死区范围
    var deadZone: Double = 0.12
    /// 锁定阈值
    var lockThreshold: Double = 0.70
    /// 前进锁定
    var forwardLock: Bool = false
    /// 操控方式
    var triggerMode: StickTriggerMode = .drag

    static let `default` = ControlStickConfig()

    enum CodingKeys: String, CodingKey {
        case directionMode, size, deadZone, lockThreshold, forwardLock, triggerMode
    }

    var summary: String {
        let numbers = String(format: "大小 %.1f× · 死区 %.2f · 锁定 %.2f",
                             size, deadZone, lockThreshold)
        let lock = forwardLock ? " · 前进锁定" : ""
        return "\(directionMode.rawValue) · \(triggerMode.rawValue) · \(numbers)\(lock)"
    }
}

extension ControlStickConfig {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        directionMode = container.zlValue(.directionMode, StickDirectionMode.eight)
        size = container.zlValue(.size, 1.0)
        deadZone = container.zlValue(.deadZone, 0.12)
        lockThreshold = container.zlValue(.lockThreshold, 0.70)
        forwardLock = container.zlValue(.forwardLock, false)
        triggerMode = container.zlValue(.triggerMode, StickTriggerMode.drag)
    }
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
    /// ZL2 的按键事件值（GLFW 按键名，例如 GLFW_KEY_ESCAPE）
    var keyEvent: String = ""
    var visibleScene: VisibleScene = .always
    var lockable: Bool = false
    /// 文本对齐 / 粗体 / 斜体 / 下划线（对齐 ZL2 的 textAlignment / textBold / textItalic / textUnderline）
    var textAlignment: ControlTextAlignment = .left
    var textBold: Bool = false
    var textItalic: Bool = false
    var textUnderline: Bool = false
    /// 滑动联动（对齐 ZL2 的 isSwipple）
    var isSwipple: Bool = false
    /// 允许触摸事件向下穿透（对齐 ZL2 的 isPenetrable）
    var isPenetrable: Bool = false
    /// 开关式按下状态（对齐 ZL2 的 isToggleable）
    var isToggleable: Bool = false
    /// 外观样式
    var appearance: ControlAppearance = .default
    /// 摇杆详细配置（仅 kind == .stick 有效）
    var stick: ControlStickConfig = .default

    /// 兼容旧字段：不透明度映射到外观的正常态
    var opacity: Double {
        get { appearance.normalOpacity }
        set { appearance.normalOpacity = newValue }
    }

    /// 兼容旧字段：圆角映射到外观四角
    var cornerRadius: Double {
        get { appearance.corners.topLeft }
        set { appearance.corners = ControlCorners.uniform(newValue) }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, label, x, y, width, height, action, textToSend
        case visibleScene, lockable, appearance, stick
        case textAlignment, textBold, textItalic, textUnderline
        case isSwipple, isPenetrable, isToggleable
        case legacyOpacity = "opacity"
        case legacyCornerRadius = "cornerRadius"
    }

    static let defaults: [ControlItem] = [
        .init(kind: .button, label: "W", x: 0.16, y: 0.70, width: 0.07, height: 0.07),
        .init(kind: .button, label: "A", x: 0.08, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "S", x: 0.16, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "D", x: 0.24, y: 0.82, width: 0.07, height: 0.07),
        .init(kind: .button, label: "跳", x: 0.88, y: 0.80, width: 0.08, height: 0.08),
        .init(kind: .button, label: "蹲", x: 0.74, y: 0.88, width: 0.08, height: 0.07),
        .init(kind: .button, label: "背包", x: 0.90, y: 0.56, width: 0.08, height: 0.07),
        .init(kind: .stick, label: "摇杆", x: 0.42, y: 0.78, width: 0.14, height: 0.20)
    ]
}

extension ControlItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.zlValue(.id, UUID())
        kind = container.zlValue(.kind, ControlKind.button)
        label = container.zlValue(.label, "按键")
        x = container.zlValue(.x, 0.5)
        y = container.zlValue(.y, 0.5)
        width = container.zlValue(.width, 0.08)
        height = container.zlValue(.height, 0.05)
        action = container.zlValue(.action, ControlAction.toggleMenu)
        textToSend = container.zlValue(.textToSend, "")
        visibleScene = container.zlValue(.visibleScene, VisibleScene.always)
        lockable = container.zlValue(.lockable, false)
        textAlignment = container.zlValue(.textAlignment, ControlTextAlignment.left)
        textBold = container.zlValue(.textBold, false)
        textItalic = container.zlValue(.textItalic, false)
        textUnderline = container.zlValue(.textUnderline, false)
        isSwipple = container.zlValue(.isSwipple, false)
        isPenetrable = container.zlValue(.isPenetrable, false)
        isToggleable = container.zlValue(.isToggleable, false)

        // 新的外观字段优先；缺失时用旧的 opacity / cornerRadius 迁移
        var style = container.zlValue(.appearance, ControlAppearance.default)
        if !container.contains(.appearance) {
            style.normalOpacity = container.zlValue(.legacyOpacity, style.normalOpacity)
            let legacyCorners = container.zlValue(.legacyCornerRadius, style.corners.topLeft)
            style.corners = ControlCorners.uniform(legacyCorners)
        }
        appearance = style
        stick = container.zlValue(.stick, ControlStickConfig.default)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(action, forKey: .action)
        try container.encode(textToSend, forKey: .textToSend)
        try container.encode(visibleScene, forKey: .visibleScene)
        try container.encode(lockable, forKey: .lockable)
        try container.encode(textAlignment, forKey: .textAlignment)
        try container.encode(textBold, forKey: .textBold)
        try container.encode(textItalic, forKey: .textItalic)
        try container.encode(textUnderline, forKey: .textUnderline)
        try container.encode(isSwipple, forKey: .isSwipple)
        try container.encode(isPenetrable, forKey: .isPenetrable)
        try container.encode(isToggleable, forKey: .isToggleable)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(stick, forKey: .stick)
        // 旧版本兼容镜像
        try container.encode(appearance.normalOpacity, forKey: .legacyOpacity)
        try container.encode(appearance.corners.topLeft, forKey: .legacyCornerRadius)
    }
}

// MARK: - 控件层
struct ControlLayer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [ControlItem]
    /// 默认隐藏（进入游戏时不显示）
    var hiddenByDefault = false
    /// 实体鼠标操作时隐藏
    var hiddenByMouse = false
    /// 手柄操作时隐藏
    var hiddenByGamepad = false
    /// 这一层的可见场景（对齐 ZL2 的 ControlLayer.visibilityType）
    var visibleScene: VisibleScene = .always
    /// 合并控件到下层（运行时与下方控件层合并）
    var mergeIntoLowerLayer = false

    enum CodingKeys: String, CodingKey {
        case id, name, items, hiddenByDefault, hiddenByMouse, hiddenByGamepad
        case visibleScene, mergeIntoLowerLayer
    }

    /// 已开启的属性数量（列表里做标记用）
    var enabledPropertyCount: Int {
        var count = 0
        if hiddenByDefault { count += 1 }
        if hiddenByMouse { count += 1 }
        if hiddenByGamepad { count += 1 }
        if mergeIntoLowerLayer { count += 1 }
        return count
    }
}

extension ControlLayer {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.zlValue(.id, UUID())
        name = container.zlValue(.name, "控件层")
        items = container.zlValue(.items, [ControlItem]())
        hiddenByDefault = container.zlValue(.hiddenByDefault, false)
        hiddenByMouse = container.zlValue(.hiddenByMouse, false)
        hiddenByGamepad = container.zlValue(.hiddenByGamepad, false)
        visibleScene = container.zlValue(.visibleScene, VisibleScene.always)
        mergeIntoLowerLayer = container.zlValue(.mergeIntoLowerLayer, false)
    }
}

// MARK: - 布局导入错误（中文提示）
enum ControlLayoutError: LocalizedError {
    case emptyData
    case notJSONObject
    case noLayers
    case invalidLayer(String)
    case invalidControl(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "导入失败：数据为空，请先粘贴布局 JSON。"
        case .notJSONObject:
            return "导入失败：这不是 JSON 对象，布局应该是 { ... } 结构。"
        case .noLayers:
            return "导入失败：布局里没有任何控件层。"
        case .invalidLayer(let message):
            return "导入失败：控件层有问题 - \(message)"
        case .invalidControl(let message):
            return "导入失败：控件有问题 - \(message)"
        case .decodeFailed(let message):
            return "导入失败：格式不正确（\(message)）"
        }
    }
}

// MARK: - 布局文档
struct ControlLayoutDoc: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "我的布局"
    var author = ""
    var version = "1.0"
    var desc = ""
    var layers: [ControlLayer]
    /// 当前布局已加入的样式（导出时一起保存）
    var styleVault: [ControlAppearance] = []

    init(id: UUID = UUID(),
         name: String = "我的布局",
         author: String = "",
         version: String = "1.0",
         desc: String = "",
         layers: [ControlLayer],
         styleVault: [ControlAppearance] = []) {
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.desc = desc
        self.layers = layers
        self.styleVault = styleVault
    }

    enum CodingKeys: String, CodingKey {
        case id, name, author, version, desc, layers, styleVault
    }

    var totalItemCount: Int {
        layers.reduce(0) { $0 + $1.items.count }
    }

    static var `default`: ControlLayoutDoc {
        ControlLayoutDoc(name: "新的控制布局", layers: [
            ControlLayer(name: "基础", items: ControlItem.defaults)
        ])
    }
}

extension ControlLayoutDoc {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.zlValue(.id, UUID())
        name = container.zlValue(.name, "我的布局")
        author = container.zlValue(.author, "")
        version = container.zlValue(.version, "1.0")
        desc = container.zlValue(.desc, "")
        layers = container.zlValue(.layers, [ControlLayer]())
        styleVault = container.zlValue(.styleVault, [ControlAppearance]())
    }

    // MARK: 导出

    /// 编码为 JSON（Codable）
    func exportJSON(pretty: Bool = true) -> Data {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        if let data = try? encoder.encode(self) {
            return data
        }
        return Data()
    }

    /// 导出为可读文本
    func exportJSONText(pretty: Bool = true) -> String {
        String(data: exportJSON(pretty: pretty), encoding: .utf8) ?? ""
    }

    // MARK: 导入

    /// 从 JSON 数据导入（覆盖当前文档）
    mutating func importJSON(_ data: Data) throws {
        self = try ControlLayoutDoc.loadJSON(data)
    }

    /// 解析并校验 JSON
    static func loadJSON(_ data: Data) throws -> ControlLayoutDoc {
        guard !data.isEmpty else { throw ControlLayoutError.emptyData }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ControlLayoutError.decodeFailed("不是 UTF-8 文本")
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else { throw ControlLayoutError.notJSONObject }

        let decoder = JSONDecoder()
        let doc: ControlLayoutDoc
        do {
            doc = try decoder.decode(ControlLayoutDoc.self, from: data)
        } catch let error as DecodingError {
            throw ControlLayoutError.decodeFailed(describe(error))
        } catch {
            throw ControlLayoutError.decodeFailed(error.localizedDescription)
        }

        guard !doc.layers.isEmpty else { throw ControlLayoutError.noLayers }
        for (layerIndex, layer) in doc.layers.enumerated() {
            let layerNumber = layerIndex + 1
            if layer.name.trimmingCharacters(in: .whitespaces).isEmpty {
                throw ControlLayoutError.invalidLayer("第 \(layerNumber) 个控件层没有名称")
            }
            for (itemIndex, item) in layer.items.enumerated() {
                let itemNumber = itemIndex + 1
                if item.x < 0 || item.x > 1 || item.y < 0 || item.y > 1 {
                    throw ControlLayoutError.invalidControl("第 \(layerNumber) 层第 \(itemNumber) 个控件的坐标超出 0~1 范围")
                }
                if item.width <= 0 || item.height <= 0 {
                    throw ControlLayoutError.invalidControl("第 \(layerNumber) 层第 \(itemNumber) 个控件的尺寸必须大于 0")
                }
            }
        }
        return doc
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "缺少字段「\(key.stringValue)」"
        case .typeMismatch(_, let context):
            return "字段类型不对：\(context.debugDescription)"
        case .valueNotFound(_, let context):
            return "字段缺少取值：\(context.debugDescription)"
        case .dataCorrupted(let context):
            return "数据无法解析：\(context.debugDescription)"
        @unknown default:
            return "未知的解析错误"
        }
    }
}

// MARK: - 样式收藏柜（跨布局保存到 UserDefaults）
final class ControlStyleVault: ObservableObject {
    static let shared = ControlStyleVault()
    private static let storageKey = "zl.controls.styleVault"

    @Published private(set) var styles: [ControlAppearance] = []

    init() {
        load()
    }

    func add(_ style: ControlAppearance) {
        if let index = styles.firstIndex(where: { $0.name == style.name }) {
            var updated = style
            updated.id = styles[index].id
            styles[index] = updated
        } else {
            styles.append(style)
        }
        persist()
    }

    func remove(_ id: UUID) {
        styles.removeAll { $0.id == id }
        persist()
    }

    func resetToPresets() {
        styles = ControlAppearance.presets
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ControlAppearance].self, from: data),
              !decoded.isEmpty else {
            styles = ControlAppearance.presets
            return
        }
        styles = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(styles) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// 从 ZLLayoutStore 加载布局（真正把用户编辑的内容读回来）
    private func loadLayout() {
        guard !loaded else { return }
        loaded = true
        guard let data = ZLLayoutStore.loadRaw(name: layoutName),
              let decoded = try? JSONDecoder().decode(ControlLayoutDoc.self, from: data) else {
            return
        }
        doc = decoded
        if layerIndex >= doc.layers.count { layerIndex = 0 }
    }

    /// 存回 ZLLayoutStore（编辑结果不再丢失）
    private func saveLayout() {
        guard loaded else { return }
        if let data = try? JSONEncoder().encode(doc) {
            ZLLayoutStore.saveRaw(name: layoutName, data: data)
        }
    }
}

// MARK: - 编辑器弹窗（属性 / 样式柜 / 导入导出 / 层属性）
private enum ControlEditorSheet: String, Identifiable {
    case inspector, styles, transfer, layer
    var id: String { rawValue }
}

// MARK: - 编辑器
struct ControlEditorScreen: View {
    var onBack: () -> Void = {}
    var onHome: () -> Void = {}
    /// 要编辑的布局名（对应 ZLLayoutStore 里的文件）
    var layoutName: String = "默认布局"

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var vault = ControlStyleVault.shared

    @State private var doc = ControlLayoutDoc.default
    @State private var loaded = false
    @State private var layerIndex = 0
    @State private var selected: UUID? = nil
    @State private var editing = false
    @State private var showLayerList = false
    @State private var previewMode = 0   // 0 游戏内 1 游戏外
    @State private var snap = true
    @State private var showLayoutInfo = false
    @State private var toast: String? = nil
    @State private var sheet: ControlEditorSheet? = nil

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
        .task(id: "editor-load") { loadLayout() }
        .onDisappear { saveLayout() }
        .sheet(item: $sheet, onDismiss: { selected = nil }) { which in
            switch which {
            case .inspector:
                if let item = selectedItem {
                    inspectorSheet(item)
                }
            case .styles:
                stylePanelSheet
            case .transfer:
                transferSheet
            case .layer:
                layerSettingsSheet
            }
        }
    }

    // MARK: 数据辅助

    private var currentLayer: ControlLayer? {
        guard doc.layers.indices.contains(layerIndex) else { return nil }
        return doc.layers[layerIndex]
    }

    private var currentItems: [ControlItem] {
        guard let layer = currentLayer else { return [] }
        return layer.items
    }

    private var selectedItem: ControlItem? {
        guard let id = selected else { return nil }
        return currentItems.first { $0.id == id }
    }

    // 顶部工具栏
    private var topBar: some View {
        HStack(spacing: 8) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left").foregroundStyle(ZLTheme.textPrimary)
                    .frame(width: 40, height: 36)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(doc.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            chipButton("布局信息", icon: "info.circle", highlighted: showLayoutInfo) {
                showLayoutInfo = true
            }

            chipButton("控件层", icon: "square.stack.3d.up.fill", highlighted: showLayerList) {
                showLayerList.toggle()
            }
            chipButton("吸附", icon: "grid", highlighted: snap) {
                snap.toggle()
            }
            chipButton("样式", icon: "paintpalette.fill", highlighted: !doc.styleVault.isEmpty) {
                sheet = .styles
            }

            Button {
                editing.toggle()
            } label: {
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
                Button("样式收藏柜") { sheet = .styles }
                Button("导出 / 导入 JSON") { sheet = .transfer }
                Button("新增控件层") { addLayer() }
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

    private func chipButton(_ title: String, icon: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12))
                .foregroundStyle(highlighted ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                .padding(.horizontal, 12).frame(height: 34)
                .background(highlighted ? ZLTheme.primarySoft : ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 左侧控件层列表

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("控件层")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZLTheme.textSecond)
                Spacer()
                Button { addLayer() } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(ZLTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(doc.layers.indices, id: \.self) { index in
                        layerRow(index)
                    }
                }
            }

            Text("齿轮可配置层属性")
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
                .padding(.horizontal, 10)
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .frame(width: 178)
        .background(ZLTheme.surface.opacity(0.5))
    }

    private func layerRow(_ index: Int) -> some View {
        HStack(spacing: 4) {
            Button { layerIndex = index } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 11))
                    Text(doc.layers[index].name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    if doc.layers[index].hiddenByDefault {
                        Image(systemName: "eye.slash.fill").font(.system(size: 9))
                    }
                    if doc.layers[index].enabledPropertyCount > 0 {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 9))
                    }
                    Spacer(minLength: 0)
                    Text("\(doc.layers[index].items.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                }
                .foregroundStyle(layerIndex == index ? ZLTheme.primaryDeep : ZLTheme.textSecond)
                .padding(.horizontal, 8).frame(height: 36)
                .background(layerIndex == index ? ZLTheme.primarySoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                layerIndex = index
                sheet = .layer
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 26, height: 30)
                    .background(ZLTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    // MARK: 画布

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                (previewMode == 0 ? Color(hex: 0x3A3F2E) : ZLTheme.background)
                    .ignoresSafeArea()

                ForEach(currentItems) { item in
                    controlView(item, in: geo.size)
                }

                // 悬浮提示条
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

                        if let toast {
                            Text(toast)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ZLTheme.textOnGold)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(ZLTheme.success)
                                .clipShape(Capsule())
                        } else {
                            Text(editing ? "点按控件编辑属性 · 拖动改位置 · 长按可复制" : "点右上角「编辑」开始调整布局")
                                .font(.system(size: 10))
                                .foregroundStyle(ZLTheme.textSecond)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func controlView(_ item: ControlItem, in size: CGSize) -> some View {
        let appearance = item.appearance.resolved(dark: colorScheme == .dark)
        let width = max(38, item.width * size.width)
        let height = max(30, item.height * size.height)
        let shape = ControlCornerShape(corners: appearance.corners)
        let isSelected = selected == item.id
        let border = CGFloat(max(0, appearance.borderWidth))

        return ZStack {
            switch item.kind {
            case .stick:
                stickView(item, appearance: appearance, width: width, height: height, selected: isSelected)
            case .text:
                Text(displayText(of: item))
                    .font(.system(size: 13))
                    .foregroundStyle(appearance.content)
                    .padding(.horizontal, 10)
                    .frame(minWidth: width, minHeight: height)
                    .background(shape.fill(appearance.background))
                    .overlay(shape.stroke(appearance.borderColor, lineWidth: border))
                    .overlay(shape.stroke(isSelected ? ZLTheme.primary : Color.clear, lineWidth: 2))
            case .button:
                Text(item.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(appearance.content)
                    .frame(width: width, height: height)
                    .background(shape.fill(appearance.background))
                    .overlay(shape.stroke(appearance.borderColor, lineWidth: border))
                    .overlay(shape.stroke(isSelected ? ZLTheme.primary : Color.clear, lineWidth: 2))
            }
        }
        .opacity(appearance.opacity)
        .position(x: item.x * size.width, y: item.y * size.height)
        .contentShape(Rectangle())
        .contextMenu {
            Button("打开属性") {
                selected = item.id
                sheet = .inspector
            }
            Button("复制到当前层") { copyItem(item, toLayer: layerIndex) }
            if doc.layers.count > 1 {
                Menu("复制到其他控件层") {
                    ForEach(doc.layers.indices, id: \.self) { index in
                        Button(doc.layers[index].name) { copyItem(item, toLayer: index) }
                    }
                }
            }
            Divider()
            Button("删除控件", role: .destructive) { deleteItem(item) }
        }
        .onTapGesture {
            if editing {
                selected = item.id
                sheet = .inspector
            }
        }
        .gesture(
            editing ? DragGesture().onChanged { value in
                dragMove(item, x: value.location.x, y: value.location.y, in: size)
            } : nil
        )
    }

    private func stickView(_ item: ControlItem,
                           appearance: ResolvedControlAppearance,
                           width: CGFloat,
                           height: CGFloat,
                           selected: Bool) -> some View {
        let diameter = max(56, min(width, height) * CGFloat(item.stick.size))
        let border = CGFloat(max(0, appearance.borderWidth))
        let ticks: [Double] = (0..<item.stick.directionMode.tickCount).map { index in
            Double(index) * 360.0 / Double(item.stick.directionMode.tickCount)
        }
        return ZStack {
            Circle()
                .fill(appearance.background)
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(appearance.borderColor, lineWidth: border)
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(appearance.content.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: diameter * CGFloat(item.stick.deadZone) * 2,
                       height: diameter * CGFloat(item.stick.deadZone) * 2)
            ForEach(ticks, id: \.self) { angle in
                Capsule()
                    .fill(appearance.content.opacity(0.35))
                    .frame(width: 2, height: 6)
                    .offset(y: -(diameter / 2 - 8))
                    .rotationEffect(.degrees(angle))
            }
            Circle()
                .fill(appearance.content.opacity(0.85))
                .frame(width: diameter * 0.3, height: diameter * 0.3)
            if item.stick.forwardLock {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(appearance.content.opacity(0.7))
                    .offset(y: -diameter * 0.22)
            }
        }
        .overlay(
            Circle()
                .stroke(selected ? ZLTheme.primary : Color.clear, lineWidth: 2)
                .frame(width: diameter, height: diameter)
        )
    }

    private func displayText(of item: ControlItem) -> String {
        if !item.textToSend.isEmpty { return item.textToSend }
        if !item.label.isEmpty { return item.label }
        return "文本"
    }

    // MARK: 编辑动作

    private func dragMove(_ item: ControlItem, x: CGFloat, y: CGFloat, in size: CGSize) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        guard let index = doc.layers[layerIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        guard size.width > 0, size.height > 0 else { return }
        var newX = min(max(x / size.width, 0.03), 0.97)
        var newY = min(max(y / size.height, 0.03), 0.97)
        if snap {
            newX = (newX * 50).rounded() / 50
            newY = (newY * 50).rounded() / 50
        }
        doc.layers[layerIndex].items[index].x = newX
        doc.layers[layerIndex].items[index].y = newY
    }

    private func addItem(_ kind: ControlKind) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        var item = ControlItem(kind: kind,
                               label: kind == .button ? "按键" : kind.rawValue,
                               x: 0.5, y: 0.5,
                               width: kind == .stick ? 0.14 : 0.08,
                               height: kind == .stick ? 0.20 : 0.06)
        item.appearance = doc.styleVault.first ?? ControlAppearance.default
        doc.layers[layerIndex].items.append(item)
        selected = item.id
        sheet = .inspector
        flash("已添加\(kind.rawValue)")
    }

    private func deleteItem(_ item: ControlItem) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        doc.layers[layerIndex].items.removeAll { $0.id == item.id }
        if selected == item.id { selected = nil }
        flash("已删除控件")
    }

    /// 复制控件：到当前层 / 到指定层
    private func copyItem(_ item: ControlItem, toLayer target: Int) {
        guard doc.layers.indices.contains(target) else { return }
        var duplicate = item
        duplicate.id = UUID()
        duplicate.x = min(max(item.x + 0.03, 0.03), 0.97)
        duplicate.y = min(max(item.y + 0.03, 0.03), 0.97)
        doc.layers[target].items.append(duplicate)
        flash("已复制到「\(doc.layers[target].name)」")
    }

    private func apply(_ updated: ControlItem) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        guard let index = doc.layers[layerIndex].items.firstIndex(where: { $0.id == updated.id }) else { return }
        doc.layers[layerIndex].items[index] = updated
    }

    private func addLayer() {
        doc.layers.append(ControlLayer(name: "控件层 \(doc.layers.count + 1)", items: []))
        layerIndex = doc.layers.count - 1
        selected = nil
        flash("已新增控件层")
    }

    private func deleteCurrentLayer() {
        guard doc.layers.count > 1 else {
            flash("至少要保留一个控件层")
            return
        }
        doc.layers.remove(at: layerIndex)
        layerIndex = max(0, min(layerIndex, doc.layers.count - 1))
        selected = nil
        sheet = nil
        flash("已删除控件层")
    }

    private func mergeCurrentLayerDown() {
        guard doc.layers.indices.contains(layerIndex), layerIndex > 0 else {
            flash("最底层的控件层无法向下合并")
            return
        }
        let items = doc.layers[layerIndex].items
        doc.layers[layerIndex - 1].items.append(contentsOf: items)
        doc.layers.remove(at: layerIndex)
        layerIndex -= 1
        selected = nil
        sheet = nil
        flash("已合并到下层")
    }

    // MARK: 样式动作

    private func addToVault(_ style: ControlAppearance) {
        vault.add(style)
        flash("已加入样式收藏柜")
    }

    private func addStyleToLayout(_ style: ControlAppearance) {
        if doc.styleVault.contains(where: { $0.name == style.name }) {
            flash("该样式已在当前布局中")
            return
        }
        doc.styleVault.append(style)
        flash("已加入当前布局")
    }

    private func removeStyleFromLayout(_ id: UUID) {
        doc.styleVault.removeAll { $0.id == id }
        flash("已从当前布局移除样式")
    }

    private func applyStyle(_ style: ControlAppearance) {
        guard doc.layers.indices.contains(layerIndex) else { return }
        if let id = selected,
           let index = doc.layers[layerIndex].items.firstIndex(where: { $0.id == id }) {
            doc.layers[layerIndex].items[index].appearance = style
            flash("已应用到选中控件")
        } else {
            for index in doc.layers[layerIndex].items.indices {
                doc.layers[layerIndex].items[index].appearance = style
            }
            flash("已应用到当前层全部控件")
        }
    }

    private func importDocument(_ imported: ControlLayoutDoc) {
        doc = imported
        layerIndex = 0
        selected = nil
        sheet = nil
        flash("导入成功：\(imported.layers.count) 个控件层")
    }

    private func flash(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            self.toast = nil
        }
    }

    // MARK: 弹窗

    @ViewBuilder
    private func inspectorSheet(_ item: ControlItem) -> some View {
        ControlInspector(
            item: item,
            layerNames: doc.layers.map { $0.name },
            currentLayer: layerIndex,
            layoutStyles: doc.styleVault,
            onCopyToLayer: { source, target in copyItem(source, toLayer: target) },
            onAddToVault: { style in addToVault(style) },
            onChange: { updated in apply(updated) }
        )
        .id(item.id)
    }

    @ViewBuilder
    private var stylePanelSheet: some View {
        ControlStylePanel(
            layoutStyles: doc.styleVault,
            vaultStyles: vault.styles,
            hasSelection: selectedItem != nil,
            onAddToLayout: { style in addStyleToLayout(style) },
            onApplyToSelection: { style in applyStyle(style) },
            onRemoveFromLayout: { id in removeStyleFromLayout(id) },
            onRemoveFromVault: { id in vault.remove(id) },
            onResetVault: { vault.resetToPresets() },
            onClose: { sheet = nil }
        )
    }

    @ViewBuilder
    private var transferSheet: some View {
        ControlLayoutTransferSheet(
            jsonText: doc.exportJSONText(),
            onImport: { imported in importDocument(imported) },
            onClose: { sheet = nil }
        )
    }

    @ViewBuilder
    private var layerSettingsSheet: some View {
        if doc.layers.indices.contains(layerIndex) {
            ControlLayerSettingsSheet(
                layer: Binding<ControlLayer>(
                    get: {
                        if doc.layers.indices.contains(layerIndex) {
                            return doc.layers[layerIndex]
                        }
                        return ControlLayer(name: "控件层", items: [ControlItem]())
                    },
                    set: { newValue in
                        if doc.layers.indices.contains(layerIndex) {
                            doc.layers[layerIndex] = newValue
                        }
                    }
                ),
                layerCount: doc.layers.count,
                isBottomLayer: layerIndex == 0,
                onMergeDown: { mergeCurrentLayerDown() },
                onDelete: { deleteCurrentLayer() },
                onClose: { sheet = nil }
            )
        }
    }
}

// MARK: - 属性检查器
struct ControlInspector: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: ControlItem
    var layerNames: [String] = []
    var currentLayer: Int = 0
    var layoutStyles: [ControlAppearance] = []
    var onCopyToLayer: ((ControlItem, Int) -> Void)? = nil
    var onAddToVault: ((ControlAppearance) -> Void)? = nil
    var onChange: (ControlItem) -> Void

    @State private var addedToVault = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    basicCard
                    actionCard
                    geometryCard
                    if item.kind == .stick {
                        stickCard
                    }
                    appearanceCard
                    copyCard
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.vertical, ZLTheme.screenPadding)
            }
            .background(ZLTheme.background.ignoresSafeArea())
            .navigationTitle("控件属性")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onChange(item)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: 卡片

    private func inspectorCard<Content: View>(_ title: String,
                                              icon: String,
                                              @ViewBuilder content: @escaping () -> Content) -> some View {
        ZLCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.primaryDeep)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                }
                content()
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ZLTheme.textSecond)
    }

    private func sliderRow(_ title: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           format: String = "%.2f") -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundStyle(ZLTheme.textSecond)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
            }
            Slider(value: value, in: range)
                .tint(ZLTheme.primary)
        }
    }

    private func toggleRow(_ title: String, desc: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ZLTheme.primary)
        }
    }

    private func smallMenuLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12))
            .foregroundStyle(ZLTheme.primaryDeep)
            .padding(.horizontal, 12).frame(height: 30)
            .background(ZLTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: 基本信息

    private var basicCard: some View {
        inspectorCard("基本信息", icon: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 10) {
                rowLabel("名称")
                ZLTextField(placeholder: "控件名称", text: $item.label)

                rowLabel("类型")
                Picker("类型", selection: $item.kind) {
                    ForEach(ControlKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                rowLabel("可见场景")
                Picker("可见场景", selection: $item.visibleScene) {
                    ForEach(VisibleScene.allCases) { scene in
                        Text(scene.rawValue).tag(scene)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("拖动后锁定位置")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.textSecond)
                    Spacer()
                    Toggle("", isOn: $item.lockable)
                        .labelsHidden()
                        .tint(ZLTheme.primary)
                }
            }
        }
    }

    // MARK: 点击事件

    private var actionCard: some View {
        inspectorCard("点击事件", icon: "hand.tap.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("动作", selection: $item.action) {
                    ForEach(ControlAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
                .pickerStyle(.menu)
                .tint(ZLTheme.primaryDeep)

                if item.action == .sendText {
                    rowLabel("要发送的文本")
                    ZLTextField(placeholder: "例如 /gamemode creative", text: $item.textToSend)
                }
            }
        }
    }

    // MARK: 坐标与尺寸

    private var geometryCard: some View {
        inspectorCard("坐标与尺寸", icon: "arrow.up.left.and.arrow.down.right") {
            VStack(alignment: .leading, spacing: 8) {
                sliderRow("横坐标 X", value: $item.x, range: 0...1)
                sliderRow("纵坐标 Y", value: $item.y, range: 0...1)
                sliderRow("宽度", value: $item.width, range: 0.03...0.4)
                sliderRow("高度", value: $item.height, range: 0.02...0.4)
            }
        }
    }

    // MARK: 摇杆详细配置

    private var stickCard: some View {
        inspectorCard("摇杆配置", icon: "circle.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                rowLabel("方向事件")
                Picker("方向事件", selection: $item.stick.directionMode) {
                    ForEach(StickDirectionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                rowLabel("操控方式")
                Picker("操控方式", selection: $item.stick.triggerMode) {
                    ForEach(StickTriggerMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                sliderRow("摇杆大小", value: $item.stick.size, range: 0.6...1.8, format: "%.1f×")
                sliderRow("死区范围", value: $item.stick.deadZone, range: 0...0.6)
                sliderRow("锁定阈值", value: $item.stick.lockThreshold, range: 0.1...1.0)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("前进锁定")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                        Text("推到上限后保持该方向，松开才复位")
                            .font(.system(size: 11))
                            .foregroundStyle(ZLTheme.textSecond)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: $item.stick.forwardLock)
                        .labelsHidden()
                        .tint(ZLTheme.primary)
                }

                Text(item.stick.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 外观样式

    private var appearanceCard: some View {
        inspectorCard("外观样式", icon: "paintpalette.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(item.appearance.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(ZLTheme.primarySoft)
                        .clipShape(Capsule())
                    Spacer()
                    if !layoutStyles.isEmpty {
                        Menu {
                            ForEach(layoutStyles) { style in
                                Button(style.name) { item.appearance = style }
                            }
                        } label: {
                            smallMenuLabel("布局样式", icon: "square.stack.3d.up.fill")
                        }
                    }
                }

                rowLabel("样式名称")
                ZLTextField(placeholder: "样式名称", text: $item.appearance.name)

                ControlAppearanceEditor(appearance: $item.appearance)

                Button {
                    onAddToVault?(item.appearance)
                    addedToVault = true
                } label: {
                    Label(addedToVault ? "已加入样式收藏柜" : "把当前外观加入收藏柜",
                          systemImage: addedToVault ? "checkmark.circle.fill" : "star.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(addedToVault ? ZLTheme.success : ZLTheme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(addedToVault ? ZLTheme.surfaceAlt : ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 控件复制

    private var copyCard: some View {
        inspectorCard("控件复制", icon: "doc.on.doc.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    onCopyToLayer?(item, currentLayer)
                } label: {
                    Label("复制到当前层", systemImage: "plus.square.on.square")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZLTheme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                if layerNames.count > 1 {
                    Menu {
                        ForEach(layerNames.indices, id: \.self) { index in
                            Button(layerNames[index]) {
                                onCopyToLayer?(item, index)
                            }
                        }
                    } label: {
                        Label("复制到指定控件层", systemImage: "square.stack.3d.up.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ZLTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(ZLTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                Text("复制会生成一个新控件，坐标自动偏移一点，不会覆盖原控件。")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 外观编辑器
struct ControlAppearanceEditor: View {
    @Binding var appearance: ControlAppearance
    @State private var previewPressed = false
    @Environment(\.colorScheme) private var colorScheme

    private var cornerLabels: [String] { ["左上", "右上", "左下", "右下"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview
            opacityBlock
            colorBlock
            borderBlock
            cornerBlock
            optionBlock
        }
    }

    // MARK: 预览

    private var preview: some View {
        let resolved = appearance.resolved(dark: colorScheme == .dark)
        let shape = ControlCornerShape(corners: resolved.corners)
        let opacity = previewPressed ? resolved.pressedOpacity : resolved.opacity
        return HStack(spacing: 14) {
            ZStack {
                shape
                    .fill(resolved.background)
                    .frame(width: 92, height: 46)
                shape
                    .stroke(resolved.borderColor,
                            lineWidth: CGFloat(max(0, resolved.borderWidth)))
                    .frame(width: 92, height: 46)
                Text(appearance.name.isEmpty ? "样式预览" : appearance.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(resolved.content)
                    .lineLimit(1)
            }
            .opacity(opacity)

            VStack(alignment: .leading, spacing: 6) {
                Text(previewPressed ? "按下态" : "正常态")
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                Toggle("预览按下态", isOn: $previewPressed)
                    .labelsHidden()
                    .tint(ZLTheme.primary)
            }

            Spacer(minLength: 0)
        }
        .animation(previewAnimation, value: previewPressed)
    }

    private var previewAnimation: Animation? {
        appearance.animated ? Animation.easeInOut(duration: 0.15) : nil
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ZLTheme.textSecond)
    }

    // MARK: 不透明度

    private var opacityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("不透明度")
            opacityLine("正常态", value: $appearance.normalOpacity)
            opacityLine("按下态", value: $appearance.pressedOpacity)
        }
    }

    private func opacityLine(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: 0.1...1.0)
                .tint(ZLTheme.primary)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 34, alignment: .trailing)
        }
    }

    // MARK: 颜色

    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("颜色")
            colorRow("背景色", hex: $appearance.backgroundHex)
            colorRow("内容色", hex: $appearance.contentHex)
            colorRow("边框色", hex: $appearance.borderHex)
        }
    }

    private func colorRow(_ title: String, hex: Binding<UInt32>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                Circle()
                    .fill(Color(hex: hex.wrappedValue))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(ZLTheme.stroke, lineWidth: 0.5))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ControlColorPalette.options) { option in
                        ControlColorSwatch(hex: option.hex,
                                           selected: hex.wrappedValue == option.hex) {
                            hex.wrappedValue = option.hex
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: 边框 / 圆角

    private var borderBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("边框粗细")
            HStack(spacing: 8) {
                Slider(value: $appearance.borderWidth, in: 0...6)
                    .tint(ZLTheme.primary)
                Text(String(format: "%.1f", appearance.borderWidth))
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    private var cornerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                header("圆角（四个角可分别设置）")
                Spacer()
                Button("统一") {
                    appearance.corners = ControlCorners.uniform(appearance.corners.topLeft)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ZLTheme.primaryDeep)
                .buttonStyle(.plain)
            }
            cornerLine(0)
            cornerLine(1)
            cornerLine(2)
            cornerLine(3)
        }
    }

    private func cornerLine(_ index: Int) -> some View {
        HStack(spacing: 8) {
            Text(cornerLabels[index])
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 34, alignment: .leading)
            Slider(value: cornerBinding(index), in: 0...40)
                .tint(ZLTheme.primary)
            Text(String(format: "%.0f", appearance.corners.value(at: index)))
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
                .frame(width: 26, alignment: .trailing)
        }
    }

    private func cornerBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { appearance.corners.value(at: index) },
            set: { newValue in
                var corners = appearance.corners
                corners.setValue(newValue, at: index)
                appearance.corners = corners
            }
        )
    }

    // MARK: 动画与暗色

    private var optionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("动画与暗色主题")
            toggleLine("启用过渡动画", isOn: $appearance.animated)
            toggleLine("暗色主题使用独立配色", isOn: $appearance.separateDark)

            if appearance.separateDark {
                colorRow("暗色背景", hex: $appearance.darkBackgroundHex)
                colorRow("暗色内容", hex: $appearance.darkContentHex)
                colorRow("暗色边框", hex: $appearance.darkBorderHex)
                opacityLine("暗色正常态", value: $appearance.darkNormalOpacity)
                opacityLine("暗色按下态", value: $appearance.darkPressedOpacity)
            }
        }
    }

    private func toggleLine(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(ZLTheme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ZLTheme.primary)
        }
    }
}

// MARK: - 颜色色块
struct ControlColorSwatch: View {
    let hex: UInt32
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(ZLTheme.stroke, lineWidth: 0.5))
                .overlay(
                    Circle()
                        .stroke(selected ? ZLTheme.primaryDeep : Color.clear, lineWidth: 2)
                        .padding(-3)
                )
                .padding(3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 样式收藏柜面板
struct ControlStylePanel: View {
    @Environment(\.dismiss) private var dismiss
    var layoutStyles: [ControlAppearance] = []
    var vaultStyles: [ControlAppearance] = []
    var hasSelection: Bool = false
    var onAddToLayout: (ControlAppearance) -> Void = { _ in }
    var onApplyToSelection: (ControlAppearance) -> Void = { _ in }
    var onRemoveFromLayout: (UUID) -> Void = { _ in }
    var onRemoveFromVault: (UUID) -> Void = { _ in }
    var onResetVault: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ZLTheme.cardGap) {
                    layoutSection
                    vaultSection
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.vertical, ZLTheme.screenPadding)
            }
            .background(ZLTheme.background.ignoresSafeArea())
            .navigationTitle("样式收藏柜")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }

    // 当前布局样式
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("当前布局样式",
                          subtitle: hasSelection ? "应用样式会覆盖选中控件的外观" : "未选中控件时将应用到当前层全部控件")
            if layoutStyles.isEmpty {
                emptyHint("当前布局还没有样式。可以把收藏柜里的样式「加入当前布局」。")
            } else {
                ForEach(layoutStyles) { style in
                    styleRow(style) {
                        HStack(spacing: 6) {
                            iconButton("arrow.down.circle.fill", color: ZLTheme.primaryDeep) {
                                onApplyToSelection(style)
                            }
                            iconButton("trash.fill", color: ZLTheme.danger) {
                                onRemoveFromLayout(style.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // 收藏柜
    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("样式收藏柜", subtitle: "收藏的样式可以跨布局使用")
                Spacer()
                Button {
                    onResetVault()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZLTheme.textSecond)
                        .frame(width: 30, height: 30)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if vaultStyles.isEmpty {
                emptyHint("收藏柜还是空的。在控件属性里点「把当前外观加入收藏柜」即可。")
            } else {
                ForEach(vaultStyles) { style in
                    styleRow(style) {
                        HStack(spacing: 6) {
                            iconButton("plus.circle.fill", color: ZLTheme.primary) {
                                onAddToLayout(style)
                            }
                            iconButton("trash.fill", color: ZLTheme.danger) {
                                onRemoveFromVault(style.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ZLTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
        }
    }

    private func emptyHint(_ text: String) -> some View {
        ZLCard(padding: 12) {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func styleRow<Content: View>(_ style: ControlAppearance,
                                         @ViewBuilder actions: @escaping () -> Content) -> some View {
        ZLCard(padding: 12) {
            HStack(spacing: 12) {
                previewSwatch(style)
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Text(style.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.textSecond)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                actions()
            }
        }
    }

    private func previewSwatch(_ style: ControlAppearance) -> some View {
        ControlCornerShape(corners: style.corners)
            .fill(Color(hex: style.backgroundHex))
            .frame(width: 46, height: 30)
            .overlay(
                ControlCornerShape(corners: style.corners)
                    .stroke(Color(hex: style.borderHex),
                            lineWidth: CGFloat(max(0, style.borderWidth)))
            )
            .overlay(
                Text("W")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: style.contentHex))
            )
            .opacity(style.normalOpacity)
    }

    private func iconButton(_ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 控件层属性
struct ControlLayerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var layer: ControlLayer
    var layerCount: Int = 1
    var isBottomLayer: Bool = false
    var onMergeDown: () -> Void = {}
    var onDelete: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ZLTheme.cardGap) {
                    nameCard
                    propertyCard
                    actionCard
                }
                .padding(.horizontal, ZLTheme.screenPadding)
                .padding(.vertical, ZLTheme.screenPadding)
            }
            .background(ZLTheme.background.ignoresSafeArea())
            .navigationTitle("控件层属性")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }

    private var nameCard: some View {
        ZLCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("控件层名称")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZLTheme.textSecond)
                ZLTextField(placeholder: "控件层名称", text: $layer.name)
                Text("当前层共 \(layer.items.count) 个控件")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
            }
        }
    }

    private var propertyCard: some View {
        ZLCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(ZLTheme.primaryDeep)
                    Text("层属性")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Spacer()
                }

                toggleRow("默认隐藏", desc: "进入游戏时不显示这一层的控件", isOn: $layer.hiddenByDefault)
                Divider()
                toggleRow("实体鼠标操作时隐藏", desc: "连接鼠标并操作时自动隐藏，避免遮挡", isOn: $layer.hiddenByMouse)
                Divider()
                toggleRow("手柄操作时隐藏", desc: "用手柄操作时自动隐藏这一层", isOn: $layer.hiddenByGamepad)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("可见场景")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ZLTheme.textPrimary)
                    Picker("可见场景", selection: $layer.visibleScene) {
                        ForEach(VisibleScene.allCases) { scene in
                            Text(scene.rawValue).tag(scene)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Divider()
                toggleRow("合并控件到下层", desc: "运行时把这一层的控件并入下方控件层", isOn: $layer.mergeIntoLowerLayer)
            }
        }
    }

    private var actionCard: some View {
        ZLCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    onMergeDown()
                } label: {
                    Label("立即合并到下层", systemImage: "arrow.down.to.line")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isBottomLayer ? ZLTheme.textSecond : ZLTheme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(isBottomLayer ? ZLTheme.surfaceAlt : ZLTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isBottomLayer)

                Button {
                    onDelete()
                } label: {
                    Label("删除这个控件层", systemImage: "trash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(layerCount > 1 ? ZLTheme.danger : ZLTheme.textSecond)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(ZLTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(layerCount <= 1)

                Text(isBottomLayer ? "最底层无法向下合并，至少要保留一个控件层。" : "合并后这一层会被删除，控件会追加到下层。")
                    .font(.system(size: 10))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggleRow(_ title: String, desc: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZLTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(ZLTheme.textSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ZLTheme.primary)
        }
    }
}

// MARK: - 布局 JSON 导入 / 导出
struct ControlLayoutTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    var jsonText: String
    var onImport: (ControlLayoutDoc) -> Void = { _ in }
    var onClose: () -> Void = {}

    @State private var mode = 0
    @State private var input = ""
    @State private var message: String? = nil
    @State private var isError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: ZLTheme.cardGap) {
                Picker("模式", selection: $mode) {
                    Text("导出").tag(0)
                    Text("导入").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, ZLTheme.screenPadding)

                if mode == 0 {
                    exportView
                } else {
                    importView
                }
            }
            .padding(.top, 10)
            .background(ZLTheme.background.ignoresSafeArea())
            .navigationTitle("布局 JSON")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }

    private var exportView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZLCard(padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导出内容（\(jsonText.count) 个字符）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ZLTheme.textSecond)
                    ScrollView {
                        Text(jsonText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ZLTheme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 320)
                }
            }
            Text("长按上面的文本可以全选复制，保存成 .json 文件后即可分享给别人导入。")
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.textSecond)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ZLTheme.screenPadding)
    }

    private var importView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("把布局 JSON 粘贴到这里")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ZLTheme.textSecond)
                Spacer()
                Button("清空") {
                    input = ""
                    message = nil
                }
                .font(.system(size: 11))
                .foregroundStyle(ZLTheme.primaryDeep)
                .buttonStyle(.plain)
            }

            TextField("粘贴布局 JSON（以 { 开头）", text: $input, axis: .vertical)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(8...14)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(ZLTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: ZLTheme.chipRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ZLTheme.chipRadius, style: .continuous)
                        .stroke(ZLTheme.stroke, lineWidth: 1)
                )

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(isError ? ZLTheme.danger : ZLTheme.success)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                runImport()
            } label: {
                Label("导入并覆盖当前布局", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZLTheme.textOnGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ZLTheme.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Text("导入会做格式校验：JSON 结构、控件层名称、控件坐标与尺寸。校验失败不会改动当前布局。")
                .font(.system(size: 10))
                .foregroundStyle(ZLTheme.textSecond)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ZLTheme.screenPadding)
    }

    private func runImport() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            message = "请先粘贴布局 JSON。"
            isError = true
            return
        }
        guard let data = text.data(using: .utf8) else {
            message = "文本编码失败，请检查粘贴内容。"
            isError = true
            return
        }
        do {
            let imported = try ControlLayoutDoc.loadJSON(data)
            onImport(imported)
            message = "导入成功：\(imported.layers.count) 个控件层，\(imported.totalItemCount) 个控件。"
            isError = false
        } catch let error as ControlLayoutError {
            message = error.errorDescription ?? "导入失败：格式不正确。"
            isError = true
        } catch {
            message = "导入失败：\(error.localizedDescription)"
            isError = true
        }
    }
}

// MARK: - 布局信息（真机：名称/创作者/版本/描述 + 分享）
struct LayoutInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var doc: ControlLayoutDoc
    @State private var exportText = ""
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZLCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("布局信息").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ZLTheme.textPrimary)
                            field("布局名称", $doc.name)
                            field("布局创作者", $doc.author)
                            field("布局版本", $doc.version)
                            field("布局描述", $doc.desc)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            exportText = doc.exportJSONText()
                            showExport = true
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(ZLTheme.textOnGold)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(ZLTheme.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button { dismiss() } label: {
                            Text("编辑控制布局")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(ZLTheme.primaryDeep)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(ZLTheme.primarySoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ZLTheme.screenPadding)
            }
            .background(ZLTheme.background)
            .navigationTitle("布局信息")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showExport) {
                VStack(spacing: 12) {
                    Text("布局 JSON").font(.system(size: 15, weight: .semibold))
                    ScrollView {
                        Text(exportText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ZLTheme.textSecond)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 300)
                    .background(ZLTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .padding(ZLTheme.screenPadding)
                .background(ZLTheme.background)
                .presentationDetents([.medium])
            }
        }
    }

    private func field(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(ZLTheme.textSecond)
            TextField(title == "布局描述" ? "没有描述" : "", text: binding)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10).frame(height: 36)
                .background(ZLTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}
