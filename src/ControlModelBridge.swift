// ZL2-iOS · 控件模型桥接层
// 编辑器内部用 ControlItem（UI 友好，0~1 归一化）
// 对外用 ZLControlLayout（与 ZL2 互通，0~10000 整数坐标）
import SwiftUI

extension ControlItem {
    /// 转为 ZL2 的 NormalButton
    func toZL2(styleUUID: String? = nil) -> ZLNormalButton {
        var b = ZLNormalButton(
            text: label,
            uuid: id.uuidString,
            position: ZLButtonPosition(x: Int((x * 10000).rounded()),
                                       y: Int((y * 10000).rounded())),
            buttonSize: ZLButtonSize(
                widthDp: 44,
                heightDp: 44,
                widthPercentage: Int((width * 10000).rounded()),
                heightPercentage: Int((height * 10000).rounded()),
                mode: .percentage
            )
        )
        b.buttonStyle = styleUUID
        b.textAlignment = .center
        b.isToggleable = false
        b.isSwipple = true
        b.isPenetrable = false
        // 优先用真实的按键事件（导入的 ZL2 布局），否则按动作映射
        if !keyEvent.isEmpty {
            b.clickEvents = [.key(keyEvent)]
        } else {
            b.clickEvents = [action.toZL2Event(text: textToSend)]
        }
        return b
    }

    /// 从 ZL2 的 NormalButton 创建
    static func fromZL2(_ b: ZLNormalButton) -> ControlItem {
        var item = ControlItem(kind: .button, label: b.text,
                               x: b.position.xPercent, y: b.position.yPercent)
        item.width = b.buttonSize.widthPercentOfScreen
        item.height = b.buttonSize.heightPercentOfScreen
        // 取第一个事件（保留按键，不要退化成 sendText）
        for e in b.clickEvents {
            switch e {
            case .key(let k):
                item.keyEvent = k
                break
            case .sendText(let t):
                item.action = .sendText
                item.textToSend = t
                break
            default:
                item.action = ControlAction.fromZL2(e)
                break
            }
        }
        return item
    }

    /// 转为 ZL2 的文本框
    func toZL2Text() -> ZLTextWidget {
        ZLTextWidget(text: label,
                     uuid: id.uuidString,
                     position: ZLButtonPosition(x: Int((x * 10000).rounded()),
                                                y: Int((y * 10000).rounded())),
                     buttonSize: ZLButtonSize(widthDp: 60, heightDp: 24,
                                              widthPercentage: Int((width * 10000).rounded()),
                                              heightPercentage: Int((height * 10000).rounded()),
                                              mode: .percentage),
                     textAlignment: .left)
    }

    /// 转为 ZL2 的摇杆
    func toZL2Joystick() -> ZLJoystick {
        ZLJoystick(uuid: id.uuidString,
                   position: ZLButtonPosition(x: Int((x * 10000).rounded()),
                                              y: Int((y * 10000).rounded())),
                   buttonSize: ZLButtonSize(widthDp: 120, heightDp: 120,
                                            widthPercentage: Int((width * 10000).rounded()),
                                            heightPercentage: Int((height * 10000).rounded()),
                                            mode: .percentage),
                   deadZone: stick.deadZone,
                   lockThreshold: stick.lockThreshold)
    }
}

extension ControlAction {
    /// 动作 → ZL2 事件
    func toZL2Event(text: String) -> ZLClickEvent {
        switch self {
        case .toggleMenu:   return .launcherEvent("toggle_menu")
        case .mouseLeft:    return .launcherEvent("mouse_left")
        case .mouseMiddle:  return .launcherEvent("mouse_middle")
        case .mouseRight:   return .launcherEvent("mouse_right")
        case .wheelUp:      return .launcherEvent("wheel_up")
        case .wheelDown:    return .launcherEvent("wheel_down")
        case .sendText:     return .sendText(text)
        case .none:         return .launcherEvent("none")
        }
    }

