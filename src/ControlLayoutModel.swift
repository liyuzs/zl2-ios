// ZL2-iOS · 控制布局数据模型（严格对齐 ZL2 的 LayerController 模块）
// 参考：LayerController/src/main/java/com/movtery/layer_controller/
//   layout/ControlLayout.kt        → ZLControlLayout / ZLLayoutInfo
//   layout/ControlLayer.kt         → ZLLayer
//   data/NormalData.kt             → ZLNormalButton
//   data/TextData.kt               → ZLTextWidget
//   data/JoystickData.kt           → ZLJoystick
//   data/ButtonPosition.kt         → ZLButtonPosition（0~10000）
//   data/ButtonSize.kt             → ZLButtonSize（type / dp / percentage / reference）
//   data/ButtonStyle.kt            → ZLButtonStyle / ZLStyleConfig
//   data/ButtonShape.kt            → ZLCorners
//   data/JoystickStyle.kt          → ZLJoystickStyle / ZLJoystickStyleConfig
//   data/VisibilityType.kt         → ZLVisibilityType
//   data/TextAlignment.kt          → ZLTextAlignment
//   data/lang/*.kt                 → ZLTranslatableString / ZLLocalizedString
//   event/ClickEvent.kt            → ZLClickEvent（type + key 两个键）
//   utils/JsonAdapters.kt          → ZLColorValue（ARGB Long）
// 目的：JSON 格式与 ZL2 完全互通，可直接导入/导出官方布局文件
import Foundation
import SwiftUI

// MARK: - 容错解码（老布局缺少字段时用 ZL2 的默认值）
extension KeyedDecodingContainer {
    fileprivate func zl<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        do {
            if let value = try decodeIfPresent(T.self, forKey: key) { return value }
        } catch {}
        return fallback
    }

    fileprivate func zlOptional<T: Decodable>(_ key: Key, _ fallback: T?) -> T? {
        do {
            if let value = try decodeIfPresent(T.self, forKey: key) { return value }
        } catch {}
        return fallback
    }
}

// MARK: - 多语言字符串（对齐 TranslatableString / LocalizedString）
struct ZLLocalizedString: Codable, Equatable, Sendable {
    var languageTag: String
    var value: String

    init(languageTag: String = "", value: String = "") {
        self.languageTag = languageTag
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case languageTag = "language_tag"
        case value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        languageTag = c.zl(.languageTag, "")
        value = c.zl(.value, "")
    }
}

struct ZLTranslatableString: Codable, Equatable, Sendable {
    /// 对应 ZL2 的 `default`（未命中语言时使用）
    var defaultValue: String
    var matchQueue: [ZLLocalizedString]

    init(_ defaultValue: String = "", matchQueue: [ZLLocalizedString] = []) {
        self.defaultValue = defaultValue
        self.matchQueue = matchQueue
    }

    private enum CodingKeys: String, CodingKey {
        case defaultValue = "default"
        case matchQueue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultValue = c.zl(.defaultValue, "")
        matchQueue = c.zl(.matchQueue, [])
    }

    /// 按当前系统语言取显示文本（对齐 TranslatableString.translate）
    var plainText: String {
        let langs = Locale.preferredLanguages.map { $0.lowercased() }
        for item in matchQueue where !item.value.isEmpty {
            let tag = item.languageTag.lowercased()
            if tag.contains("-") {
                if langs.contains(where: { $0.hasPrefix(tag) }) { return item.value }
            } else if langs.contains(where: { $0.hasPrefix(tag) }) {
                return item.value
            }
        }
        return defaultValue
    }
}

// MARK: - 坐标（0~10000 整数，对齐 ZL2 的 POSITION_RANGE）
// 注意：ZL2 的 x/y 是「控件左上角」在（屏幕尺寸 - 控件尺寸）上的百分比，
// 不是控件中心点；编辑器内部用 0~1 的中心点坐标，换算在 ControlModelBridge 里完成。
struct ZLButtonPosition: Codable, Equatable, Sendable {
    static let range = 0...10000

    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = min(max(x, ZLButtonPosition.range.lowerBound), ZLButtonPosition.range.upperBound)
        self.y = min(max(y, ZLButtonPosition.range.lowerBound), ZLButtonPosition.range.upperBound)
    }

    private enum CodingKeys: String, CodingKey { case x, y }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: c.zl(.x, 5000), y: c.zl(.y, 5000))
    }

    /// 0~1 的百分比值（对齐 ButtonPosition.xPercentage / yPercentage）
    var xPercent: Double { min(max(Double(x) / 10000.0, 0), 1) }
    var yPercent: Double { min(max(Double(y) / 10000.0, 0), 1) }
}

// MARK: - 尺寸（对齐 ButtonSize：dp / 百分比 / 包裹内容）
struct ZLButtonSize: Codable, Equatable, Sendable {
    /// 对齐 ButtonSize.Type，序列化值为 dp / percentage / wrap_content
    enum SizeType: String, Codable, Sendable {
        case dp = "dp"
        case percentage = "percentage"
        case wrapContent = "wrap_content"
    }

    /// 对齐 ButtonSize.Reference，序列化值为 screen_width / screen_height
    enum Reference: String, Codable, Sendable {
        case screenWidth = "screen_width"
        case screenHeight = "screen_height"
    }

