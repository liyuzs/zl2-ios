// ZL2-iOS · 控制布局数据模型（严格对齐 ZL2 的 LayerController 模块）
// 参考：LayerController/src/main/java/com/movtery/layer_controller/
// 目的：JSON 格式与 ZL2 完全互通，可直接导入/导出官方布局文件
import Foundation
import SwiftUI

// MARK: - 坐标（0~10000 整数，对齐 ZL2 的 POSITION_RANGE）
struct ZLButtonPosition: Codable, Equatable, Sendable {
    var x: Int      // 0...10000
    var y: Int      // 0...10000

    static let range = 0...10000

    var xPercent: Double { min(max(Double(x) / 10000, 0), 1) }
    var yPercent: Double { min(max(Double(y) / 10000, 0), 1) }

    init(x: Int, y: Int) {
        self.x = min(max(x, 0), 10000)
        self.y = min(max(y, 0), 10000)
    }
}

// MARK: - 尺寸（对齐 ButtonSize：dp + 百分比双模式）
struct ZLButtonSize: Codable, Equatable, Sendable {
    var widthDp: Double = 40
    var heightDp: Double = 40
    var widthPercentage: Int = 800      // 100...10000（即 1%~100%）
    var heightPercentage: Int = 800
    var mode: SizeMode = .percentage

    enum SizeMode: String, Codable, Sendable {
        case dp        = "dp"
        case percentage = "percentage"
    }

    static let minDp = 5.0
    static let percentRange = 100...10000

    var widthPercentOfScreen: Double { Double(widthPercentage) / 10000 }
    var heightPercentOfScreen: Double { Double(heightPercentage) / 10000 }
}

// MARK: - 可见类型
enum ZLVisibilityType: String, Codable, CaseIterable, Sendable {
    case always  = "Always"
    case inGame  = "InGame"
    case outGame = "OutGame"
}

// MARK: - 文本对齐
enum ZLTextAlignment: String, Codable, CaseIterable, Sendable {
    case left   = "Left"
    case center = "Center"
    case right  = "Right"
}

// MARK: - 颜色序列化（ZL2 用 Compose Color 的 Long）
struct ZLColorValue: Codable, Equatable, Sendable {
    var argb: UInt32

