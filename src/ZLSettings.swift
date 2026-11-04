// ZL2-iOS · 全部设置项（对齐 ZL2 的 AllSettings.kt，115 项）
// 来源：/tmp/zl2/ZalithLauncher/src/main/java/com/movtery/zalithlauncher/setting/AllSettings.kt
//
// 约定：
// - key 与安卓版完全一致（MMKV / SharedPreferences 同名），方便逐项对照
// - defaultValue 用字符串保存，便于 UI 层直接回退到默认值
//   · 布尔："true" / "false"
//   · 整数：十进制字符串；可空整数（安卓 null）记为 "null"
//   · 枚举：与安卓同名的枚举字面量，如 "MouseControlMode.SLIDE"
//   · parcelable：鼠标热点/悬浮窗位置用 "x,y"（百分比 / 屏幕坐标），见各条注释
// - range：安卓 intSetting 的取值区间；无区间为 nil
import Foundation

/// 设置项类型（与安卓 SettingsRegistry 的 SettingUnit 对应）
enum ZLSettingType: String {
    case bool, string, int, long, enumValue, stringList, parcelable
}

/// 单个设置项定义
struct ZLSettingDef: Identifiable {
    var id: String { key }
    let key: String
    let type: ZLSettingType
    let defaultValue: String
    let range: ClosedRange<Int>?
    let group: String

    /// 安卓端默认值为 null（如 ramAllocation / physicalKeyImeCode / lastIgnoredVersion）
    var isNullable: Bool { defaultValue == "null" }
}

/// ZL2 全部设置项
enum ZLSettings {
    // MARK: render（渲染设置，15 项）
    static let renderSettings: [ZLSettingDef] = [
        .init(key: "renderer", type: .string, defaultValue: "", range: nil, group: "render"),
        .init(key: "sfpewPluginLayer", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "sfpewRelaxedContext", type: .bool, defaultValue: "false", range: nil, group: "render"),
        // 安卓默认 "default turnip"
        .init(key: "vulkanDriver", type: .string, defaultValue: "default turnip", range: nil, group: "render"),
        .init(key: "graphicsApi", type: .enumValue, defaultValue: "GraphicsApi.DEFAULT_OPENGL", range: nil, group: "render"),
        .init(key: "resolutionRatio", type: .int, defaultValue: "100", range: 25...300, group: "render"),
        .init(key: "resolutionRule", type: .enumValue, defaultValue: "ResolutionRule.PERCENTAGE", range: nil, group: "render"),
        .init(key: "customResolutionWidth", type: .int, defaultValue: "0", range: nil, group: "render"),
        .init(key: "customResolutionHeight", type: .int, defaultValue: "0", range: nil, group: "render"),
        .init(key: "gameFullScreen", type: .bool, defaultValue: "true", range: nil, group: "render"),
        .init(key: "sustainedPerformance", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "requestMaxRefreshRate", type: .bool, defaultValue: "true", range: nil, group: "render"),
        .init(key: "zinkPreferSystemDriver", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "vsyncInZink", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "dumpShaders", type: .bool, defaultValue: "false", range: nil, group: "render"),
    ]

