//
//  CoreLayoutExport.swift
//  ZL2-iOS · 把编辑器画的控制布局翻译成核心能读的格式
//
//  ────────────────────────────────────────────────────────────
//  为什么需要这一层：
//
//  编辑器存的是 **ZL2 格式**（ZLControlLayout）：
//    · 坐标 0~10000 整数千分比（ZLButtonPosition）
//    · 图层分层（ZLLayer → normalButtons / textBoxes / joystickButtons）
//    · 样式靠 uuid 间接引用（buttonStyle: String? → styles: [ZLButtonStyle]）
//
//  核心（Amethyst / Pojav 的 ControlLayout）读的是 **Pojav 格式**：
//    · dynamicX / dynamicY 是浮点比例 0~1
//    · 扁平数组 mControlDataList，靠 type 区分 button / joystick
//    · 样式直接内联到每个控件上
//
//  两种格式不通用。没有这一层，用户在编辑器里辛苦调好的按钮位置，
//  进游戏后完全看不到。
//  ────────────────────────────────────────────────────────────

import Foundation
import UIKit

// MARK: - 导出器

enum CoreLayoutExporter {

    // MARK: 路径

    /// 核心读布局的目录：<AME_HOME>/controlmap/
    static var controlMapDir: URL {
        let home = ProcessInfo.processInfo.environment["AME_HOME"]
            ?? (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("amethyst").path ?? NSTemporaryDirectory())
        let dir = URL(fileURLWithPath: home).appendingPathComponent("controlmap", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 核心当前使用的布局文件名
    ///
    /// 这里有个踩过的坑，值得写清楚：这个项目里有**三套互不相通**的存储，
    /// 光写 UserDefaults 是不能让核心知道该加载哪个布局的。
    ///
    /// 核心读布局名的位置是 SurfaceViewController.m:464：
    ///     [PLProfiles resolveKeyForCurrentProfile:@"defaultTouchCtrl"]
    /// 而 PLProfiles.m:35 的 resolveKey: 只查两处：
    ///   ① profile["defaultTouchCtrl"] → <GAME_DIR>/launcher_profiles.json
    ///   ② 兜底 getPrefObject("control.default_ctrl") → PLPreferences 的 plist
    ///
    /// 所以：UserDefaults 只是本 App 自己的记账本，
    /// 真正要生效必须写 ② 处（这里用 setPrefObject）。① 处留给核心自己的界面改。
    ///
    /// 注：setPrefObject 在 bootstrap()（内部 loadPreferences）之前调用是安全的 ——
    /// 全局 pref 还是 nil，ObjC 对 nil 发消息是静默无操作，不会崩，也不会写脏数据。
    /// 启动时 syncControlLayoutIfNeeded() 会再补一次，那时 pref 一定已就绪。
    static var activeLayoutName: String {
        get { UserDefaults.standard.string(forKey: "control_layout") ?? "default.json" }
        set {
            UserDefaults.standard.set(newValue, forKey: "control_layout")
            // ZL2 设置项 controlLayout（安卓原生的同名字段）
            UserDefaults.standard.set(newValue, forKey: "controlLayout")
            // 让核心真的去加载它（这才是生效的那一步）
            setPrefObject("control.default_ctrl", newValue)
        }
    }

    /// 读取核心当前用的布局文件名 —— 从核心自己的偏好系统读，而不是我们的记账本
    static var coreActiveLayoutName: String {
        (getPrefObject("control.default_ctrl") as? String) ?? "default.json"
    }

    // MARK: 主入口

    /// 把一份 ZL2 布局导出成核心格式，写到 <AME_HOME>/controlmap/<fileName>
    /// - Returns: 写入的文件名（含 .json）
    @discardableResult
    static func export(_ layout: ZLControlLayout, fileName: String? = nil) throws -> String {
        let rawName = layout.info.name.plainText
        let name = fileName ?? (rawName.isEmpty ? "default.json"
                                                : sanitize(rawName) + ".json")

        let coreDict = convert(layout)
        let data = try JSONSerialization.data(withJSONObject: coreDict,
                                              options: [.prettyPrinted, .sortedKeys])
        let url = controlMapDir.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return name
    }

    /// 导出并直接设为当前使用的布局
    @discardableResult
    static func exportAndActivate(_ layout: ZLControlLayout, fileName: String? = nil) throws -> String {
        let name = try export(layout, fileName: fileName)
        activeLayoutName = name
        return name
    }

    // MARK: 核心转换

    /// ZL2 布局 → Pojav 核心字典
    static func convert(_ layout: ZLControlLayout) -> [String: Any] {
        // 先把样式按 uuid 建索引，控件里只是引用
        var styleByUUID: [String: ZLButtonStyle] = [:]
        for s in layout.styles { styleByUUID[s.uuid] = s }

        // 图层 uuid → 序号，供「切换图层」按钮编出伪键码
        var layerIndexByUUID: [String: Int] = [:]
        for (i, layer) in layout.layers.enumerated() where !layer.uuid.isEmpty {
            layerIndexByUUID[layer.uuid] = i
        }

        // 核心把控件分成三个**互不相通**的列表，放错列表就不会被实例化：
        //   mControlDataList  → ControlButton（普通按钮 / 文本框）
        //   mJoystickDataList → ControlJoystick（方向摇杆）
        //   mDrawerDataList   → ControlDrawer（抽屉）
        // 见 core/customcontrols/CustomControlsUtils.m:435 起的 loadControlObject()。
        var buttons: [[String: Any]] = []
        var joysticks: [[String: Any]] = []

        // 核心没有图层概念，把不隐藏的图层平铺成一组控件
        for layer in layout.layers where layer.hide == false {
            for btn in layer.normalButtons {
                buttons.append(convertButton(btn,
                                             style: resolveStyle(btn.buttonStyle, styleByUUID),
                                             layerIndexByUUID: layerIndexByUUID))
            }
            for txt in layer.textBoxes {
                buttons.append(convertTextBox(txt, style: resolveStyle(txt.buttonStyle, styleByUUID)))
            }
            for joy in layer.joystickButtons {
                // 摇杆以前被塞进 mControlDataList，于是核心把它当普通按钮创建，
                // 方向摇杆行为完全没有 —— 进游戏等于没法走路。
                joysticks.append(convertJoystick(joy, layout: layout))
            }
        }

        // version 必须是 8。
        //
        // 核心的 convertLayoutIfNecessary()（CustomControlsUtils.m:199）按这个字段
        // 决定要不要跑旧格式迁移：
        //   case 0/1 → convertV1Layout → V2 → V5 → V7 → V8 整条链
        //   case 8   → break（不动）
        // 原来写的是 1，等于把我们刚生成的 v8 格式当成 v1 去迁移，后果：
        //   · width/height 被 ÷scaledAt×50 → 所有控件尺寸减半
        //   · bgColor / strokeWidth / opacity 被强制覆盖 → 样式全毁
        //   · [keycodes addObject:btnDict[@"keycode"]] 而我们没有 keycode 这个键，
        //     nil 加进 NSMutableArray 会抛 NSInvalidArgumentException → 直接崩
        // 也就是说：只要用户保存过一次自定义布局，进游戏就会崩。
        return [
            "mControlDataList": buttons,
            "mJoystickDataList": joysticks,
            "mDrawerDataList": [[String: Any]](),
            "scaledAt": currentButtonScale(),
            "version": 8,
        ]
    }

    // MARK: 普通按钮

    private static func convertButton(_ btn: ZLNormalButton,
                                      style: ZLStyleConfig?,
                                      layerIndexByUUID: [String: Int] = [:]) -> [String: Any] {
        var d = baseGeometry(position: btn.position, size: btn.buttonSize)
        d["type"] = "button"
        d["name"] = btn.text.plainText
        d["keycodes"] = keycodesOf(btn.clickEvents, layerIndexByUUID: layerIndexByUUID)
        d["isDynamic"] = true

        // 可见性：核心按 isGrabbing 切换两套显示
        //   isGrabbing = true  （鼠标被抓取 = 游戏内）→ 看 displayInGame
        //   isGrabbing = false （菜单状态）           → 看 displayInMenu
        // 见 SurfaceViewController.m:411 updateControlHiddenState:
        //
        // 之前这里把 displayInMenu 恒写成 false，导致菜单状态下所有按钮消失。
        let vis = visibilityFlags(btn.visibilityType)
        d["displayInGame"] = vis.inGame
        d["displayInMenu"] = vis.inMenu

        d["isToggle"] = btn.isToggleable
        d["isSwipeable"] = btn.isSwipple
        d["passThruEnabled"] = btn.isPenetrable

        applyStyle(&d, style: style)

        // 文本对齐
        d["textAlignment"] = btn.textAlignment.rawValue
        return d
    }

    /// ZL2 的三种可见性 → 核心的两个布尔
    ///
    /// | ZL2       | displayInGame | displayInMenu |
    /// |-----------|---------------|---------------|
    /// | always    | true          | true          |
    /// | inGame    | true          | false         |
    /// | inMenu    | false         | true          |
    static func visibilityFlags(_ type: ZLVisibilityType) -> (inGame: Bool, inMenu: Bool) {
        switch type {
        case .always: return (true, true)
        case .inGame: return (true, false)
        case .inMenu: return (false, true)
        }
    }

    // MARK: 文本框

    private static func convertTextBox(_ txt: ZLTextWidget,
                                       style: ZLStyleConfig?) -> [String: Any] {
        var d = baseGeometry(position: txt.position, size: txt.buttonSize)
        d["type"] = "button"
        d["name"] = txt.text.plainText
        d["keycodes"] = [Int]()
        d["isDynamic"] = true
        let txtVis = visibilityFlags(txt.visibilityType)
        d["displayInGame"] = txtVis.inGame
        d["displayInMenu"] = txtVis.inMenu
        d["isToggle"] = false
        d["isSwipeable"] = false
        d["passThruEnabled"] = true     // 纯文本不该吃触摸

        applyStyle(&d, style: style)

        // 文本专用：不给背景，只画字
        d["background"] = false
        d["textSize"] = style?.fontSize ?? 9
        d["textColor"] = colorToInt(style?.contentColor, fallback: -1)
        d["textAlignment"] = txt.textAlignment.rawValue
        return d
    }

    // MARK: 摇杆

    private static func convertJoystick(_ joy: ZLJoystick,
                                        layout: ZLControlLayout) -> [String: Any] {
        var d: [String: Any] = [
            "type": "joystick",
            "name": "",
            "keycodes": [Int](),
            "isDynamic": true,
            "displayInGame": visibilityFlags(joy.visibilityType).inGame,
            "displayInMenu": visibilityFlags(joy.visibilityType).inMenu,
            "passThruEnabled": false,
            "forwardLock": joy.canLock,
            "absolute": joy.triggerMode == .absolute,
            "deadZoneRatio": joy.deadZoneRatio,
            "lockThreshold": joy.lockThreshold,
        ]

        // 位置：摇杆固定用中心点 + 尺寸
        let cx = Double(joy.position.x) / 10000.0
        let cy = Double(joy.position.y) / 10000.0
        let sizeDp = joystickSizeDp(joy)
        d["dynamicX"] = cx
        d["dynamicY"] = cy
        d["width"] = sizeDp
        d["height"] = sizeDp

        // 摇杆样式（背景色/摇杆色/圆角）
        if let sid = joy.joystickStyleId,
           let js = layout.joystickStyles.first(where: { $0.uuid == sid }) {
            // commonStyle = true 表示亮暗共用一套配色，直接用 lightStyle；
            // 否则按系统当前外观选。原来这里三元两边都写 lightStyle（笔误），
            // 导致暗色模式下摇杆永远是亮色配色。
            let cfg = js.commonStyle ? js.lightStyle : effectiveJoystickStyle(js)
            d["opacity"] = phpClamp(cfg.alpha, 0, 1)
            d["bgColor"] = colorToInt(cfg.backgroundColor, fallback: 0x4d000000)
            d["joystickColor"] = colorToInt(cfg.joystickColor, fallback: 0x80ffffff)
            d["strokeColor"] = colorToInt(cfg.borderColor, fallback: -1)
            d["strokeWidth"] = Double(cfg.borderWidthRatio)
            d["joystickSize"] = cfg.joystickSize
            d["cornerRadius"] = 100.0   // 摇杆默认圆形
        } else {
            d["opacity"] = 1.0
            d["bgColor"] = 0x4d000000
            d["joystickColor"] = 0x80ffffff
            d["strokeColor"] = -1
            d["strokeWidth"] = 2.0
            d["cornerRadius"] = 100.0
        }

        // 方向键位：8 个方向 × 4 个键位 = 32 个整数
        //
        // 核心的 ControlJoystick 原来把 W/A/S/D 写死，
        // 现在改成读 directionKeycodes。索引 = direction * 4 + slot。
        // 方向编号对齐核心的 DIRECTION_* 宏：
        //   0=EAST 1=NE 2=NORTH 3=NW 5=SW 7=SE（核心跳过 WEST=4 和 SOUTH=6，
        //   因为它们是 NE/NW 和 SW/SE 的中间态）
        // 但 ZL2 的 8 个方向都配了，所以按 0-7 依次填。
        d["directionKeycodes"] = directionKeycodes(for: joy)

        return d
    }

    /// ZL2 的 directionEvents → 核心要的 32 个整数
    ///
    /// 核心的方向编号（见 ControlJoystick.m 的 DIRECTION_* 宏）：
    ///   0 EAST / 1 NORTH_EAST / 2 NORTH / 3 NORTH_WEST
    ///   4 WEST / 5 SOUTH_WEST / 6 SOUTH / 7 SOUTH_EAST
    ///
    /// ZL2 的键名与之对应，但 ZL2 默认只给 8 个方向配了 WASD 组合。
    static func directionKeycodes(for joy: ZLJoystick) -> [Int] {
        // 方向名 → 核心编号
        let order: [ZLJoystickDirection] = [
            .east, .northEast, .north, .northWest,
            .west, .southWest, .south, .southEast,
        ]

        var out = [Int](repeating: 0, count: 32)

        // 用户没自定义时用 ZL2 的默认绑定（WASD 八向）
        let events = joy.directionEvents.isEmpty ? ZLJoystickDefaults.directionEvents
                                                 : joy.directionEvents

        for (idx, dir) in order.enumerated() {
            guard let list = events[dir.rawValue] else { continue }
            var slot = 0
            for ev in list where ev.type == .key {
                guard slot < 4 else { break }
                if let code = GLFWKeyNames.code(for: ev.value), code > 0 {
                    out[idx * 4 + slot] = code
                    slot += 1
                }
            }
        }
        return out
    }

    // MARK: 样式内联

    private static func resolveStyle(_ uuid: String?,
                                     _ index: [String: ZLButtonStyle]) -> ZLStyleConfig? {
        guard let uuid, !uuid.isEmpty, let style = index[uuid] else { return nil }
        // ZLButtonStyle.commonStyle = true 时亮暗共用，直接用 lightStyle；
        // 否则按系统当前外观选（原来这里固定返回 lightStyle，暗色模式下控件颜色不对）
        if style.commonStyle { return style.lightStyle }
        return isSystemDark ? style.darkStyle : style.lightStyle
    }

    /// 摇杆样式：commonStyle 为真用 light，否则按系统外观选
    private static func effectiveJoystickStyle(_ js: ZLJoystickStyle) -> ZLJoystickStyleConfig {
        js.commonStyle ? js.lightStyle : (isSystemDark ? js.darkStyle : js.lightStyle)
    }

    /// 系统当前是否深色外观
    ///
    /// 导出发生在保存/启动时，可能不在主线程，所以：
    ///   · 主线程直接看 UITraitCollection.current
    ///   · 其它线程退回查 UITraitCollection 的全局值（读不到就当亮色）
    private static var isSystemDark: Bool {
        if Thread.isMainThread {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        // 非主线程：用一个不依赖线程状态的方式
        var isDark = false
        DispatchQueue.main.sync {
            isDark = UITraitCollection.current.userInterfaceStyle == .dark
        }
        return isDark
    }

    private static func applyStyle(_ d: inout [String: Any], style: ZLStyleConfig?) {
        guard let s = style else {
            d["opacity"] = 1.0
            d["cornerRadius"] = 0.0
            d["bgColor"] = 0x4d000000
            d["strokeColor"] = -1
            d["strokeWidth"] = 0.0
            d["textSize"] = 9
            d["textColor"] = -1
            return
        }
        d["opacity"] = phpClamp(s.alpha, 0, 1)
        d["bgColor"] = colorToInt(s.backgroundColor, fallback: 0x4d000000)
        d["strokeColor"] = colorToInt(s.borderColor, fallback: -1)
        d["strokeWidth"] = Double(s.borderWidth)
        d["textSize"] = s.fontSize ?? 9
        d["textColor"] = colorToInt(s.contentColor, fallback: -1)

        // 圆角：ZLCorners 有四个角，核心只认单值，取左上角
        d["cornerRadius"] = Double(s.borderRadius.topStart)
        // 按下态（核心侧有 pressedBgColor 的话用得上）
        d["pressedBgColor"] = colorToInt(s.pressedBackgroundColor, fallback: 0x4d000000)
    }

    // MARK: 几何换算

    /// ZL2 位置是 0~10000 千分比（中心点），核心要 0~1 浮点
    private static func baseGeometry(position: ZLButtonPosition,
                                     size: ZLButtonSize) -> [String: Any] {
        let cx = Double(position.x) / 10000.0
        let cy = Double(position.y) / 10000.0
        let (w, h) = sizeInDp(size)
        return [
            "dynamicX": phpClamp(cx, 0, 1),
            "dynamicY": phpClamp(cy, 0, 1),
            "width": w,
            "height": h,
        ]
    }

    /// 尺寸换算成 dp：dp 类型直接用，百分比按 400dp 基准折算
    private static func sizeInDp(_ size: ZLButtonSize) -> (Double, Double) {
        let base = 400.0
        switch size.type {
        case .dp:
            return (max(20, size.widthDp), max(20, size.heightDp))
        case .percentage:
            let w = Double(size.widthPercentage) / 10000.0 * base
            let h = Double(size.heightPercentage) / 10000.0 * base
            return (max(20, w), max(20, h))
        case .wrapContent:
            return (48, 48)
        }
    }

    private static func joystickSizeDp(_ joy: ZLJoystick) -> Double {
        switch joy.sizeType {
        case .dp:
            return max(40, joy.sizeDp)
        case .percentage:
            return max(40, Double(joy.sizePercentage) / 10000.0 * 400.0)
        case .wrapContent:
            return 120
        }
    }

    // MARK: 键码

    /// 从点击事件里抠出核心要的整数键码数组。
    ///
    /// ZL2 把按键存成字符串 "GLFW_KEY_ESCAPE"，核心要 [Int]。
    /// 一个控件最多挂 4 个键位（核心的 keycodes 数组固定长度 4）。
    ///
    /// 图层事件（switch_layer / show_layer / hide_layer）不是按键，
    /// 但核心只认整数，所以把图层**在数组里的序号**编成 -1001/-1002/... 的
    /// 「伪键码」，由 SurfaceViewController 的 executebtn: default 分支拦截处理。
    ///
    /// - Parameter layerIndexByUUID: 图层 uuid → 序号（由当前布局提供）
    private static func keycodesOf(_ events: [ZLClickEvent],
                                   layerIndexByUUID: [String: Int] = [:]) -> [Int] {
        var codes: [Int] = []
        for ev in events {
            switch ev.type {
            case .key:
                // 不能用 `code > 0` 过滤 —— 核心的特殊按钮（SPECIALBTN_MENU 等）
                // 全是负数（-1..-9，见 core/utils.h:42-50）。用 > 0 会把它们全丢掉，
                // 表现是「菜单键/键盘键/虚拟鼠标键配置好了但按下去没反应」。
                // 0 是 NONE（无按键），跳过即可；伪键码是 -1000 及以下，不会从这里来。
                if let code = GLFWKeyNames.code(for: ev.value), code != 0 {
                    codes.append(code)
                }
            case .switchLayer, .showLayer, .hideLayer:
                // 图层事件：uuid 查出序号 → 按动作类型编伪键码
                if let idx = layerIndexByUUID[ev.value] {
                    let action: LayerPseudoKey.Action
                    switch ev.type {
                    case .showLayer: action = .showLayer
                    case .hideLayer: action = .hideLayer
                    default:         action = .switchLayer
                    }
                    codes.append(LayerPseudoKey.encode(index: idx, action: action))
                }
            default:
                // launcher_event / send_text 没有键码对应，跳过
                break
            }
        }
        // 核心要求正好 4 个；不足补 0，超出截断
        if codes.count > 4 { codes = Array(codes.prefix(4)) }
        while codes.count < 4 { codes.append(0) }
        return codes
    }

    // MARK: 颜色

    /// ZLColorValue 内部就是一个 32 位 ARGB，直接透传（核心要的也是 ARGB）
    private static func colorToInt(_ color: ZLColorValue?, fallback: Int) -> Int {
        guard let c = color else { return fallback }
        return Int(c.argb)
    }

    // MARK: 工具

    private static func currentButtonScale() -> Double {
        if let v = UserDefaults.standard.object(forKey: "control.button_scale") as? Double, v > 0 {
            return v
        }
        return 100.0
    }

    private static func phpClamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        min(max(v, lo), hi)
    }

    private static func sanitize(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return s.components(separatedBy: bad).joined(separator: "_")
    }

    // MARK: 便捷

    /// 从编辑器的 control_layouts/<name>.json 转成核心格式并激活
    @discardableResult
    static func syncFromEditor(name: String) throws -> String {
        let src = ZLLayoutStore.dir.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: src)
        let layout = try ZLControlLayout.importJSON(data)
        return try exportAndActivate(layout, fileName: "\(sanitize(name)).json")
    }

    // MARK: - 图层切换支持
    //
    // 核心（Pojav 的 ControlLayout）是扁平的，没有「图层」概念。
    // 但 ZL2 允许按钮触发 switch_layer / show_layer / hide_layer。
    //
    // 解决方案：为每个图层各导出一份独立布局文件，
    // 图层切换时让核心重新 loadControlFile:。
    // 核心本身支持运行时切换（ControlLayout.h 暴露了 loadControlFile: 和
    // removeAllButtons），所以这条路可行。
    //
    // 代价：一份布局会变成 N 个文件（N = 图层数）。
    // 命名规则：<布局名>__layer<i>.json，第 0 层同时复制一份成 <布局名>.json。

    /// 导出全部图层，返回「图层 uuid → 核心文件名」的映射
    @discardableResult
    static func exportAllLayers(_ layout: ZLControlLayout,
                                baseName: String? = nil) throws -> [String: String] {
        let rawName = layout.info.name.plainText
        let base = baseName ?? (rawName.isEmpty ? "default" : sanitize(rawName))

        var map: [String: String] = [:]

        for (index, layer) in layout.layers.enumerated() {
            // 只导出该图层的控件
            var single = ZLControlLayout(info: layout.info,
                                         layers: [layer],
                                         styles: layout.styles,
                                         joystickStyles: layout.joystickStyles,
                                         editorVersion: layout.editorVersion)
            // 关键：单层导出时不能因为 hide 就跳过，否则空层
            single.layers[0].hide = false

            let fileName = "\(base)__layer\(index).json"
            _ = try export(single, fileName: fileName)
            if !layer.uuid.isEmpty {
                map[layer.uuid] = fileName
            }
            // 第 0 层同时作为默认布局
            if index == 0 {
                map["__default__"] = fileName
            }
        }

        if let def = map["__default__"] {
            activeLayoutName = def
        }

        // 预生成「图层组合」文件
        //
        // show_layer / hide_layer 需要把多层叠在一起显示，但核心一次只能加载一份文件。
        // 所以在导出时就把常见组合都算好：
        //   __combo_0-1.json   显示第 0、1 层
        //   __combo_0-1-2.json 显示第 0、1、2 层
        //   ...（全部非空子集）
        //
        // 层数不多（通常 2~4），子集数量 2^n - 1 完全可接受。
        try exportCombinations(layout, base: base)

        return map
    }

    /// 生成全部非空图层子集的组合文件
    private static func exportCombinations(_ layout: ZLControlLayout, base: String) throws {
        let n = layout.layers.count
        guard n > 1, n <= 6 else { return }   // 超过 6 层就不预生成（63 种太多）

        for mask in 1..<(1 << n) {
            let indices = (0..<n).filter { mask & (1 << $0) != 0 }
            // 单层组合已经有 __layerN.json 了，跳过
            if indices.count == 1 { continue }

            let picked = indices.map { layout.layers[$0] }
            var combo = ZLControlLayout(info: layout.info,
                                        layers: picked,
                                        styles: layout.styles,
                                        joystickStyles: layout.joystickStyles,
                                        editorVersion: layout.editorVersion)
            // 组合里所有层都要显示
            for i in combo.layers.indices { combo.layers[i].hide = false }

            let key = indices.map(String.init).joined(separator: "-")
            _ = try export(combo, fileName: "\(base)__combo_\(key).json")
        }
    }

    /// 生成给「切换图层」按钮用的说明（写进核心能识别的备注字段）
    ///
    /// 核心读到这个字段不会执行任何动作（它不认识），
    /// 但 Swift 侧的 ZLLayerSwitcher 会监听并调用核心切文件。
    static func layerSwitchManifest(_ layout: ZLControlLayout,
                                    map: [String: String]) -> [String: Any] {
        var layers: [[String: Any]] = []
        for (index, layer) in layout.layers.enumerated() {
            layers.append([
                "uuid": layer.uuid,
                "name": layer.name,
                "index": index,
                "file": map[layer.uuid] ?? "",
                "visibleType": layer.visibilityType.rawValue,
            ])
        }
        return [
            "layoutName": layout.info.name.plainText,
            "layers": layers,
        ]
    }

    /// 把图层清单写成 json（和布局文件同目录，供 App 侧读取）
    @discardableResult
    static func writeLayerManifest(_ layout: ZLControlLayout,
                                   map: [String: String]) throws -> URL {
        let rawName = layout.info.name.plainText
        let base = rawName.isEmpty ? "default" : sanitize(rawName)
        let url = controlMapDir.appendingPathComponent("\(base)__layers.json")
        let obj = layerSwitchManifest(layout, map: map)
        let data = try JSONSerialization.data(withJSONObject: obj,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        return url
    }
}
