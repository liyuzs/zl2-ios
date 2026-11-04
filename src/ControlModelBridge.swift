// ZL2-iOS · 控件模型桥接层
// 编辑器内部用 ControlItem（UI 友好，0~1 归一化，x/y 是控件中心点）
// 对外用 ZLControlLayout（与 ZL2 互通，0~10000 整数坐标，x/y 是控件左上角在
// 「屏幕尺寸 - 控件尺寸」上的百分比，见 LayerController/utils/Buttons.kt 的 widgetPosition）
import SwiftUI

// MARK: - 坐标换算（中心点 0~1 ↔ ZL2 的 0~10000）
enum ZLCoordinateTransform {
    /// 编辑器中心点坐标 → ZL2 位置
    static func position(centerX: Double,
                         centerY: Double,
                         widthFraction: Double,
                         heightFraction: Double) -> ZLButtonPosition {
        let w = min(max(widthFraction, 0.01), 0.99)
        let h = min(max(heightFraction, 0.01), 0.99)
        let x = (centerX - w / 2) / (1 - w)
        let y = (centerY - h / 2) / (1 - h)
        return ZLButtonPosition(x: Int((x * 10000).rounded()),
                                y: Int((y * 10000).rounded()))
    }

    /// ZL2 位置 → 编辑器中心点坐标
    static func center(xPercent: Double,
                       yPercent: Double,
                       widthFraction: Double,
                       heightFraction: Double) -> (x: Double, y: Double) {
        let w = min(max(widthFraction, 0.01), 0.99)
        let h = min(max(heightFraction, 0.01), 0.99)
        let x = xPercent * (1 - w) + w / 2
        let y = yPercent * (1 - h) + h / 2
        return (min(max(x, 0), 1), min(max(y, 0), 1))
    }
}

// MARK: - 可见场景 / 文本对齐 换算
extension VisibleScene {
    func toZL2() -> ZLVisibilityType {
        switch self {
        case .always:  return .always
        case .inGame:  return .inGame
        case .outGame: return .inMenu
        }
    }
}

extension ZLVisibilityType {
    func toVisibleScene() -> VisibleScene {
        switch self {
        case .always: return .always
        case .inGame: return .inGame
        case .inMenu: return .outGame
        }
    }
}

extension ControlTextAlignment {
    func toZL2() -> ZLTextAlignment {
        switch self {
        case .left:   return .left
        case .center: return .center
        case .right:  return .right
        }
    }

    static func from(zl alignment: ZLTextAlignment) -> ControlTextAlignment {
        switch alignment {
        case .left:   return .left
        case .center: return .center
        case .right:  return .right
        }
    }
}

// MARK: - 外观 ↔ ButtonStyle
extension ControlAppearance {
    /// 编辑器外观 → ZL2 的 ButtonStyle（uuid 由外部指定，供控件引用）
    func toZL2Style(uuid: String) -> ZLButtonStyle {
        let zlCorners = ZLCorners(topStart: corners.topLeft,
                                  topEnd: corners.topRight,
                                  bottomEnd: corners.bottomRight,
                                  bottomStart: corners.bottomLeft)

        var light = ZLStyleConfig()
        light.alpha = normalOpacity
        light.pressedAlpha = pressedOpacity
        light.backgroundColor = ZLColorValue(rgb: backgroundHex)
        light.pressedBackgroundColor = ZLColorValue(rgb: backgroundHex)
        light.contentColor = ZLColorValue(rgb: contentHex)
        light.pressedContentColor = ZLColorValue(rgb: contentHex)
        light.borderWidth = Int(borderWidth.rounded())
        light.pressedBorderWidth = Int(borderWidth.rounded())
        light.borderColor = ZLColorValue(rgb: borderHex)
        light.pressedBorderColor = ZLColorValue(rgb: borderHex)
        light.borderRadius = zlCorners
        light.pressedBorderRadius = zlCorners

        var dark = light
        dark.alpha = darkNormalOpacity
        dark.pressedAlpha = darkPressedOpacity
        dark.backgroundColor = ZLColorValue(rgb: darkBackgroundHex)
        dark.pressedBackgroundColor = ZLColorValue(rgb: darkBackgroundHex)
        dark.contentColor = ZLColorValue(rgb: darkContentHex)
        dark.pressedContentColor = ZLColorValue(rgb: darkContentHex)
        dark.borderColor = ZLColorValue(rgb: darkBorderHex)
        dark.pressedBorderColor = ZLColorValue(rgb: darkBorderHex)

        return ZLButtonStyle(name: name.isEmpty ? "样式" : name,
                             uuid: uuid,
                             animateSwap: animated,
                             commonStyle: !separateDark,
                             lightStyle: light,
                             darkStyle: dark)
    }