    /// 绝对值最小值（ZL2: MIN_SIZE_DP = 5.0f）
    static let minDp = 5.0
    /// 百分比取值范围（ZL2: SIZE_PERCENTAGE = 100f..10000f）
    static let percentRange = 100...10000

    var type: SizeType
    var widthDp: Double
    var heightDp: Double
    var widthPercentage: Int
    var heightPercentage: Int
    var widthReference: Reference
    var heightReference: Reference

    /// 默认值对齐 ZL2 的 DefaultSize（1400 = 14%）
    init(type: SizeType = .percentage,
         widthDp: Double = 50,
         heightDp: Double = 50,
         widthPercentage: Int = 1400,
         heightPercentage: Int = 1400,
         widthReference: Reference = .screenHeight,
         heightReference: Reference = .screenHeight) {
        self.type = type
        self.widthDp = max(ZLButtonSize.minDp, widthDp)
        self.heightDp = max(ZLButtonSize.minDp, heightDp)
        self.widthPercentage = min(max(widthPercentage, ZLButtonSize.percentRange.lowerBound),
                                   ZLButtonSize.percentRange.upperBound)
        self.heightPercentage = min(max(heightPercentage, ZLButtonSize.percentRange.lowerBound),
                                    ZLButtonSize.percentRange.upperBound)
        self.widthReference = widthReference
        self.heightReference = heightReference
    }

    private enum CodingKeys: String, CodingKey {
        case type, widthDp, heightDp, widthPercentage, heightPercentage
        case widthReference, heightReference
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(type: c.zl(.type, SizeType.percentage),
                  widthDp: c.zl(.widthDp, 50),
                  heightDp: c.zl(.heightDp, 50),
                  widthPercentage: c.zl(.widthPercentage, 1400),
                  heightPercentage: c.zl(.heightPercentage, 1400),
                  widthReference: c.zl(.widthReference, Reference.screenHeight),
                  heightReference: c.zl(.heightReference, Reference.screenHeight))
    }

    var widthPercentOfScreen: Double { Double(widthPercentage) / 10000.0 }
    var heightPercentOfScreen: Double { Double(heightPercentage) / 10000.0 }
}

// MARK: - 可见类型（对齐 VisibilityType：always / in_game / in_menu）
enum ZLVisibilityType: String, Codable, CaseIterable, Sendable {
    case always = "always"
    case inGame = "in_game"
    case inMenu = "in_menu"
}

// MARK: - 文本对齐（TextAlignment 没有 @Serializable，kotlinx 用枚举名）
enum ZLTextAlignment: String, Codable, CaseIterable, Sendable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

// MARK: - 颜色（对齐 ColorSerializer：ARGB 存成 Long）
struct ZLColorValue: Codable, Equatable, Sendable {
    var argb: UInt32

    init(argb: UInt32) { self.argb = argb }

    /// 用 0xRRGGBB + 独立 alpha 构造（编辑器里的颜色都是不透明 RGB）
    init(rgb: UInt32, alpha: UInt8 = 0xFF) {
        self.argb = (UInt32(alpha) << 24) | (rgb & 0xFFFFFF)
    }

    var color: Color {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw: UInt64 = (try? c.decode(UInt64.self)) ?? 0
        // ZL2 ColorSerializer：高 32 位非 0 时是历史格式，否则取低 32 位
        let high = UInt32(truncatingIfNeeded: raw >> 32)
        argb = high != 0 ? high : UInt32(truncatingIfNeeded: raw)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(UInt64(argb))
    }
}

// MARK: - 四角圆角（对齐 ButtonShape：topStart / topEnd / bottomEnd / bottomStart，单位 Dp，0~100）
struct ZLCorners: Codable, Equatable, Sendable {
    static let range = 0.0...100.0

    var topStart: Double
    var topEnd: Double
    var bottomEnd: Double
    var bottomStart: Double

    init(topStart: Double = 0, topEnd: Double = 0, bottomEnd: Double = 0, bottomStart: Double = 0) {
        self.topStart = Self.clamp(topStart)
        self.topEnd = Self.clamp(topEnd)
        self.bottomEnd = Self.clamp(bottomEnd)
        self.bottomStart = Self.clamp(bottomStart)
    }

    init(size: Double) {
        self.init(topStart: size, topEnd: size, bottomEnd: size, bottomStart: size)
    }

    static func uniform(_ value: Double) -> ZLCorners { ZLCorners(size: value) }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, ZLCorners.range.lowerBound), ZLCorners.range.upperBound)
    }

    private enum CodingKeys: String, CodingKey {
        case topStart, topEnd, bottomEnd, bottomStart
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(topStart: c.zl(.topStart, 0),
                  topEnd: c.zl(.topEnd, 0),
                  bottomEnd: c.zl(.bottomEnd, 0),
                  bottomStart: c.zl(.bottomStart, 0))
    }
}

// MARK: - 样式配置（对齐 ButtonStyle.StyleConfig）
struct ZLStyleConfig: Codable, Equatable, Sendable {
    static let alphaRange = 0.0...1.0
    static let fontSizeRange = 2...30
    static let borderWidthRange = 0...50

    var alpha: Double
    var pressedAlpha: Double
    var backgroundColor: ZLColorValue
    var pressedBackgroundColor: ZLColorValue
    var contentColor: ZLColorValue
    var pressedContentColor: ZLColorValue
    var fontSize: Int?
    var pressedFontSize: Int?
    var borderWidth: Int
    var pressedBorderWidth: Int
    var borderColor: ZLColorValue
    var pressedBorderColor: ZLColorValue
    var borderRadius: ZLCorners
    var pressedBorderRadius: ZLCorners

