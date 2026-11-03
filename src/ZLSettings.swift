// ZL2-iOS · 全部设置项（自动生成，对齐 ZL2 的 AllSettings.kt）
// 来源：/tmp/zl2/ZalithLauncher/src/main/java/com/movtery/zalithlauncher/setting/AllSettings.kt
import Foundation

/// 设置项类型
enum ZLSettingType: String {
    case bool, string, int, enumValue, stringList, parcelable
}

/// 单个设置项定义
struct ZLSettingDef: Identifiable {
    var id: String { key }
    let key: String
    let type: ZLSettingType
    let defaultValue: String
    let range: ClosedRange<Int>?
    let group: String
}

/// ZL2 全部设置项
enum ZLSettings {
    // MARK: render
    static let renderSettings: [ZLSettingDef] = [
        .init(key: "renderer", type: .string, defaultValue: "", range: nil, group: "render"),
        .init(key: "sfpewPluginLayer", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "sfpewRelaxedContext", type: .bool, defaultValue: "false", range: nil, group: "render"),
        .init(key: "vulkanDriver", type: .string, defaultValue: "", range: nil, group: "render"),
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

    // MARK: game
    static let gameSettings: [ZLSettingDef] = [
        .init(key: "versionIsolation", type: .bool, defaultValue: "true", range: nil, group: "game"),
        .init(key: "skipGameIntegrityCheck", type: .bool, defaultValue: "false", range: nil, group: "game"),
        .init(key: "versionCustomInfo", type: .string, defaultValue: "", range: nil, group: "game"),
        .init(key: "javaRuntime", type: .string, defaultValue: "", range: nil, group: "game"),
        .init(key: "autoPickJavaRuntime", type: .bool, defaultValue: "true", range: nil, group: "game"),
        .init(key: "ramAllocation", type: .int, defaultValue: "0", range: nil, group: "game"),
        .init(key: "jvmArgs", type: .string, defaultValue: "", range: nil, group: "game"),
        .init(key: "nativeLibPlugins", type: .stringList, defaultValue: "", range: nil, group: "game"),
        .init(key: "showLogAutomatic", type: .bool, defaultValue: "false", range: nil, group: "game"),
        .init(key: "logTextSize", type: .int, defaultValue: "15", range: 5...20, group: "game"),
        .init(key: "logBufferFlushInterval", type: .int, defaultValue: "200", range: 100...1000, group: "game"),
        .init(key: "showFPS", type: .bool, defaultValue: "true", range: nil, group: "game"),
        .init(key: "fpsDisplayMode", type: .enumValue, defaultValue: "FpsDisplayMode.NUMBER", range: nil, group: "game"),
        .init(key: "showMemory", type: .bool, defaultValue: "false", range: nil, group: "game"),
        .init(key: "showMenuBall", type: .bool, defaultValue: "true", range: nil, group: "game"),
        .init(key: "menuBallPos", type: .parcelable, defaultValue: "", range: nil, group: "game"),
        .init(key: "menuBallOpacity", type: .int, defaultValue: "100", range: 20...100, group: "game"),
    ]

    // MARK: control
    static let controlSettings: [ZLSettingDef] = [
        .init(key: "physicalMouseMode", type: .bool, defaultValue: "true", range: nil, group: "control"),
        .init(key: "physicalKeyImeCode", type: .int, defaultValue: "0", range: nil, group: "control"),
        .init(key: "hideMouse", type: .bool, defaultValue: "false", range: nil, group: "control"),
        .init(key: "mouseSize", type: .int, defaultValue: "24", range: 5...50, group: "control"),
        .init(key: "arrowMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "linkMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "iBeamMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "crossHairMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "resizeNSMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "resizeEWMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "resizeAllMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "notAllowedMouseHotspot", type: .parcelable, defaultValue: "", range: nil, group: "control"),
        .init(key: "cursorSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "control"),
        .init(key: "mouseCaptureSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "control"),
        .init(key: "mouseControlMode", type: .enumValue, defaultValue: "MouseControlMode.SLIDE", range: nil, group: "control"),
        .init(key: "mouseTouchBlockMode", type: .enumValue, defaultValue: "MouseTouchBlockMode.NONE", range: nil, group: "control"),
        .init(key: "mouseLongPressDelay", type: .int, defaultValue: "300", range: 100...1000, group: "control"),
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

    // MARK: gamepad
    static let gamepadSettings: [ZLSettingDef] = [
        .init(key: "gamepadControl", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "sdlAutoShowIme", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "imeMagnifierAutoShow", type: .bool, defaultValue: "true", range: nil, group: "gamepad"),
        .init(key: "gamepadInputMode", type: .enumValue, defaultValue: "GamepadInputMode.Mapped", range: nil, group: "gamepad"),
        .init(key: "gamepadInputModePrompted", type: .bool, defaultValue: "false", range: nil, group: "gamepad"),
        .init(key: "gamepadDeadZoneScale", type: .int, defaultValue: "100", range: 50...200, group: "gamepad"),
        .init(key: "gamepadMappingConfig", type: .string, defaultValue: "", range: nil, group: "gamepad"),
        .init(key: "joystickControlMode", type: .enumValue, defaultValue: "JoystickMode.LeftMovement", range: nil, group: "gamepad"),
        .init(key: "gamepadCursorSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "gamepad"),
        .init(key: "gamepadCameraSensitivity", type: .int, defaultValue: "100", range: 25...300, group: "gamepad"),
    ]

    // MARK: launcher
    static let launcherSettings: [ZLSettingDef] = [
        .init(key: "enableMouseClick", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "launcherColorTheme", type: .enumValue, defaultValue: "Build.VERSION_CODES.S", range: nil, group: "launcher"),
        .init(key: "launcherCustomColor", type: .int, defaultValue: "0", range: nil, group: "launcher"),
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
        .init(key: "lastIgnoredVersion", type: .int, defaultValue: "0", range: nil, group: "launcher"),
        .init(key: "launcherLogRetentionDays", type: .int, defaultValue: "7", range: 1...14, group: "launcher"),
        .init(key: "gameDownloadSource", type: .enumValue, defaultValue: "MirrorSourceType.LEGACY_NAMES", range: nil, group: "launcher"),
        .init(key: "assetPlatformSource", type: .enumValue, defaultValue: "MirrorSourceType.LEGACY_NAMES", range: nil, group: "launcher"),
        .init(key: "controlLayout", type: .string, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "currentAccount", type: .string, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "currentGamePathId", type: .string, defaultValue: "", range: nil, group: "launcher"),
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
        .init(key: "terracottaNoticeVer", type: .int, defaultValue: "0", range: nil, group: "launcher"),
        .init(key: "lastUpgradeCheck", type: .parcelable, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "finishedGame", type: .int, defaultValue: "0", range: nil, group: "launcher"),
        .init(key: "showSponsorship", type: .bool, defaultValue: "true", range: nil, group: "launcher"),
        .init(key: "lastSponsorReportMonth", type: .string, defaultValue: "", range: nil, group: "launcher"),
        .init(key: "searchModPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchModpackPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchResourcePackPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
        .init(key: "searchShadersPlatform", type: .enumValue, defaultValue: "Platform.CURSEFORGE", range: nil, group: "launcher"),
    ]

    /// 全部设置项
    static var all: [ZLSettingDef] {
        renderSettings + gameSettings + controlSettings + gamepadSettings + launcherSettings
    }
}