    init(argb: UInt32) { self.argb = argb }
    init(_ color: Color) {
        // 简化：转成 ARGB32
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.argb = (UInt32(a * 255) << 24) | (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
    }

    var color: Color {
        let a = Double((argb >> 24) & 0xFF) / 255
        let r = Double((argb >> 16) & 0xFF) / 255
        let g = Double((argb >> 8) & 0xFF) / 255
        let b = Double(argb & 0xFF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // ZL2 用数字存
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(UInt32.self) { argb = n }
        else if let i = try? c.decode(Int64.self) { argb = UInt32(truncatingIfNeeded: i) }
        else { argb = 0xFF000000 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(argb)
    }
}

// MARK: - 样式配置（对齐 StyleConfig）
struct ZLStyleConfig: Codable, Equatable, Sendable {
    var alpha: Double = 1.0
    var pressedAlpha: Double = 1.0
    var backgroundColor: ZLColorValue = .init(argb: 0xFFFFFFFF)
    var pressedBackgroundColor: ZLColorValue = .init(argb: 0xFFCCCCCC)
    var contentColor: ZLColorValue = .init(argb: 0xFF000000)
    var pressedContentColor: ZLColorValue = .init(argb: 0xFF000000)
    var fontSize: Int? = nil
    var pressedFontSize: Int? = nil
    var borderWidth: Int = 0
    var pressedBorderWidth: Int = 0
    var borderColor: ZLColorValue = .init(argb: 0xFF000000)
    var pressedBorderColor: ZLColorValue = .init(argb: 0xFF000000)
    var borderRadius: ZLCorners = .uniform(8)

    static let alphaRange = 0.0...1.0
    static let fontSizeRange = 2...30
    static let defaultFontSize = 14
    static let borderWidthRange = 0...50
}

// MARK: - 四角圆角（对齐 borderRadius）
struct ZLCorners: Codable, Equatable, Sendable {
    var topLeft: Int = 8
    var topRight: Int = 8
    var bottomLeft: Int = 8
    var bottomRight: Int = 8

    static func uniform(_ v: Int) -> ZLCorners {
        ZLCorners(topLeft: v, topRight: v, bottomLeft: v, bottomRight: v)
    }
}

// MARK: - 按钮样式（对齐 ButtonStyle）
struct ZLButtonStyle: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var uuid: String
    var animateSwap: Bool = true
    var commonStyle: Bool = true
    var lightStyle: ZLStyleConfig
    var darkStyle: ZLStyleConfig

    private enum CodingKeys: String, CodingKey {
        case name, uuid, animateSwap, commonStyle, lightStyle, darkStyle
    }
}

// MARK: - 点击事件（对齐 ClickEvent 的 6 种 type）
enum ZLClickEvent: Codable, Equatable, Sendable {
    case key(String)                        // 按键
    case launcherEvent(String)              // 启动器事件
    case switchLayer(String)                // 切换控件层
    case showLayer(String)                  // 显示控件层
    case hideLayer(String)                  // 隐藏控件层
    case sendText(String)                   // 发送文本

    private enum CodingKeys: String, CodingKey {
        case type, key, launcher_event, switch_layer, show_layer, hide_layer, send_text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        switch type {
        case "key":              self = .key(try c.decodeIfPresent(String.self, forKey: .key) ?? "")
        case "launcher_event":   self = .launcherEvent(try c.decodeIfPresent(String.self, forKey: .launcher_event) ?? "")
        case "switch_layer":     self = .switchLayer(try c.decodeIfPresent(String.self, forKey: .switch_layer) ?? "")
        case "show_layer":       self = .showLayer(try c.decodeIfPresent(String.self, forKey: .show_layer) ?? "")
        case "hide_layer":       self = .hideLayer(try c.decodeIfPresent(String.self, forKey: .hide_layer) ?? "")
        case "send_text":        self = .sendText(try c.decodeIfPresent(String.self, forKey: .send_text) ?? "")
        default:                 self = .launcherEvent(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .key(let v):            try c.encode("key", forKey: .type); try c.encode(v, forKey: .key)
        case .launcherEvent(let v):  try c.encode("launcher_event", forKey: .type); try c.encode(v, forKey: .launcher_event)
        case .switchLayer(let v):    try c.encode("switch_layer", forKey: .type); try c.encode(v, forKey: .switch_layer)
        case .showLayer(let v):      try c.encode("show_layer", forKey: .type); try c.encode(v, forKey: .show_layer)
        case .hideLayer(let v):      try c.encode("hide_layer", forKey: .type); try c.encode(v, forKey: .hide_layer)
        case .sendText(let v):       try c.encode("send_text", forKey: .type); try c.encode(v, forKey: .send_text)
        }
    }

    var displayName: String {
        switch self {
        case .key(let k):           return "按键 \(k)"
        case .launcherEvent(let e): return "启动器事件：\(e)"
        case .switchLayer(let l):   return "切换层：\(l)"
        case .showLayer(let l):     return "显示层：\(l)"
        case .hideLayer(let l):     return "隐藏层：\(l)"
        case .sendText(let t):      return "发送文本：\(t.prefix(12))"
        }
    }
}

// MARK: - 普通按钮（对齐 NormalData）
struct ZLNormalButton: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var text: String
    var uuid: String
    var position: ZLButtonPosition
    var buttonSize: ZLButtonSize
    var buttonStyle: String? = nil     // 引用样式 uuid
    var textAlignment: ZLTextAlignment = .left
    var textBold: Bool = false
    var textItalic: Bool = false
    var textUnderline: Bool = false
    var visibilityType: ZLVisibilityType = .always
    var clickEvents: [ZLClickEvent] = []
    var isSwipple: Bool = true         // 滑动联动
    var isPenetrable: Bool = false     // 触摸穿透
    var isToggleable: Bool = false     // 开关式

    private enum CodingKeys: String, CodingKey {
        case text, uuid, position, buttonSize, buttonStyle, textAlignment
        case textBold, textItalic, textUnderline, visibilityType
        case clickEvents, isSwipple, isPenetrable, isToggleable
    }
}

// MARK: - 文本控件（对齐 TextData）
struct ZLTextWidget: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var text: String
    var uuid: String
    var position: ZLButtonPosition
    var buttonSize: ZLButtonSize
    var textAlignment: ZLTextAlignment = .left
    var textBold: Bool = false
    var textItalic: Bool = false
    var textUnderline: Bool = false
    var fontSize: Int? = nil
    var visibilityType: ZLVisibilityType = .always

    private enum CodingKeys: String, CodingKey {
        case text, uuid, position, buttonSize, textAlignment
        case textBold, textItalic, textUnderline, fontSize, visibilityType
    }
}

// MARK: - 摇杆（对齐 JoystickData）
struct ZLJoystick: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var uuid: String
    var position: ZLButtonPosition
    var buttonSize: ZLButtonSize
    var style: String? = nil
    var deadZone: Double = 0.1
    var lockThreshold: Double = 0.5
    var forwardLock: Bool = false
    var direction: String = "All"        // 8 向/4 向
    var triggerMode: String = "Drag"     // Drag/Touch
    var visibilityType: ZLVisibilityType = .always

    private enum CodingKeys: String, CodingKey {
        case uuid, position, buttonSize, style, deadZone, lockThreshold
        case forwardLock, direction, triggerMode, visibilityType
    }
}

// MARK: - 控件层（对齐 ControlLayer）
struct ZLLayer: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var uuid: String
    var hide: Bool = false
    var hideWhenMouse: Bool = true
    var hideWhenGamepad: Bool = true
    var visibilityType: ZLVisibilityType = .always
    var normalButtons: [ZLNormalButton] = []
    var textBoxes: [ZLTextWidget] = []
    var joystickButtons: [ZLJoystick] = []

    private enum CodingKeys: String, CodingKey {
        case name, uuid, hide, hideWhenMouse, hideWhenGamepad, visibilityType
        case normalButtons, textBoxes, joystickButtons
    }

    var totalWidgets: Int { normalButtons.count + textBoxes.count + joystickButtons.count }

    static func new(name: String) -> ZLLayer {
        ZLLayer(name: name, uuid: UUID().uuidString)
    }
}