    // MARK: game（游戏设置，11 项）
    static let gameSettings: [ZLSettingDef] = [
        .init(key: "versionIsolation", type: .bool, defaultValue: "true", range: nil, group: "game"),
        .init(key: "skipGameIntegrityCheck", type: .bool, defaultValue: "false", range: nil, group: "game"),
        // 安卓默认 "${BuildKeys.LAUNCHER_IDENTIFIER}[zl_version]"；
        // BuildKeys 是安卓构建期生成的常量，iOS 端以 "ZalithLauncher" 作为标识（待确认）
        .init(key: "versionCustomInfo", type: .string, defaultValue: "ZalithLauncher[zl_version]", range: nil, group: "game"),
        .init(key: "javaRuntime", type: .string, defaultValue: "", range: nil, group: "game"),
        .init(key: "autoPickJavaRuntime", type: .bool, defaultValue: "true", range: nil, group: "game"),
        // 安卓为 NullableIntSettingUnit，默认 null，最小 256MB
        .init(key: "ramAllocation", type: .int, defaultValue: "null", range: 256...Int.max, group: "game"),
        .init(key: "jvmArgs", type: .string, defaultValue: "", range: nil, group: "game"),
        // 安卓 stringListSetting，默认 emptyList()
        .init(key: "nativeLibPlugins", type: .stringList, defaultValue: "", range: nil, group: "game"),
        .init(key: "showLogAutomatic", type: .bool, defaultValue: "false", range: nil, group: "game"),
        .init(key: "logTextSize", type: .int, defaultValue: "15", range: 5...20, group: "game"),
        .init(key: "logBufferFlushInterval", type: .int, defaultValue: "200", range: 100...1000, group: "game"),
    ]