    /// 默认值对齐 ZL2 的 DefaultButtonStyleConfig
    init(alpha: Double = 1,
         pressedAlpha: Double = 1,
         backgroundColor: ZLColorValue = ZLColorValue(argb: 0x80000000),
         pressedBackgroundColor: ZLColorValue = ZLColorValue(argb: 0xB3888888),
         contentColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         pressedContentColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         fontSize: Int? = nil,
         pressedFontSize: Int? = nil,
         borderWidth: Int = 0,
         pressedBorderWidth: Int = 0,
         borderColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         pressedBorderColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         borderRadius: ZLCorners = ZLCorners.uniform(0),
         pressedBorderRadius: ZLCorners = ZLCorners.uniform(0)) {
        self.alpha = min(max(alpha, 0), 1)
        self.pressedAlpha = min(max(pressedAlpha, 0), 1)
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.contentColor = contentColor
        self.pressedContentColor = pressedContentColor
        self.fontSize = fontSize.map { min(max($0, 2), 30) }
        self.pressedFontSize = pressedFontSize.map { min(max($0, 2), 30) }
        self.borderWidth = min(max(borderWidth, 0), 50)
        self.pressedBorderWidth = min(max(pressedBorderWidth, 0), 50)
        self.borderColor = borderColor
        self.pressedBorderColor = pressedBorderColor
        self.borderRadius = borderRadius
        self.pressedBorderRadius = pressedBorderRadius
    }

    private enum CodingKeys: String, CodingKey {
        case alpha, pressedAlpha, backgroundColor, pressedBackgroundColor
        case contentColor, pressedContentColor, fontSize, pressedFontSize
        case borderWidth, pressedBorderWidth, borderColor, pressedBorderColor
        case borderRadius, pressedBorderRadius
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(alpha: c.zl(.alpha, 1),
                  pressedAlpha: c.zl(.pressedAlpha, 1),
                  backgroundColor: c.zl(.backgroundColor, ZLColorValue(argb: 0x80000000)),
                  pressedBackgroundColor: c.zl(.pressedBackgroundColor, ZLColorValue(argb: 0xB3888888)),
                  contentColor: c.zl(.contentColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  pressedContentColor: c.zl(.pressedContentColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  fontSize: c.zlOptional(.fontSize, Int?.none),
                  pressedFontSize: c.zlOptional(.pressedFontSize, Int?.none),
                  borderWidth: c.zl(.borderWidth, 0),
                  pressedBorderWidth: c.zl(.pressedBorderWidth, 0),
                  borderColor: c.zl(.borderColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  pressedBorderColor: c.zl(.pressedBorderColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  borderRadius: c.zl(.borderRadius, ZLCorners.uniform(0)),
                  pressedBorderRadius: c.zl(.pressedBorderRadius, ZLCorners.uniform(0)))
    }
}

// MARK: - 按钮样式（对齐 ButtonStyle）
struct ZLButtonStyle: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var uuid: String
    var animateSwap: Bool
    var commonStyle: Bool
    var lightStyle: ZLStyleConfig
    var darkStyle: ZLStyleConfig

    /// 默认值对齐 ZL2 的 DefaultButtonStyle（animateSwap = false）
    init(name: String = "Default",
         uuid: String = UUID().uuidString,
         animateSwap: Bool = false,
         commonStyle: Bool = true,
         lightStyle: ZLStyleConfig = ZLStyleConfig(),
         darkStyle: ZLStyleConfig = ZLStyleConfig()) {
        self.name = name
        self.uuid = uuid
        self.animateSwap = animateSwap
        self.commonStyle = commonStyle
        self.lightStyle = lightStyle
        self.darkStyle = darkStyle
    }

    private enum CodingKeys: String, CodingKey {
        case name, uuid, animateSwap, commonStyle, lightStyle, darkStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.zl(.name, "Default"),
                  uuid: c.zl(.uuid, UUID().uuidString),
                  animateSwap: c.zl(.animateSwap, false),
                  commonStyle: c.zl(.commonStyle, true),
                  lightStyle: c.zl(.lightStyle, ZLStyleConfig()),
                  darkStyle: c.zl(.darkStyle, ZLStyleConfig()))
    }
}

// MARK: - 摇杆样式（对齐 JoystickStyle）
struct ZLJoystickStyleConfig: Codable, Equatable, Sendable {
    var alpha: Double
    var backgroundColor: ZLColorValue
    var joystickColor: ZLColorValue
    var joystickCanLockColor: ZLColorValue
    var joystickLockedColor: ZLColorValue
    var lockMarkColor: ZLColorValue
    var borderWidthRatio: Int
    var borderColor: ZLColorValue
    var backgroundShape: Int
    var joystickShape: Int
    var joystickSize: Double