    /// ZL2 事件 → 动作
    static func fromZL2(_ e: ZLClickEvent) -> ControlAction {
        switch e {
        case .key:
            return .none       // 按键由 keyEvent 字段承载，不走动作
        case .launcherEvent(let v):
            switch v {
            case "toggle_menu":  return .toggleMenu
            case "mouse_left":   return .mouseLeft
            case "mouse_middle": return .mouseMiddle
            case "mouse_right":  return .mouseRight
            case "wheel_up":     return .wheelUp
            case "wheel_down":   return .wheelDown
            default:             return .none
            }
        case .sendText:      return .sendText
        case .switchLayer:   return .none
        case .showLayer:     return .none
        case .hideLayer:     return .none
        }
    }
}

extension ZLControlLayout {
    /// 从编辑器的 ControlLayoutDoc 生成 ZL2 布局
    static func from(doc: ControlLayoutDoc) -> ZLControlLayout {
        var layout = ZLControlLayout(info: ZLLayoutInfo(name: doc.name,
                                                        author: doc.author,
                                                        description: doc.desc,
                                                        versionCode: 1,
                                                        versionName: doc.version))
        layout.editorVersion = 12

        for layer in doc.layers {
            var zlLayer = ZLLayer(name: layer.name, uuid: layer.id.uuidString)
            zlLayer.hide = layer.hiddenByDefault
            zlLayer.hideWhenMouse = layer.hiddenByMouse
            zlLayer.hideWhenGamepad = layer.hiddenByGamepad
            for item in layer.items {
                switch item.kind {
                case .button: zlLayer.normalButtons.append(item.toZL2())
                case .text:   zlLayer.textBoxes.append(item.toZL2Text())
                case .stick:  zlLayer.joystickButtons.append(item.toZL2Joystick())
                }
            }
            layout.layers.append(zlLayer)
        }

        // 导出样式收藏柜
        for a in doc.styleVault {
            var s = ZLButtonStyle(name: a.name.isEmpty ? "样式" : a.name,
                                  uuid: a.id.uuidString,
                                  lightStyle: ZLStyleConfig(),
                                  darkStyle: ZLStyleConfig())
            s.lightStyle.alpha = a.normalOpacity
            s.darkStyle.alpha = a.normalOpacity
            s.lightStyle.borderWidth = Int(a.borderWidth)
            s.darkStyle.borderWidth = Int(a.borderWidth)
            s.lightStyle.backgroundColor = ZLColorValue(argb: a.backgroundHex)
            s.darkStyle.backgroundColor = ZLColorValue(argb: a.backgroundHex)
            s.lightStyle.contentColor = ZLColorValue(argb: a.contentHex)
            s.darkStyle.contentColor = ZLColorValue(argb: a.contentHex)
            s.lightStyle.borderRadius = .uniform(8)
            s.darkStyle.borderRadius = .uniform(8)
            layout.styles.append(s)
        }

        return layout
    }

    /// 转回编辑器的 ControlLayoutDoc
    func toDoc() -> ControlLayoutDoc {
        var doc = ControlLayoutDoc(name: info.name, author: info.author,
                                   version: info.versionName, desc: info.description,
                                   layers: [])
        doc.layers = layers.map { l in
            var cl = ControlLayer(name: l.name, items: [])
            cl.hiddenByDefault = l.hide
            cl.hiddenByMouse = l.hideWhenMouse
            cl.hiddenByGamepad = l.hideWhenGamepad
            cl.items = l.normalButtons.map { ControlItem.fromZL2($0) }
            // 文本框
            for t in l.textBoxes {
                var item = ControlItem(kind: .text, label: t.text,
                                       x: t.position.xPercent, y: t.position.yPercent)
                item.width = t.buttonSize.widthPercentOfScreen
                item.height = t.buttonSize.heightPercentOfScreen
                cl.items.append(item)
            }
            // 摇杆
            for j in l.joystickButtons {
                var item = ControlItem(kind: .stick, label: "摇杆",
                                       x: j.position.xPercent, y: j.position.yPercent)
                item.width = j.buttonSize.widthPercentOfScreen
                item.height = j.buttonSize.heightPercentOfScreen
                cl.items.append(item)
            }
            return cl
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
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("control_layouts", isDirectory: true)
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
        let n = name ?? layout.info.name
        let url = dir.appendingPathComponent("\(n).json")
        guard let data = try? layout.exportJSON() else { return false }
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