// MARK: - 布局信息（对齐 ControlLayout.Info）
struct ZLLayoutInfo: Codable, Equatable, Sendable {
    var name: String
    var author: String
    var description: String
    var versionCode: Int = 1
    var versionName: String = "1.0"

    private enum CodingKeys: String, CodingKey {
        case name, author, description, versionCode, versionName
    }
}

// MARK: - 完整布局（对齐 ControlLayout）
struct ZLControlLayout: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var info: ZLLayoutInfo
    var layers: [ZLLayer] = []
    var styles: [ZLButtonStyle] = []
    var joystickStyles: [ZLButtonStyle] = []
    var editorVersion: Int = 12         // ZL2 当前编辑器版本

    private enum CodingKeys: String, CodingKey {
        case info, layers, styles, joystickStyles, editorVersion
    }

    static var empty: ZLControlLayout {
        ZLControlLayout(info: ZLLayoutInfo(name: "新的控制布局",
                                           author: "",
                                           description: ""),
                        layers: [],
                        styles: [],
                        joystickStyles: [])
    }

    /// 默认布局（对齐 ZL2 的默认控件：键盘常用键 + WASD + 摇杆）
    static var defaultLayout: ZLControlLayout {
        var layout = ZLControlLayout.empty
        var layer = ZLLayer(name: "默认", uuid: UUID().uuidString)

        // 键盘按键（真机截图里的 ESC/F3/F5/Tab/Ctrl/Alt/输入法）
        let keyboardKeys: [(String, String, Int, Int)] = [
            ("ESC", "ESC", 600, 300),
            ("F3", "F3", 1400, 300),
            ("F5", "F5", 2200, 300),
            ("Tab", "Tab", 3000, 300),
            ("Ctrl", "Ctrl", 3800, 300),
            ("Alt", "Alt", 4600, 300),
            ("输入法", "输入法", 5400, 300),
        ]
        for (label, key, x, y) in keyboardKeys {
            var b = ZLNormalButton(text: label, uuid: UUID().uuidString,
                                   position: .init(x: x, y: y),
                                   buttonSize: ZLButtonSize(widthDp: 44, heightDp: 44))
            b.clickEvents = [.key(key)]
            layer.normalButtons.append(b)
        }

        // WASD
        let wasd: [(String, Int, Int)] = [
            ("W", 1600, 6500), ("A", 900, 7200),
            ("S", 1600, 7200), ("D", 2300, 7200),
        ]
        for (label, x, y) in wasd {
            var b = ZLNormalButton(text: label, uuid: UUID().uuidString,
                                   position: .init(x: x, y: y),
                                   buttonSize: ZLButtonSize(widthDp: 44, heightDp: 44))
            b.clickEvents = [.key(label.lowercased())]
            layer.normalButtons.append(b)
        }

        // 右侧动作键
        let actions: [(String, String, Int, Int)] = [
            ("跳", " ", 8800, 6800),
            ("蹲", "shift", 7500, 7800),
            ("背包", "e", 9000, 5600),
        ]
        for (label, key, x, y) in actions {
            var b = ZLNormalButton(text: label, uuid: UUID().uuidString,
                                   position: .init(x: x, y: y),
                                   buttonSize: ZLButtonSize(widthDp: 48, heightDp: 48))
            b.clickEvents = [.key(key)]
            layer.normalButtons.append(b)
        }

        // 滑动方向控件
        var swipeUp = ZLNormalButton(text: "滑动↑", uuid: UUID().uuidString,
                                     position: .init(x: 9200, y: 2500),
                                     buttonSize: ZLButtonSize(widthDp: 44, heightDp: 36))
        swipeUp.clickEvents = [.launcherEvent("swipe_up")]
        layer.normalButtons.append(swipeUp)

        var swipeDown = ZLNormalButton(text: "滑动↓", uuid: UUID().uuidString,
                                       position: .init(x: 9200, y: 3200),
                                       buttonSize: ZLButtonSize(widthDp: 44, heightDp: 36))
        swipeDown.clickEvents = [.launcherEvent("swipe_down")]
        layer.normalButtons.append(swipeDown)

        // 摇杆
        let stick = ZLJoystick(uuid: UUID().uuidString,
                               position: .init(x: 4200, y: 7800),
                               buttonSize: ZLButtonSize(widthDp: 140, heightDp: 140))
        layer.joystickButtons.append(stick)

        layout.layers = [layer]
        return layout
    }

    /// 导出为 ZL2 兼容 JSON
    func exportJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    /// 导入 ZL2 的布局 JSON
    static func importJSON(_ data: Data) throws -> ZLControlLayout {
        try JSONDecoder().decode(ZLControlLayout.self, from: data)
    }
}