    /// ZL2 的 ButtonStyle → 编辑器外观
    static func from(zl style: ZLButtonStyle) -> ControlAppearance {
        var appearance = ControlAppearance()
        appearance.name = style.name
        appearance.normalOpacity = style.lightStyle.alpha
        appearance.pressedOpacity = style.lightStyle.pressedAlpha
        appearance.backgroundHex = style.lightStyle.backgroundColor.argb & 0xFFFFFF
        appearance.contentHex = style.lightStyle.contentColor.argb & 0xFFFFFF
        appearance.borderWidth = Double(style.lightStyle.borderWidth)
        appearance.borderHex = style.lightStyle.borderColor.argb & 0xFFFFFF
        appearance.corners = ControlCorners(topLeft: style.lightStyle.borderRadius.topStart,
                                            topRight: style.lightStyle.borderRadius.topEnd,
                                            bottomLeft: style.lightStyle.borderRadius.bottomStart,
                                            bottomRight: style.lightStyle.borderRadius.bottomEnd)
        appearance.animated = style.animateSwap
        appearance.separateDark = !style.commonStyle
        appearance.darkBackgroundHex = style.darkStyle.backgroundColor.argb & 0xFFFFFF
        appearance.darkContentHex = style.darkStyle.contentColor.argb & 0xFFFFFF
        appearance.darkBorderHex = style.darkStyle.borderColor.argb & 0xFFFFFF
        appearance.darkNormalOpacity = style.darkStyle.alpha
        appearance.darkPressedOpacity = style.darkStyle.pressedAlpha
        return appearance
    }
}

// MARK: - 编辑器控件 ↔ ZL2 控件
extension ControlItem {
    /// 转为 ZL2 的 NormalData
    func toZL2(styleUUID: String? = nil) -> ZLNormalButton {
        let widthFraction = min(max(width, 0.01), 0.99)
        let heightFraction = min(max(height, 0.01), 0.99)
        var button = ZLNormalButton(
            text: ZLTranslatableString(label),
            uuid: id.uuidString,
            position: ZLCoordinateTransform.position(centerX: x, centerY: y,
                                                    widthFraction: widthFraction,
                                                    heightFraction: heightFraction),
            buttonSize: ZLButtonSize(type: .percentage,
                                     widthDp: 44,
                                     heightDp: 44,
                                     widthPercentage: Int((widthFraction * 10000).rounded()),
                                     heightPercentage: Int((heightFraction * 10000).rounded()),
                                     widthReference: .screenWidth,
                                     heightReference: .screenHeight),
            buttonStyle: styleUUID,
            textAlignment: textAlignment.toZL2(),
            textBold: textBold,
            textItalic: textItalic,
            textUnderline: textUnderline,
            visibilityType: visibleScene.toZL2(),
            clickEvents: zl2ClickEvents(),
            isSwipple: isSwipple,
            isPenetrable: isPenetrable,
            isToggleable: isToggleable
        )
        button.filterValidEvents()
        return button
    }

    /// 点击事件：优先用导入时保留的真实按键，否则按动作映射
    func zl2ClickEvents() -> [ZLClickEvent] {
        if !keyEvent.isEmpty {
            return [.key(keyEvent)]
        }
        if let event = action.toZL2Event(text: textToSend) {
            return [event]
        }
        return []
    }