    /// 默认值对齐 ZL2 的 DefaultJoystickStyleConfig
    init(alpha: Double = 1,
         backgroundColor: ZLColorValue = ZLColorValue(argb: 0x80000000),
         joystickColor: ZLColorValue = ZLColorValue(argb: 0x80FFFFFF),
         joystickCanLockColor: ZLColorValue = ZLColorValue(argb: 0x80FFFF00),
         joystickLockedColor: ZLColorValue = ZLColorValue(argb: 0x8000FF00),
         lockMarkColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         borderWidthRatio: Int = 0,
         borderColor: ZLColorValue = ZLColorValue(argb: 0xFFFFFFFF),
         backgroundShape: Int = 50,
         joystickShape: Int = 50,
         joystickSize: Double = 0.5) {
        self.alpha = min(max(alpha, 0), 1)
        self.backgroundColor = backgroundColor
        self.joystickColor = joystickColor
        self.joystickCanLockColor = joystickCanLockColor
        self.joystickLockedColor = joystickLockedColor
        self.lockMarkColor = lockMarkColor
        self.borderWidthRatio = min(max(borderWidthRatio, 0), 50)
        self.borderColor = borderColor
        self.backgroundShape = min(max(backgroundShape, 0), 50)
        self.joystickShape = min(max(joystickShape, 0), 50)
        self.joystickSize = min(max(joystickSize, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case alpha, backgroundColor, joystickColor, joystickCanLockColor
        case joystickLockedColor, lockMarkColor, borderWidthRatio, borderColor
        case backgroundShape, joystickShape, joystickSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(alpha: c.zl(.alpha, 1),
                  backgroundColor: c.zl(.backgroundColor, ZLColorValue(argb: 0x80000000)),
                  joystickColor: c.zl(.joystickColor, ZLColorValue(argb: 0x80FFFFFF)),
                  joystickCanLockColor: c.zl(.joystickCanLockColor, ZLColorValue(argb: 0x80FFFF00)),
                  joystickLockedColor: c.zl(.joystickLockedColor, ZLColorValue(argb: 0x8000FF00)),
                  lockMarkColor: c.zl(.lockMarkColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  borderWidthRatio: c.zl(.borderWidthRatio, 0),
                  borderColor: c.zl(.borderColor, ZLColorValue(argb: 0xFFFFFFFF)),
                  backgroundShape: c.zl(.backgroundShape, 50),
                  joystickShape: c.zl(.joystickShape, 50),
                  joystickSize: c.zl(.joystickSize, 0.5))
    }
}

struct ZLJoystickStyle: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var uuid: String
    var commonStyle: Bool
    var lightStyle: ZLJoystickStyleConfig
    var darkStyle: ZLJoystickStyleConfig

    init(name: String = "Default",
         uuid: String = UUID().uuidString,
         commonStyle: Bool = true,
         lightStyle: ZLJoystickStyleConfig = ZLJoystickStyleConfig(),
         darkStyle: ZLJoystickStyleConfig = ZLJoystickStyleConfig()) {
        self.name = name
        self.uuid = uuid
        self.commonStyle = commonStyle
        self.lightStyle = lightStyle
        self.darkStyle = darkStyle
    }

    private enum CodingKeys: String, CodingKey {
        case name, uuid, commonStyle, lightStyle, darkStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.zl(.name, "Default"),
                  uuid: c.zl(.uuid, UUID().uuidString),
                  commonStyle: c.zl(.commonStyle, true),
                  lightStyle: c.zl(.lightStyle, ZLJoystickStyleConfig()),
                  darkStyle: c.zl(.darkStyle, ZLJoystickStyleConfig()))
    }
}

// MARK: - 点击事件（对齐 ClickEvent：只有 type + key 两个键）
enum ZLClickEventType: String, Codable, CaseIterable, Sendable {
    case key = "key"
    case launcherEvent = "launcher_event"
    case switchLayer = "switch_layer"
    case showLayer = "show_layer"
    case hideLayer = "hide_layer"
    case sendText = "send_text"

    /// 该事件类型是否与控件层相关
    var isAboutLayers: Bool {
        self == .switchLayer || self == .showLayer || self == .hideLayer
    }
}

struct ZLClickEvent: Codable, Equatable, Sendable {
    var type: ZLClickEventType
    /// 事件值：GLFW 按键名 / 启动器事件常量 / 控件层 uuid / 文本
    var value: String

    init(type: ZLClickEventType, value: String) {
        self.type = type
        self.value = value
    }

    private enum CodingKeys: String, CodingKey { case type, key }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.zl(.type, ZLClickEventType.key)
        value = c.zl(.key, "")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(value, forKey: .key)
    }

    // MARK: 便捷构造

    static func key(_ key: String) -> ZLClickEvent { ZLClickEvent(type: .key, value: key) }
    static func launcherEvent(_ key: String) -> ZLClickEvent { ZLClickEvent(type: .launcherEvent, value: key) }
    static func switchLayer(_ layerID: String) -> ZLClickEvent { ZLClickEvent(type: .switchLayer, value: layerID) }
    static func showLayer(_ layerID: String) -> ZLClickEvent { ZLClickEvent(type: .showLayer, value: layerID) }
    static func hideLayer(_ layerID: String) -> ZLClickEvent { ZLClickEvent(type: .hideLayer, value: layerID) }
    static func sendText(_ text: String) -> ZLClickEvent { ZLClickEvent(type: .sendText, value: text) }

    var isAboutLayers: Bool { type.isAboutLayers }