    // MARK: control（控制设置，29 项）
    static let controlSettings: [ZLSettingDef] = [
        .init(key: "physicalMouseMode", type: .bool, defaultValue: "true", range: nil, group: "control"),
        // 安卓默认 null（未绑定）
        .init(key: "physicalKeyImeCode", type: .int, defaultValue: "null", range: nil, group: "control"),
        .init(key: "hideMouse", type: .bool, defaultValue: "false", range: nil, group: "control"),
        .init(key: "mouseSize", type: .int, defaultValue: "24", range: 5...50, group: "control"),
        // 热点坐标用 "xPercent,yPercent" 表示；安卓默认 LEFT_TOP_HOTSPOT(0, 0)
        .init(key: "arrowMouseHotspot", type: .parcelable, defaultValue: "0,0", range: nil, group: "control"),
        // 安卓默认 CursorHotspot(xPercent = 23, yPercent = 0)
        .init(key: "linkMouseHotspot", type: .parcelable, defaultValue: "23,0", range: nil, group: "control"),
        // 以下 6 项安卓默认 CENTER_HOTSPOT(50, 50)
        .init(key: "iBeamMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "crossHairMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "resizeNSMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "resizeEWMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "resizeAllMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "notAllowedMouseHotspot", type: .parcelable, defaultValue: "50,50", range: nil, group: "control"),
        .init(key: "cursorSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "control"),
        .init(key: "mouseCaptureSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "control"),
        .init(key: "mouseControlMode", type: .enumValue, defaultValue: "MouseControlMode.SLIDE", range: nil, group: "control"),
        .init(key: "mouseTouchBlockMode", type: .enumValue, defaultValue: "MouseTouchBlockMode.NONE", range: nil, group: "control"),
        .init(key: "mouseLongPressDelay", type: .int, defaultValue: "300", range: 100...1000, group: "control"),
        .init(key: "enableMouseClick", type: .bool, defaultValue: "true", range: nil, group: "control"),
        .init(key: "gestureControl", type: .bool, defaultValue: "false", range: nil, group: "control"),
        .init(key: "gestureTapMouseAction", type: .enumValue, defaultValue: "GestureActionType.MOUSE_RIGHT", range: nil, group: "control"),
        .init(key: "gestureLongPressMouseAction", type: .enumValue, defaultValue: "GestureActionType.MOUSE_LEFT", range: nil, group: "control"),
        .init(key: "gestureLongPressDelay", type: .int, defaultValue: "300", range: 100...1000, group: "control"),
        .init(key: "gyroscopeControl", type: .bool, defaultValue: "false", range: nil, group: "control"),
        .init(key: "gyroscopeSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "control"),
        .init(key: "gyroscopeSampleRate", type: .int, defaultValue: "16", range: 5...50, group: "control"),
        .init(key: "gyroscopeSmoothing", type: .bool, defaultValue: "true", range: nil, group: "control"),
        .init(key: "gyroscopeSmoothingWindow", type: .int, defaultValue: "4", range: 2...10, group: "control"),
        .init(key: "gyroscopeInvertX", type: .bool, defaultValue: "false", range: nil, group: "control"),
        .init(key: "gyroscopeInvertY", type: .bool, defaultValue: "false", range: nil, group: "control"),
    ]

    // MARK: gamepad（手柄设置，10 项）
    static let gamepadSettings: [ZLSettingDef] = [
        .init(key: "gamepadControl", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "sdlAutoShowIme", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "imeMagnifierAutoShow", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "gamepadInputMode", type: .enumValue, defaultValue: "GamepadInputMode.Mapped", range: nil, group: "gamepad"),
        .init(key: "gamepadInputModePrompted", type: .bool, defaultValue: "false", range: nil, group: "gamepad"),
        .init(key: "gamepadDeadZoneScale", type: .int, defaultValue: "100", range: 50...200, group: "gamepad"),
        .init(key: "gamepadMappingConfig", type: .string, defaultValue: "default", range: nil, group: "gamepad"),
        .init(key: "joystickControlMode", type: .enumValue, defaultValue: "JoystickMode.LeftMovement", range: nil, group: "gamepad"),
        .init(key: "gamepadCursorSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "gamepad"),
        .init(key: "gamepadCameraSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "gamepad"),
    ]

    // MARK: launcher（启动器设置 + 其它持久化状态，44 项）
    static let launcherSettings: [ZLSettingDef] = [
        // 安卓：SDK >= 31 默认 DYNAMIC，否则 EMBERMIRE；iOS 端无动态取色，仍按安卓 12+ 记 DYNAMIC
        .init(key: "launcherColorTheme", type: .enumValue, defaultValue: "ColorThemeType.DYNAMIC", range: nil, group: "launcher"),
        // 安卓默认 Color.Blue.toArgb() = 0xFF0000FF = -16776961
        .init(key: "launcherCustomColor", type: .int, defaultValue: "-16776961", range: nil, group: "launcher"),
        .init(key: "launcherCustomPaletteStyle", type: .enumValue, defaultValue: "PaletteStyle.TonalSpot", range: nil, group: "launcher"),
        .init(key: "launcherDarkMode", type: .enumValue, defaultValue: "DarkMode.FollowSystem", range: nil, group: "launcher"),
        .init(key: "launcherLanguage", type: .enumValue, defaultValue: "AppLanguage.FOLLOW_SYSTEM", range: nil, group: "launcher"),
        .init(key: "launcherFullScreen", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "launcherFestivalEffects", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "launcherSwapAnimEnabled", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "launcherAnimateSpeedLevel", type: .int, defaultValue: "10", range: 1...30, group: "launcher"),
        .init(key: "launcherActionMenuSide", type: .enumValue, defaultValue: "ActionMenuSide.END", range: nil, group: "launcher"),
        .init(key: "launcherBackgroundOpacity", type: .int, defaultValue: "80", range: 20...100, group: "launcher"),
        .init(key: "videoBackgroundVolume", type: .int, defaultValue: "0", range: 0...100, group: "launcher"),
        .init(key: "backgroundBlur", type: .int, defaultValue: "0", range: 0...40, group: "launcher"),
        .init(key: "backgroundBlurType", type: .enumValue, defaultValue: "BackgroundBlur.Background", range: nil, group: "launcher"),
        // 安卓 nullable int，默认 null
        .init(key: "lastIgnoredVersion", type: .int, defaultValue: "null", range: nil, group: "launcher"),
        .init(key: "launcherLogRetentionDays", type: .int, defaultValue: "7", range: 1...14, group: "launcher"),
        // 安卓 enumSetting 默认 AUTO，LEGACY_NAMES 只是旧名字的兜底映射表
        .init(key: "gameDownloadSource", type: .enumValue, defaultValue: "MirrorSourceType.AUTO", range: nil, group: "launcher"),
        .init(key: "assetPlatformSource", type: .enumValue, defaultValue: "MirrorSourceType.AUTO", range: nil, group: "launcher"),
        .init(key: "controlLayout", type: .string, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "currentAccount", type: .string, defaultValue: "", range: nil, group: "launcher"),
        // 安卓默认 GamePathManager.DEFAULT_ID = "default"
        .init(key: "currentGamePathId", type: .string, defaultValue: "default", range: nil, group: "launcher"),
        .init(key: "launcherTaskMenuExpanded", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "hotbarRule", type: .enumValue, defaultValue: "HotbarRule.Auto", range: nil, group: "launcher"),
        .init(key: "hotbarWidth", type: .int, defaultValue: "500", range: 0...1000, group: "launcher"),
        .init(key: "hotbarHeight", type: .int, defaultValue: "100", range: 0...1000, group: "launcher"),
        .init(key: "hotbarDoubleClick", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "hotbarLongClick", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "hotbarLongClickDelay", type: .int, defaultValue: "300", range: 100...1000, group: "launcher"),
        .init(key: "controlsOpacity", type: .int, defaultValue: "100", range: 0...100, group: "launcher"),
        .init(key: "editorEnableWidgetSnap", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "editorSnapInAllLayers", type: .bool, defaultValue: "false", range: nil, group: "launcher"),
        .init(key: "editorWidgetSnapMode", type: .enumValue, defaultValue: "SnapMode.FullScreen", range: nil, group: "launcher"),
        .init(key: "enableTerracotta", type: .bool, defaultValue: "false", range: nil, group: "launcher"),
        .init(key: "enableTerracottaNodes", type: .bool, defaultValue: "false", range: nil, group: "launcher"),
        .init(key: "terracottaNodes", type: .string, defaultValue: "", range: nil, group: "launcher"),
        // 安卓默认 -1
        .init(key: "terracottaNoticeVer", type: .int, defaultValue: "-1", range: nil, group: "launcher"),
        // 安卓 longSetting，默认 0L（不是 parcelable）
        .init(key: "lastUpgradeCheck", type: .long, defaultValue: "0", range: nil, group: "launcher"),
        .init(key: "finishedGame", type: .int, defaultValue: "0", range: nil, group: "launcher"),
        .init(key: "showSponsorship", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "lastSponsorReportMonth", type: .string, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "searchModPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchModpackPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchResourcePackPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchShadersPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
    ]

    // MARK: other（只在游戏内菜单里出现的持久化项，6 项）
    static let otherSettings: [ZLSettingDef] = [
        .init(key: "showFPS", type: .bool, defaultValue: "true", range: nil, group: "other"),
        .init(key: "fpsDisplayMode", type: .enumValue, defaultValue: "FpsDisplayMode.NUMBER", range: nil, group: "other"),
        .init(key: "showMemory", type: .bool, defaultValue: "false", range: nil, group: "other"),
        .init(key: "showMenuBall", type: .bool, defaultValue: "true", range: nil, group: "other"),
        // 安卓 offsetSetting，默认 Offset.Zero；用 "x,y" 表示
        .init(key: "menuBallPos", type: .parcelable, defaultValue: "0,0", range: nil, group: "other"),
        .init(key: "menuBallOpacity", type: .int, defaultValue: "100", range: 20...100, group: "other"),
    ]

    /// 全部设置项（115 项，与 AllSettings.kt 一一对应）
    static var all: [ZLSettingDef] {
        renderSettings + gameSettings + controlSettings + gamepadSettings + launcherSettings + otherSettings
    }

    /// 按 key 查询（设置页逐项渲染时使用）
    static let byKey: [String: ZLSettingDef] = Dictionary(
        uniqueKeysWithValues: (renderSettings + gameSettings + controlSettings
                               + gamepadSettings + launcherSettings + otherSettings)
            .map { ($0.key, $0) }
    )

    static func def(_ key: String) -> ZLSettingDef? { byKey[key] }
}