    /// 从 ZL2 的 NormalData 创建
    static func fromZL2(_ b: ZLNormalButton, appearance: ControlAppearance? = nil) -> ControlItem {
        let widthFraction = min(max(b.buttonSize.widthPercentOfScreen, 0.01), 0.99)
        let heightFraction = min(max(b.buttonSize.heightPercentOfScreen, 0.01), 0.99)
        let center = ZLCoordinateTransform.center(xPercent: b.position.xPercent,
                                                  yPercent: b.position.yPercent,
                                                  widthFraction: widthFraction,
                                                  heightFraction: heightFraction)

        var item = ControlItem(kind: .button,
                               label: b.text.plainText,
                               x: center.x,
                               y: center.y,
                               width: widthFraction,
                               height: heightFraction)
        item.textBold = b.textBold
        item.textItalic = b.textItalic
        item.textUnderline = b.textUnderline
        item.textAlignment = ControlTextAlignment.from(zl: b.textAlignment)
        item.visibleScene = b.visibilityType.toVisibleScene()
        item.isSwipple = b.isSwipple
        item.isPenetrable = b.isPenetrable
        item.isToggleable = b.isToggleable
        if let appearance = appearance {
            item.appearance = appearance
        }
        // 取第一个事件（保留按键，不要退化成 sendText）
        for e in b.clickEvents {
            switch e.type {
            case .key:
                item.keyEvent = e.value
            case .sendText:
                item.action = .sendText
                item.textToSend = e.value
            case .launcherEvent:
                item.action = ControlAction.fromZL2(e)
            case .switchLayer, .showLayer, .hideLayer:
                // 引擎侧控件层事件在 iOS 编辑器里暂无对应动作
                break
            }
        }
        return item
    }

    /// 转为 ZL2 的 TextData
    func toZL2Text(styleUUID: String? = nil) -> ZLTextWidget {
        let widthFraction = min(max(width, 0.01), 0.99)
        let heightFraction = min(max(height, 0.01), 0.99)
        return ZLTextWidget(text: ZLTranslatableString(label),
                            uuid: id.uuidString,
                            position: ZLCoordinateTransform.position(centerX: x, centerY: y,
                                                                    widthFraction: widthFraction,
                                                                    heightFraction: heightFraction),
                            buttonSize: ZLButtonSize(type: .percentage,
                                                     widthDp: 60,
                                                     heightDp: 24,
                                                     widthPercentage: Int((widthFraction * 10000).rounded()),
                                                     heightPercentage: Int((heightFraction * 10000).rounded()),
                                                     widthReference: .screenWidth,
                                                     heightReference: .screenHeight),
                            buttonStyle: styleUUID,
                            textAlignment: textAlignment.toZL2(),
                            textBold: textBold,
                            textItalic: textItalic,
                            textUnderline: textUnderline,
                            visibilityType: visibleScene.toZL2())
    }

    /// 从 ZL2 的 TextData 创建
    static func fromZL2Text(_ t: ZLTextWidget, appearance: ControlAppearance? = nil) -> ControlItem {
        let widthFraction = min(max(t.buttonSize.widthPercentOfScreen, 0.01), 0.99)
        let heightFraction = min(max(t.buttonSize.heightPercentOfScreen, 0.01), 0.99)
        let center = ZLCoordinateTransform.center(xPercent: t.position.xPercent,
                                                  yPercent: t.position.yPercent,
                                                  widthFraction: widthFraction,
                                                  heightFraction: heightFraction)
        var item = ControlItem(kind: .text,
                               label: t.text.plainText,
                               x: center.x,
                               y: center.y,
                               width: widthFraction,
                               height: heightFraction)
        item.visibleScene = t.visibilityType.toVisibleScene()
        item.textAlignment = ControlTextAlignment.from(zl: t.textAlignment)
        item.textBold = t.textBold
        item.textItalic = t.textItalic
        item.textUnderline = t.textUnderline
        item.isSwipple = false
        item.isPenetrable = false
        item.isToggleable = false
        if let appearance = appearance {
            item.appearance = appearance
        }
        return item
    }

    /// 转为 ZL2 的 JoystickData（ZL2 的摇杆是正方形，尺寸按屏幕高度百分比）
    func toZL2Joystick() -> ZLJoystick {
        let heightFraction = min(max(height, 0.01), 0.99)
        let widthFraction = heightFraction
        return ZLJoystick(uuid: id.uuidString,
                          position: ZLCoordinateTransform.position(centerX: x, centerY: y,
                                                                  widthFraction: widthFraction,
                                                                  heightFraction: heightFraction),
                          sizeType: .percentage,
                          sizeDp: 200,
                          sizePercentage: Int((heightFraction * 10000).rounded()),
                          visibilityType: visibleScene.toZL2(),
                          joystickStyleId: nil,
                          deadZoneRatio: min(max(stick.deadZone, 0), 0.9),
                          lockThreshold: min(max(stick.lockThreshold, 0), 1),
                          canLock: stick.forwardLock,
                          triggerMode: stick.triggerMode.toZL2(),
                          directionEvents: ZLJoystickDefaults.directionEvents,
                          lockEvents: ZLJoystickDefaults.lockEvents)
    }