    var displayName: String {
        switch type {
        case .key:            return "按键 \(value)"
        case .launcherEvent:  return "启动器事件：\(value)"
        case .switchLayer:    return "切换层：\(value)"
        case .showLayer:      return "显示层：\(value)"
        case .hideLayer:      return "隐藏层：\(value)"
        case .sendText:       return "发送文本：\(value.prefix(12))"
        }
    }
}

/// ZL2 的启动器事件常量（见 ZalithLauncher/ui/control/event/Events.kt）
enum ZLLauncherEventKey {
    static let switchIME = "launcher.event.switch_ime"
    static let switchMenu = "launcher.event.switch_menu"
    static let scrollUp = "launcher.event.scroll_up"
    static let scrollUpSingle = "launcher.event.scroll_up.single"
    static let scrollDown = "launcher.event.scroll_down"
    static let scrollDownSingle = "launcher.event.scroll_down.single"

    static let mouseLeft = "GLFW_MOUSE_BUTTON_LEFT"
    static let mouseMiddle = "GLFW_MOUSE_BUTTON_MIDDLE"
    static let mouseRight = "GLFW_MOUSE_BUTTON_RIGHT"
}

// MARK: - 普通按钮（对齐 NormalData，全部 14 个字段）
struct ZLNormalButton: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var text: ZLTranslatableString
    var uuid: String
    var position: ZLButtonPosition
    var buttonSize: ZLButtonSize
    /// 引用的样式 uuid（对应 styles 里某个 ButtonStyle.uuid）
    var buttonStyle: String?
    var textAlignment: ZLTextAlignment
    var textBold: Bool
    var textItalic: Bool
    var textUnderline: Bool
    var visibilityType: ZLVisibilityType
    var clickEvents: [ZLClickEvent]
    var isSwipple: Bool
    var isPenetrable: Bool
    var isToggleable: Bool

    /// 默认值对齐 ZL2 新建按钮时的取值（ControlEditor.kt addNewButton）
    init(text: ZLTranslatableString = ZLTranslatableString(),
         uuid: String = "",
         position: ZLButtonPosition = ZLButtonPosition(x: 5000, y: 5000),
         buttonSize: ZLButtonSize = ZLButtonSize(),
         buttonStyle: String? = nil,
         textAlignment: ZLTextAlignment = .left,
         textBold: Bool = false,
         textItalic: Bool = false,
         textUnderline: Bool = false,
         visibilityType: ZLVisibilityType = .always,
         clickEvents: [ZLClickEvent] = [],
         isSwipple: Bool = false,
         isPenetrable: Bool = false,
         isToggleable: Bool = false) {
        self.text = text
        self.uuid = uuid
        self.position = position
        self.buttonSize = buttonSize
        self.buttonStyle = buttonStyle
        self.textAlignment = textAlignment
        self.textBold = textBold
        self.textItalic = textItalic
        self.textUnderline = textUnderline
        self.visibilityType = visibilityType
        self.clickEvents = clickEvents
        self.isSwipple = isSwipple
        self.isPenetrable = isPenetrable
        self.isToggleable = isToggleable
    }

    private enum CodingKeys: String, CodingKey {
        case text, uuid, position, buttonSize, buttonStyle, textAlignment
        case textBold, textItalic, textUnderline, visibilityType
        case clickEvents, isSwipple, isPenetrable, isToggleable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(text: c.zl(.text, ZLTranslatableString()),
                  uuid: c.zl(.uuid, ""),
                  position: c.zl(.position, ZLButtonPosition(x: 5000, y: 5000)),
                  buttonSize: c.zl(.buttonSize, ZLButtonSize()),
                  buttonStyle: c.zlOptional(.buttonStyle, String?.none),
                  textAlignment: c.zl(.textAlignment, ZLTextAlignment.left),
                  textBold: c.zl(.textBold, false),
                  textItalic: c.zl(.textItalic, false),
                  textUnderline: c.zl(.textUnderline, false),
                  visibilityType: c.zl(.visibilityType, ZLVisibilityType.always),
                  clickEvents: c.zl(.clickEvents, []),
                  isSwipple: c.zl(.isSwipple, false),
                  isPenetrable: c.zl(.isPenetrable, false),
                  isToggleable: c.zl(.isToggleable, false))
    }

    /// 对齐 NormalData.filterValidEvent：只保留第一条非空的 SendText
    mutating func filterValidEvents() {
        var found = false
        clickEvents = clickEvents.filter { event in
            guard event.type == .sendText else { return true }
            if !found && !event.value.isEmpty {
                found = true
                return true
            }
            return false
        }
    }
}

// MARK: - 文本控件（对齐 TextData）
struct ZLTextWidget: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var text: ZLTranslatableString
    var uuid: String
    var position: ZLButtonPosition
    var buttonSize: ZLButtonSize
    var buttonStyle: String?
    var textAlignment: ZLTextAlignment
    var textBold: Bool
    var textItalic: Bool
    var textUnderline: Bool
    var visibilityType: ZLVisibilityType

    init(text: ZLTranslatableString = ZLTranslatableString(),
         uuid: String = "",
         position: ZLButtonPosition = ZLButtonPosition(x: 5000, y: 5000),
         buttonSize: ZLButtonSize = ZLButtonSize(),
         buttonStyle: String? = nil,
         textAlignment: ZLTextAlignment = .left,
         textBold: Bool = false,
         textItalic: Bool = false,
         textUnderline: Bool = false,
         visibilityType: ZLVisibilityType = .always) {
        self.text = text
        self.uuid = uuid
        self.position = position
        self.buttonSize = buttonSize
        self.buttonStyle = buttonStyle
        self.textAlignment = textAlignment
        self.textBold = textBold
        self.textItalic = textItalic
        self.textUnderline = textUnderline
        self.visibilityType = visibilityType
    }