    /// 从 ZL2 的 JoystickData 创建
    static func fromZL2Joystick(_ j: ZLJoystick) -> ControlItem {
        let sizeFraction = min(max(Double(j.sizePercentage) / 10000.0, 0.02), 0.99)
        let center = ZLCoordinateTransform.center(xPercent: j.position.xPercent,
                                                  yPercent: j.position.yPercent,
                                                  widthFraction: sizeFraction,
                                                  heightFraction: sizeFraction)
        var item = ControlItem(kind: .stick,
                               label: "摇杆",
                               x: center.x,
                               y: center.y,
                               width: sizeFraction,
                               height: sizeFraction)
        item.visibleScene = j.visibilityType.toVisibleScene()
        item.stick.deadZone = j.deadZoneRatio
        item.stick.lockThreshold = j.lockThreshold
        item.stick.forwardLock = j.canLock
        item.stick.triggerMode = StickTriggerMode.from(zl: j.triggerMode)
        item.stick.size = 1.0
        return item
    }
}

// MARK: - 摇杆配置换算
extension StickTriggerMode {
    func toZL2() -> ZLJoystickTriggerMode {
        switch self {
        case .drag:  return .drag
        case .touch: return .touch
        }
    }

    static func from(zl mode: ZLJoystickTriggerMode) -> StickTriggerMode {
        switch mode {
        case .drag:  return .drag
        case .touch: return .touch
        }
    }
}

// MARK: - 点击动作 ↔ ZL2 事件
extension ControlAction {
    /// 动作 → ZL2 事件（keys 见 ZalithLauncher/ui/control/event/Events.kt）
    func toZL2Event(text: String) -> ZLClickEvent? {
        switch self {
        case .toggleMenu:   return .launcherEvent(ZLLauncherEventKey.switchMenu)
        case .mouseLeft:    return .launcherEvent(ZLLauncherEventKey.mouseLeft)
        case .mouseMiddle:  return .launcherEvent(ZLLauncherEventKey.mouseMiddle)
        case .mouseRight:   return .launcherEvent(ZLLauncherEventKey.mouseRight)
        case .wheelUp:      return .launcherEvent(ZLLauncherEventKey.scrollUpSingle)
        case .wheelDown:    return .launcherEvent(ZLLauncherEventKey.scrollDownSingle)
        case .sendText:     return text.isEmpty ? nil : .sendText(text)
        case .none:         return nil
        }
    }

    /// ZL2 事件 → 动作
    static func fromZL2(_ e: ZLClickEvent) -> ControlAction {
        switch e.type {
        case .key:
            return .none       // 按键由 keyEvent 字段承载，不走动作
        case .launcherEvent:
            switch e.value {
            case ZLLauncherEventKey.switchMenu:       return .toggleMenu
            case ZLLauncherEventKey.mouseLeft:        return .mouseLeft
            case ZLLauncherEventKey.mouseMiddle:      return .mouseMiddle
            case ZLLauncherEventKey.mouseRight:       return .mouseRight
            case ZLLauncherEventKey.scrollUpSingle:   return .wheelUp
            case ZLLauncherEventKey.scrollDownSingle: return .wheelDown
            default:                                  return .none
            }
        case .sendText:   return .sendText
        case .switchLayer: return .none
        case .showLayer:   return .none
        case .hideLayer:   return .none
        }
    }
}

// MARK: - 布局文档 ↔ ZL2 布局
extension ZLControlLayout {
    /// 从编辑器的 ControlLayoutDoc 生成 ZL2 布局
    static func from(doc: ControlLayoutDoc) -> ZLControlLayout {
        var layout = ZLControlLayout(info: ZLLayoutInfo(name: doc.name,
                                                        author: doc.author,
                                                        description: doc.desc,
                                                        versionCode: 1,
                                                        versionName: doc.version))
        layout.editorVersion = ZLControlLayout.currentEditorVersion

        // 控件外观按值去重成 ButtonStyle，控件通过 uuid 引用（ZL2 找不到样式时会退回默认样式）
        var usedStyles: [(appearance: ControlAppearance, uuid: String)] = []
        func styleUUID(for appearance: ControlAppearance) -> String {
            if let hit = usedStyles.first(where: { $0.appearance == appearance }) {
                return hit.uuid
            }
            let uuid = appearance.id.uuidString
            usedStyles.append((appearance: appearance, uuid: uuid))
            return uuid
        }

        for layer in doc.layers {
            var zlLayer = ZLLayer(name: layer.name,
                                  uuid: layer.id.uuidString,
                                  hide: layer.hiddenByDefault,
                                  hideWhenMouse: layer.hiddenByMouse,
                                  hideWhenGamepad: layer.hiddenByGamepad,
                                  visibilityType: layer.visibleScene.toZL2())
            for item in layer.items {
                switch item.kind {
                case .button:
                    zlLayer.normalButtons.append(item.toZL2(styleUUID: styleUUID(for: item.appearance)))
                case .text:
                    zlLayer.textBoxes.append(item.toZL2Text(styleUUID: styleUUID(for: item.appearance)))
                case .stick:
                    zlLayer.joystickButtons.append(item.toZL2Joystick())
                }
            }
            layout.layers.append(zlLayer)
        }

        // 布局里备着但尚未被引用的样式也一并导出
        var knownUUIDs = Set(usedStyles.map { $0.uuid })
        for style in doc.styleVault {
            let uuid = style.id.uuidString
            if !knownUUIDs.contains(uuid) {
                usedStyles.append((appearance: style, uuid: uuid))
                knownUUIDs.insert(uuid)
            }
        }

        layout.styles = usedStyles.map { $0.appearance.toZL2Style(uuid: $0.uuid) }
        return layout
    }

    /// 转回编辑器的 ControlLayoutDoc
    func toDoc() -> ControlLayoutDoc {
        var doc = ControlLayoutDoc(name: info.name.plainText,
                                   author: info.author.plainText,
                                   version: info.versionName,
                                   desc: info.description.plainText,
                                   layers: [])

        var appearanceByUUID: [String: ControlAppearance] = [:]
        for style in styles {
            appearanceByUUID[style.uuid] = ControlAppearance.from(zl: style)
        }
        doc.styleVault = styles.map { ControlAppearance.from(zl: $0) }

        doc.layers = layers.map { layer in
            var controlLayer = ControlLayer(name: layer.name, items: [])
            controlLayer.hiddenByDefault = layer.hide
            controlLayer.hiddenByMouse = layer.hideWhenMouse
            controlLayer.hiddenByGamepad = layer.hideWhenGamepad
            controlLayer.visibleScene = layer.visibilityType.toVisibleScene()

            for button in layer.normalButtons {
                let appearance = button.buttonStyle.flatMap { appearanceByUUID[$0] }
                controlLayer.items.append(ControlItem.fromZL2(button, appearance: appearance))
            }
            for text in layer.textBoxes {
                let appearance = text.buttonStyle.flatMap { appearanceByUUID[$0] }
                controlLayer.items.append(ControlItem.fromZL2Text(text, appearance: appearance))
            }
            for joystick in layer.joystickButtons {
                controlLayer.items.append(ControlItem.fromZL2Joystick(joystick))
            }
            return controlLayer
        }

        if doc.layers.isEmpty {
            doc.layers = [ControlLayer(name: "默认", items: [])]
        }
        return doc
    }
}

// MARK: - 布局文件管理（与 ZL2 相同目录结构）
enum ZLLayoutStore {
    static var dir: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let d = documents.appendingPathComponent("control_layouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func list() -> [(name: String, url: URL)] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir,
                                                            includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .map { ($0.deletingPathExtension().lastPathComponent, $0) }
            .sorted { $0.0 < $1.0 }
    }

    @discardableResult
    static func save(_ layout: ZLControlLayout, as name: String? = nil) -> Bool {
        let n = name ?? layout.info.name.plainText
        let url = dir.appendingPathComponent("\(n).json")
        guard let data = try? layout.exportJSON() else { return false }
        return (try? data.write(to: url)) != nil
    }

    /// 按名字读原始 JSON（编辑器用，保留编辑器自有格式）
    static func loadRaw(name: String) -> Data? {
        let url = dir.appendingPathComponent("\(name).json")
        return try? Data(contentsOf: url)
    }

    /// 按名字写原始 JSON
    @discardableResult
    static func saveRaw(name: String, data: Data) -> Bool {
        let url = dir.appendingPathComponent("\(name).json")
        return (try? data.write(to: url)) != nil
    }

    static func load(_ url: URL) -> ZLControlLayout? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? ZLControlLayout.importJSON(data)
    }

    @discardableResult
    static func delete(_ url: URL) -> Bool {
        (try? FileManager.default.removeItem(at: url)) != nil
    }
}