    private enum CodingKeys: String, CodingKey {
        case text, uuid, position, buttonSize, buttonStyle, textAlignment
        case textBold, textItalic, textUnderline, visibilityType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(text: c.zl(.text, ZLTranslatableString()),
                  uuid: c.zl(.uuid, ""),
                  position: c.zl(.position, ZLButtonPosition(x: 5000, y: 5000)),
                  buttonSize: c.zl(.buttonSize, ZLButtonSize()),
                  buttonStyle: c.zlOptional(.buttonStyle, String?.none),
                  textAlignment: c.zl(.textAlignment, ZLTextAlignment.left),
                  textBold: c.zl(.textBold, false),
                  textItalic: c.zl(.textItalic, false),
                  textUnderline: c.zl(.textUnderline, false),
                  visibilityType: c.zl(.visibilityType, ZLVisibilityType.always))
    }
}

// MARK: - 摇杆（对齐 JoystickData）
enum ZLJoystickTriggerMode: String, Codable, CaseIterable, Sendable {
    case drag = "drag"
    case touch = "touch"
}

/// 对齐 JoystickDirection（directionEvents 的 map 键）
enum ZLJoystickDirection: String, Codable, CaseIterable, Sendable {
    case east = "east"
    case northEast = "north_east"
    case north = "north"
    case northWest = "north_west"
    case west = "west"
    case southWest = "south_west"
    case south = "south"
    case southEast = "south_east"
    case none = "none"
}

/// 默认的方向事件绑定 / 锁定事件（对齐 JoystickData.kt 的 DefaultDirectionEvents / DefaultLockEvents）
enum ZLJoystickDefaults {
    static let directionEvents: [String: [ZLClickEvent]] = [
        ZLJoystickDirection.north.rawValue: [.key("GLFW_KEY_W")],
        ZLJoystickDirection.northEast.rawValue: [.key("GLFW_KEY_W"), .key("GLFW_KEY_D")],
        ZLJoystickDirection.northWest.rawValue: [.key("GLFW_KEY_W"), .key("GLFW_KEY_A")],
        ZLJoystickDirection.south.rawValue: [.key("GLFW_KEY_S")],
        ZLJoystickDirection.southEast.rawValue: [.key("GLFW_KEY_S"), .key("GLFW_KEY_D")],
        ZLJoystickDirection.southWest.rawValue: [.key("GLFW_KEY_S"), .key("GLFW_KEY_A")],
        ZLJoystickDirection.east.rawValue: [.key("GLFW_KEY_D")],
        ZLJoystickDirection.west.rawValue: [.key("GLFW_KEY_A")]
    ]

    static let lockEvents: [ZLClickEvent] = [.key("GLFW_KEY_LEFT_CONTROL")]
}

struct ZLJoystick: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var uuid: String
    var position: ZLButtonPosition
    /// 不支持 wrapContent（ZL2 的 JoystickData.init 会抛错）
    var sizeType: ZLButtonSize.SizeType
    var sizeDp: Double
    var sizePercentage: Int
    var visibilityType: ZLVisibilityType
    var joystickStyleId: String?
    var deadZoneRatio: Double
    var lockThreshold: Double
    var canLock: Bool
    var triggerMode: ZLJoystickTriggerMode
    var directionEvents: [String: [ZLClickEvent]]
    var lockEvents: [ZLClickEvent]

    init(uuid: String = "",
         position: ZLButtonPosition = ZLButtonPosition(x: 5000, y: 5000),
         sizeType: ZLButtonSize.SizeType = .percentage,
         sizeDp: Double = 200,
         sizePercentage: Int = 2500,
         visibilityType: ZLVisibilityType = .always,
         joystickStyleId: String? = nil,
         deadZoneRatio: Double = 0.5,
         lockThreshold: Double = 0.3,
         canLock: Bool = true,
         triggerMode: ZLJoystickTriggerMode = .drag,
         directionEvents: [String: [ZLClickEvent]] = ZLJoystickDefaults.directionEvents,
         lockEvents: [ZLClickEvent] = ZLJoystickDefaults.lockEvents) {
        self.uuid = uuid
        self.position = position
        self.sizeType = sizeType == .wrapContent ? .percentage : sizeType
        // ZL2 的 JoystickData 不对尺寸做范围校验（只在渲染时夹取），这里只避免 0 值
        self.sizeDp = max(1, sizeDp)
        self.sizePercentage = min(max(sizePercentage, 1), 10000)
        self.visibilityType = visibilityType
        self.joystickStyleId = joystickStyleId
        self.deadZoneRatio = min(max(deadZoneRatio, 0), 0.9)
        self.lockThreshold = min(max(lockThreshold, 0), 1)
        self.canLock = canLock
        self.triggerMode = triggerMode
        self.directionEvents = directionEvents
        self.lockEvents = lockEvents
    }

    private enum CodingKeys: String, CodingKey {
        case uuid, position, sizeType, sizeDp, sizePercentage, visibilityType
        case joystickStyleId, deadZoneRatio, lockThreshold, canLock, triggerMode
        case directionEvents, lockEvents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(uuid: c.zl(.uuid, ""),
                  position: c.zl(.position, ZLButtonPosition(x: 5000, y: 5000)),
                  sizeType: c.zl(.sizeType, ZLButtonSize.SizeType.percentage),
                  sizeDp: c.zl(.sizeDp, 200),
                  sizePercentage: c.zl(.sizePercentage, 2500),
                  visibilityType: c.zl(.visibilityType, ZLVisibilityType.always),
                  joystickStyleId: c.zlOptional(.joystickStyleId, String?.none),
                  deadZoneRatio: c.zl(.deadZoneRatio, 0.5),
                  lockThreshold: c.zl(.lockThreshold, 0.3),
                  canLock: c.zl(.canLock, true),
                  triggerMode: c.zl(.triggerMode, ZLJoystickTriggerMode.drag),
                  directionEvents: c.zl(.directionEvents, ZLJoystickDefaults.directionEvents),
                  lockEvents: c.zl(.lockEvents, ZLJoystickDefaults.lockEvents))
    }
}

// MARK: - 控件层（对齐 ControlLayer：hide / hideWhenMouse / hideWhenGamepad / visibilityType）
struct ZLLayer: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var uuid: String
    var hide: Bool
    var hideWhenMouse: Bool
    var hideWhenGamepad: Bool
    var visibilityType: ZLVisibilityType
    var normalButtons: [ZLNormalButton]
    var textBoxes: [ZLTextWidget]
    var joystickButtons: [ZLJoystick]

    /// 默认值对齐 ZL2 的 createNewLayer
    init(name: String = "",
         uuid: String = UUID().uuidString,
         hide: Bool = false,
         hideWhenMouse: Bool = true,
         hideWhenGamepad: Bool = true,
         visibilityType: ZLVisibilityType = .always,
         normalButtons: [ZLNormalButton] = [],
         textBoxes: [ZLTextWidget] = [],
         joystickButtons: [ZLJoystick] = []) {
        self.name = name
        self.uuid = uuid
        self.hide = hide
        self.hideWhenMouse = hideWhenMouse
        self.hideWhenGamepad = hideWhenGamepad
        self.visibilityType = visibilityType
        self.normalButtons = normalButtons
        self.textBoxes = textBoxes
        self.joystickButtons = joystickButtons
    }

    private enum CodingKeys: String, CodingKey {
        case name, uuid, hide, hideWhenMouse, hideWhenGamepad, visibilityType
        case normalButtons, textBoxes, joystickButtons
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.zl(.name, ""),
                  uuid: c.zl(.uuid, UUID().uuidString),
                  hide: c.zl(.hide, false),
                  hideWhenMouse: c.zl(.hideWhenMouse, true),
                  hideWhenGamepad: c.zl(.hideWhenGamepad, true),
                  visibilityType: c.zl(.visibilityType, ZLVisibilityType.always),
                  normalButtons: c.zl(.normalButtons, []),
                  textBoxes: c.zl(.textBoxes, []),
                  joystickButtons: c.zl(.joystickButtons, []))
    }

    var totalWidgets: Int { normalButtons.count + textBoxes.count + joystickButtons.count }

    static func new(name: String) -> ZLLayer { ZLLayer(name: name) }
}

// MARK: - 布局信息（对齐 ControlLayout.Info，三个文本都是 TranslatableString）
struct ZLLayoutInfo: Codable, Equatable, Sendable {
    var name: ZLTranslatableString
    var author: ZLTranslatableString
    var description: ZLTranslatableString
    var versionCode: Int
    var versionName: String

    init(name: String, author: String = "", description: String = "",
         versionCode: Int = 0, versionName: String = "") {
        self.name = ZLTranslatableString(name)
        self.author = ZLTranslatableString(author)
        self.description = ZLTranslatableString(description)
        self.versionCode = versionCode
        self.versionName = versionName
    }

    init(name: ZLTranslatableString, author: ZLTranslatableString,
         description: ZLTranslatableString, versionCode: Int, versionName: String) {
        self.name = name
        self.author = author
        self.description = description
        self.versionCode = versionCode
        self.versionName = versionName
    }

    private enum CodingKeys: String, CodingKey {
        case name, author, description, versionCode, versionName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.zl(.name, ZLTranslatableString())
        author = c.zl(.author, ZLTranslatableString())
        description = c.zl(.description, ZLTranslatableString())
        versionCode = c.zl(.versionCode, 0)
        versionName = c.zl(.versionName, "")
    }
}

// MARK: - 版本不兼容
struct ZLUnsupportedVersionError: LocalizedError {
    var version: Int
    var errorDescription: String? {
        "布局版本 \(version) 高于当前支持的 \(ZLControlLayout.currentEditorVersion)，无法导入"
    }
}

// MARK: - 完整布局（对齐 ControlLayout）
struct ZLControlLayout: Codable, Equatable, Identifiable, Sendable {
    /// 对齐 Version.kt 的 EDITOR_VERSION
    static let currentEditorVersion = 12

    var id = UUID()
    var info: ZLLayoutInfo
    var layers: [ZLLayer]
    var styles: [ZLButtonStyle]
    var joystickStyles: [ZLJoystickStyle]
    var editorVersion: Int

    init(info: ZLLayoutInfo,
         layers: [ZLLayer] = [],
         styles: [ZLButtonStyle] = [],
         joystickStyles: [ZLJoystickStyle] = [],
         editorVersion: Int = ZLControlLayout.currentEditorVersion) {
        self.info = info
        self.layers = layers
        self.styles = styles
        self.joystickStyles = joystickStyles
        self.editorVersion = editorVersion
    }

    private enum CodingKeys: String, CodingKey {
        case info, layers, styles, joystickStyles, editorVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        info = c.zl(.info, ZLLayoutInfo(name: ""))
        layers = c.zl(.layers, [])
        styles = c.zl(.styles, [])
        joystickStyles = c.zl(.joystickStyles, [])
        editorVersion = c.zl(.editorVersion, ZLControlLayout.currentEditorVersion)
    }

    static var empty: ZLControlLayout {
        ZLControlLayout(info: ZLLayoutInfo(name: "新的控制布局"))
    }

    /// 默认布局（键盘常用键 + WASD + 摇杆）
    static var defaultLayout: ZLControlLayout {
        var layout = ZLControlLayout.empty
        var layer = ZLLayer(name: "默认", uuid: UUID().uuidString)

        let keyboardKeys: [(String, String, Int, Int)] = [
            ("ESC", "GLFW_KEY_ESCAPE", 600, 300),
            ("F3", "GLFW_KEY_F3", 1400, 300),
            ("F5", "GLFW_KEY_F5", 2200, 300),
            ("Tab", "GLFW_KEY_TAB", 3000, 300),
            ("Ctrl", "GLFW_KEY_LEFT_CONTROL", 3800, 300),
            ("Alt", "GLFW_KEY_LEFT_ALT", 4600, 300),
            ("输入法", "GLFW_KEY_UNKNOWN", 5400, 300)
        ]
        let wasd: [(String, String, Int, Int)] = [
            ("W", "GLFW_KEY_W", 1600, 6500),
            ("A", "GLFW_KEY_A", 900, 7200),
            ("S", "GLFW_KEY_S", 1600, 7200),
            ("D", "GLFW_KEY_D", 2300, 7200)
        ]
        let actions: [(String, String, Int, Int)] = [
            ("跳", "GLFW_KEY_SPACE", 8800, 6800),
            ("蹲", "GLFW_KEY_LEFT_SHIFT", 7500, 7800),
            ("背包", "GLFW_KEY_E", 9000, 5600)
        ]

        for (label, key, x, y) in keyboardKeys + wasd + actions {
            let button = ZLNormalButton(
                text: ZLTranslatableString(label),
                uuid: UUID().uuidString,
                position: ZLButtonPosition(x: x, y: y),
                buttonSize: ZLButtonSize(widthPercentage: 700, heightPercentage: 500,
                                         widthReference: .screenWidth, heightReference: .screenHeight),
                clickEvents: [.key(key)]
            )
            layer.normalButtons.append(button)
        }

        var stick = ZLJoystick(uuid: UUID().uuidString,
                               position: ZLButtonPosition(x: 4200, y: 7800),
                               sizePercentage: 2500)
        stick.directionEvents = ZLJoystickDefaults.directionEvents
        stick.lockEvents = ZLJoystickDefaults.lockEvents
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

    /// 导入 ZL2 的布局 JSON（含版本检查与旧版迁移）
    static func importJSON(_ data: Data) throws -> ZLControlLayout {
        var layout = try JSONDecoder().decode(ZLControlLayout.self, from: data)
        guard layout.editorVersion <= currentEditorVersion else {
            throw ZLUnsupportedVersionError(version: layout.editorVersion)
        }
        layout.migrateIfNeeded()
        return layout
    }

    /// 对齐 Version.kt 的 updateLayoutToNew（只做真正改动字段的迁移）
    /// - 1 → 2：位置与百分比 ×10（精度从 1% 提到 0.01%）
    /// - 2 → 3：hideWhenMouse / hideWhenGamepad = true（解码默认值已一致）
    /// - 3 → 4：文本对齐/粗体/斜体/下划线取默认值（解码默认值已一致）
    /// - 10 → 11：commonStyle = false
    mutating func migrateIfNeeded() {
        let version = editorVersion
        if version <= 1 {
            for layerIndex in layers.indices {
                for index in layers[layerIndex].normalButtons.indices {
                    var button = layers[layerIndex].normalButtons[index]
                    button.position = ZLButtonPosition(x: button.position.x * 10,
                                                       y: button.position.y * 10)
                    button.buttonSize = ZLButtonSize(
                        type: button.buttonSize.type,
                        widthDp: button.buttonSize.widthDp,
                        heightDp: button.buttonSize.heightDp,
                        widthPercentage: button.buttonSize.widthPercentage * 10,
                        heightPercentage: button.buttonSize.heightPercentage * 10,
                        widthReference: button.buttonSize.widthReference,
                        heightReference: button.buttonSize.heightReference)
                    layers[layerIndex].normalButtons[index] = button
                }
                for index in layers[layerIndex].textBoxes.indices {
                    var text = layers[layerIndex].textBoxes[index]
                    text.position = ZLButtonPosition(x: text.position.x * 10,
                                                     y: text.position.y * 10)
                    text.buttonSize = ZLButtonSize(
                        type: text.buttonSize.type,
                        widthDp: text.buttonSize.widthDp,
                        heightDp: text.buttonSize.heightDp,
                        widthPercentage: text.buttonSize.widthPercentage * 10,
                        heightPercentage: text.buttonSize.heightPercentage * 10,
                        widthReference: text.buttonSize.widthReference,
                        heightReference: text.buttonSize.heightReference)
                    layers[layerIndex].textBoxes[index] = text
                }
            }
        }
        if version <= 10 {
            for index in styles.indices {
                styles[index].commonStyle = false
            }
        }
        editorVersion = ZLControlLayout.currentEditorVersion
    }
}
