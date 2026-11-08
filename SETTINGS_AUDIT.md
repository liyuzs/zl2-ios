# ZL2-iOS 设置页 × ZL2 Android 逐项核对报告

- 参考：`/tmp/zl2/ZalithLauncher/.../setting/AllSettings.kt`（115 项）、`ui/screens/content/SettingsScreen.kt`（分类）、`ui/screens/content/settings/*.kt`（控件与顺序）、`res/values-zh-rCN/strings.xml`
- 被核对：`src/ZLSettings.swift`、`src/SettingsScreen.swift`
- 结论：115 个 key 全部存在（数量一致），但 **22 处默认值/类型/范围与安卓不一致**，已全部修正；设置页原有 29 项左右，**只覆盖了 115 项中的一小部分**，已按安卓分类重写为 76 项（其余 39 项在安卓端本来就不在设置页，见第 5 节）。

## 1. 分类结构

| 安卓设置页（SettingsScreen.kt） | iOS 修正前 | iOS 修正后 |
|---|---|---|
| 渲染设置 | ✅ 有 | ✅ 有（15 项） |
| 游戏设置 | ✅ 有 | ✅ 有（11 项） |
| 控制设置 | ✅ 有 | ✅ 有（29 项 + 控制管理入口在侧栏） |
| 手柄设置 | ✅ 有（仅 4 个假卡片） | ✅ 有（7 项 + 映射配置展示） |
| 启动器设置 | ✅ 有（大量杜撰项） | ✅ 有（14 项 + 主题卡 + 背景卡） |
| ─ 分隔线 ─ | ❌ 无 | ✅ 有 |
| Java 管理（独立分类） | ⚠️ 埋在“其它”里 | ✅ 侧栏独立项 → `AppRoute.javaManage` |
| 控制管理（独立分类） | ⚠️ 放在控制页首条 | ✅ 侧栏独立项 → `AppRoute.controlManage` |
| ─ 分隔线 ─ | ❌ 无 | ✅ 有 |
| 关于（独立分类） | ⚠️ 埋在“其它”里 | ✅ 侧栏独立项 → `AppRoute.about` |

安卓没有“其它”分类；iOS 原来的“其它”页已移除。

## 2. 全量核对表（115 项）

“iOS 修正前”指改动前 `ZLSettings.swift` 的值；“一致?”针对修正前。

### 渲染设置 render（15）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 渲染 | renderer | `""` | `""` | ✅ |
| 渲染 | sfpewPluginLayer | `false` | `false` | ✅ |
| 渲染 | sfpewRelaxedContext | `false` | `false` | ✅ |
| 渲染 | vulkanDriver | `"default turnip"` | `""` | ❌ 已修正 |
| 渲染 | graphicsApi | `GraphicsApi.DEFAULT_OPENGL` | 同 | ✅ |
| 渲染 | resolutionRatio | `100`（25–300） | 同 | ✅ |
| 渲染 | resolutionRule | `ResolutionRule.PERCENTAGE` | 同 | ✅ |
| 渲染 | customResolutionWidth | `0` | 同 | ✅ |
| 渲染 | customResolutionHeight | `0` | 同 | ✅ |
| 渲染 | gameFullScreen | `true` | 同 | ✅ |
| 渲染 | sustainedPerformance | `false` | 同 | ✅ |
| 渲染 | requestMaxRefreshRate | `true` | 同 | ✅ |
| 渲染 | zinkPreferSystemDriver | `false` | 同 | ✅ |
| 渲染 | vsyncInZink | `false` | 同 | ✅ |
| 渲染 | dumpShaders | `false` | 同 | ✅ |

### 游戏设置 game（11）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 游戏 | versionIsolation | `true` | 同 | ✅ |
| 游戏 | skipGameIntegrityCheck | `false` | 同 | ✅ |
| 游戏 | versionCustomInfo | `"${BuildKeys.LAUNCHER_IDENTIFIER}[zl_version]"` | `""` | ❌ 已修正（标识待确认） |
| 游戏 | javaRuntime | `""` | 同 | ✅ |
| 游戏 | autoPickJavaRuntime | `true` | 同 | ✅ |
| 游戏 | ramAllocation | `null`，最小 256 | `"0"`，无范围 | ❌ 已修正 |
| 游戏 | jvmArgs | `""` | 同 | ✅ |
| 游戏 | nativeLibPlugins | `emptyList()` | `""` | ✅（空列表的表示） |
| 游戏 | showLogAutomatic | `false` | 同 | ✅ |
| 游戏 | logTextSize | `15`（5–20） | 同 | ✅ |
| 游戏 | logBufferFlushInterval | `200`（100–1000） | 同 | ✅ |

### 控制设置 control（29）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 控制 | physicalMouseMode | `true` | 同 | ✅ |
| 控制 | physicalKeyImeCode | `null` | `"0"` | ❌ 已修正 |
| 控制 | hideMouse | `false` | 同 | ✅ |
| 控制 | mouseSize | `24`（5–50） | 同 | ✅ |
| 控制 | arrowMouseHotspot | `LEFT_TOP_HOTSPOT(0,0)` | `""` | ❌ 已修正 |
| 控制 | linkMouseHotspot | `CursorHotspot(23,0)` | `""` | ❌ 已修正 |
| 控制 | iBeamMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | crossHairMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | resizeNSMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | resizeEWMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | resizeAllMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | notAllowedMouseHotspot | `CENTER_HOTSPOT(50,50)` | `""` | ❌ 已修正 |
| 控制 | cursorSensitivity | `100`（25–300） | 同 | ✅ |
| 控制 | mouseCaptureSensitivity | `100`（25–300） | 同 | ✅ |
| 控制 | mouseControlMode | `MouseControlMode.SLIDE` | 同 | ✅ |
| 控制 | mouseTouchBlockMode | `MouseTouchBlockMode.NONE` | 同 | ✅ |
| 控制 | mouseLongPressDelay | `300`（100–1000） | 同 | ✅ |
| 控制 | enableMouseClick | `true` | 同值，但被归到 launcher 组 | ⚠️ 分组已修正 |
| 控制 | gestureControl | `false` | 同 | ✅ |
| 控制 | gestureTapMouseAction | `GestureActionType.MOUSE_RIGHT` | 同 | ✅ |
| 控制 | gestureLongPressMouseAction | `GestureActionType.MOUSE_LEFT` | 同 | ✅ |
| 控制 | gestureLongPressDelay | `300`（100–1000） | 同 | ✅ |
| 控制 | gyroscopeControl | `false` | 同 | ✅ |
| 控制 | gyroscopeSensitivity | `100`（25–300） | 同 | ✅ |
| 控制 | gyroscopeSampleRate | `16`（5–50） | 同 | ✅ |
| 控制 | gyroscopeSmoothing | `true` | 同 | ✅ |
| 控制 | gyroscopeSmoothingWindow | `4`（2–10） | 同 | ✅ |
| 控制 | gyroscopeInvertX | `false` | 同 | ✅ |
| 控制 | gyroscopeInvertY | `false` | 同 | ✅ |

### 手柄设置 gamepad（10）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 手柄 | gamepadControl | `true` | 同 | ✅ |
| 手柄 | sdlAutoShowIme | `true` | 同 | ✅（安卓上属游戏菜单项） |
| 手柄 | imeMagnifierAutoShow | `true` | 同 | ✅（同上） |
| 手柄 | gamepadInputMode | `GamepadInputMode.Mapped` | 同 | ✅ |
| 手柄 | gamepadInputModePrompted | `false` | 同 | ✅（内部标记） |
| 手柄 | gamepadDeadZoneScale | `100`（50–200） | 同 | ✅ |
| 手柄 | gamepadMappingConfig | `"default"` | `""` | ❌ 已修正 |
| 手柄 | joystickControlMode | `JoystickMode.LeftMovement` | 同 | ✅ |
| 手柄 | gamepadCursorSensitivity | `100`（25–300） | 同 | ✅ |
| 手柄 | gamepadCameraSensitivity | `100`（25–300） | 同 | ✅ |

### 启动器设置 launcher（44）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 启动器 | launcherColorTheme | SDK≥31 `DYNAMIC`，否则 `EMBERMIRE` | `"Build.VERSION_CODES.S"`（无意义值） | ❌ 已修正 |
| 启动器 | launcherCustomColor | `0xFF0000FF` = `-16776961` | `"0"` | ❌ 已修正 |
| 启动器 | launcherCustomPaletteStyle | `PaletteStyle.TonalSpot` | 同 | ✅ |
| 启动器 | launcherDarkMode | `DarkMode.FollowSystem` | 同 | ✅ |
| 启动器 | launcherLanguage | `AppLanguage.FOLLOW_SYSTEM` | 同 | ✅ |
| 启动器 | launcherFullScreen | `true` | 同 | ✅ |
| 启动器 | launcherFestivalEffects | `true` | 同 | ✅ |
| 启动器 | launcherSwapAnimEnabled | `true` | 同 | ✅ |
| 启动器 | launcherAnimateSpeedLevel | `10`（1–30） | 同 | ✅ |
| 启动器 | launcherActionMenuSide | `ActionMenuSide.END` | 同 | ✅ |
| 启动器 | launcherBackgroundOpacity | `80`（20–100） | 同 | ✅ |
| 启动器 | videoBackgroundVolume | `0`（0–100） | 同 | ✅ |
| 启动器 | backgroundBlur | `0`（0–40） | 同 | ✅ |
| 启动器 | backgroundBlurType | `BackgroundBlur.Background` | 同 | ✅ |
| 启动器 | lastIgnoredVersion | `null` | `"0"` | ❌ 已修正 |
| 启动器 | launcherLogRetentionDays | `7`（1–14） | 同 | ✅ |
| 启动器 | gameDownloadSource | `MirrorSourceType.AUTO` | `MirrorSourceType.LEGACY_NAMES` | ❌ 已修正 |
| 启动器 | assetPlatformSource | `MirrorSourceType.AUTO` | `MirrorSourceType.LEGACY_NAMES` | ❌ 已修正 |
| 启动器 | controlLayout | `""` | 同 | ✅ |
| 启动器 | currentAccount | `""` | 同 | ✅ |
| 启动器 | currentGamePathId | `"default"`（GamePathManager.DEFAULT_ID） | `""` | ❌ 已修正 |
| 启动器 | launcherTaskMenuExpanded | `true` | 同 | ✅ |
| 启动器 | hotbarRule | `HotbarRule.Auto` | 同 | ✅ |
| 启动器 | hotbarWidth | `500`（0–1000） | 同 | ✅ |
| 启动器 | hotbarHeight | `100`（0–1000） | 同 | ✅ |
| 启动器 | hotbarDoubleClick | `true` | 同 | ✅ |
| 启动器 | hotbarLongClick | `true` | 同 | ✅ |
| 启动器 | hotbarLongClickDelay | `300`（100–1000） | 同 | ✅ |
| 启动器 | controlsOpacity | `100`（0–100） | 同 | ✅ |
| 启动器 | editorEnableWidgetSnap | `true` | 同 | ✅ |
| 启动器 | editorSnapInAllLayers | `false` | 同 | ✅ |
| 启动器 | editorWidgetSnapMode | `SnapMode.FullScreen` | 同 | ✅ |
| 启动器 | enableTerracotta | `false` | 同 | ✅ |
| 启动器 | enableTerracottaNodes | `false` | 同 | ✅ |
| 启动器 | terracottaNodes | `""` | 同 | ✅ |
| 启动器 | terracottaNoticeVer | `-1` | `"0"` | ❌ 已修正 |
| 启动器 | lastUpgradeCheck | `0L`（long） | `""`（parcelable，类型错） | ❌ 已修正 |
| 启动器 | finishedGame | `0` | 同 | ✅ |
| 启动器 | showSponsorship | `true` | 同 | ✅ |
| 启动器 | lastSponsorReportMonth | `""` | 同 | ✅ |
| 启动器 | searchModPlatform | `Platform.CURSEFORGE` | 同 | ✅ |
| 启动器 | searchModpackPlatform | `Platform.CURSEFORGE` | 同 | ✅ |
| 启动器 | searchResourcePackPlatform | `Platform.CURSEFORGE` | 同 | ✅ |
| 启动器 | searchShadersPlatform | `Platform.CURSEFORGE` | 同 | ✅ |

### 其它 other（6，全部是游戏内菜单项）

| 分类 | key | ZL2 默认值 | iOS 修正前 | 一致? |
|---|---|---|---|---|
| 其它 | showFPS | `true` | 同值，但被归到 game 组 | ⚠️ 分组已修正 |
| 其它 | fpsDisplayMode | `FpsDisplayMode.NUMBER` | 同 | ✅ |
| 其它 | showMemory | `false` | 同 | ✅ |
| 其它 | showMenuBall | `true` | 同 | ✅ |
| 其它 | menuBallPos | `Offset.Zero` | `""` | ❌ 已修正 |
| 其它 | menuBallOpacity | `100`（20–100） | 同 | ✅ |

## 3. 已修正的 22 处默认值/类型/范围

1. vulkanDriver：`""` → `"default turnip"`
2. versionCustomInfo：`""` → `"ZalithLauncher[zl_version]"`（标识见“不确定项”）
3. ramAllocation：`"0"` 无范围 → `"null"`，范围下限 256
4. physicalKeyImeCode：`"0"` → `"null"`
5. arrowMouseHotspot：`""` → `"0,0"`
6. linkMouseHotspot：`""` → `"23,0"`
7–12. iBeam / crossHair / resizeNS / resizeEW / resizeAll / notAllowed：`""` → `"50,50"`
13. gamepadMappingConfig：`""` → `"default"`
14. launcherColorTheme：`"Build.VERSION_CODES.S"` → `"ColorThemeType.DYNAMIC"`
15. launcherCustomColor：`"0"` → `"-16776961"`
16. lastIgnoredVersion：`"0"` → `"null"`
17. gameDownloadSource：`LEGACY_NAMES` → `AUTO`
18. assetPlatformSource：`LEGACY_NAMES` → `AUTO`
19. currentGamePathId：`""` → `"default"`
20. terracottaNoticeVer：`"0"` → `"-1"`
21. lastUpgradeCheck：类型 parcelable + `""` → long + `"0"`
22. menuBallPos：`""` → `"0,0"`

另修正 3 处分组：enableMouseClick → control；showFPS/fpsDisplayMode/showMemory/showMenuBall/menuBallPos/menuBallOpacity → other；controlLayout 保留在 launcher 列表但语义属控制。

## 4. 设置页 UI 修正

- 控制类型：布尔→Toggle；整数→Slider（范围全部沿用安卓 `floatRange`）；枚举→下拉菜单（`Menu`，带选中勾）；字符串→输入框；鼠标热点→X/Y 百分比编辑弹窗；`physicalKeyImeCode`→绑定值 + 重置；`backgroundBlurType`→滑块旁图标切换（与安卓一致）；`launcherAnimateSpeedLevel`→显示 `×value/10`。
- 文案：全部改用 `ZLStrings`（即 `strings.xml` 原文），删除了旧页面杜撰的文案，例如：
  - “日志字号大小”→ `settings_game_log_text_size_title`“日志字体大小”
  - “JVM 参数”→ `settings_game_jvm_args_title`“JVM 启动参数”
  - “抓取鼠标滑动灵敏度”→ `settings_control_mouse_capture_sensitivity_title`“抓获鼠标滑动灵敏度”
  - “长按触发的延迟”→ `settings_control_mouse_long_press_delay_title`
  - 删除“矩阵鼠标控制”“输入法模式”“扳机灵敏度”“震动反馈”“已安装的 Java”“动画低速/动画高度”等安卓源码中不存在的项
  - 删除错误的动画速度选项“空白 / 从未加载 / 从网络加载”（安卓是 1–30 的倍率滑块）
- 分类：5 个设置分类 + 分隔线 + Java 管理 / 控制管理 + 分隔线 + 关于，与安卓一致。

## 5. 仍未出现在设置页的 39 项（不是遗漏，安卓也不在设置页）

### 5.1 游戏内菜单项（6）
`showFPS`、`fpsDisplayMode`、`showMemory`、`showMenuBall`、`menuBallPos`、`menuBallOpacity`
→ 安卓在游戏内菜单悬浮窗里改；iOS 的设置页不应出现。若要补齐，应做在游戏内菜单，而不是设置页。

### 5.2 控制/编辑器状态与游戏菜单项（15）
`controlLayout`、`hotbarRule`、`hotbarWidth`、`hotbarHeight`、`hotbarDoubleClick`、`hotbarLongClick`、`hotbarLongClickDelay`、`controlsOpacity`、`editorEnableWidgetSnap`、`editorSnapInAllLayers`、`editorWidgetSnapMode`
→ 安卓在“游戏菜单 / 控制布局编辑器”里改。
`sdlAutoShowIme`、`imeMagnifierAutoShow` → 游戏菜单“自动唤起输入法 / 输入时默认弹出放大镜”。
`gamepadInputModePrompted` → 内部标记（是否询问过输入模式），无 UI。
`enableMouseClick` 等已在设置页。

### 5.3 启动器内部状态（14）
`launcherActionMenuSide`、`launcherTaskMenuExpanded`、`lastIgnoredVersion`、`lastUpgradeCheck`、`finishedGame`、`showSponsorship`、`lastSponsorReportMonth`、`terracottaNoticeVer`、`currentAccount`、`currentGamePathId`、`searchModPlatform`、`searchModpackPlatform`、`searchResourcePackPlatform`、`searchShadersPlatform`
→ 由各自功能页/逻辑读写，安卓设置页不直接暴露。

### 5.4 主题/陶瓦/自定义项（4）
`launcherCustomColor`、`launcherCustomPaletteStyle` → 安卓在“自定义颜色”对话框里；iOS 主题卡目前只做 7 套预设，这两项只存值。
`enableTerracotta`、`enableTerracottaNodes`、`terracottaNodes` → 安卓在陶瓦联机页；iOS 的 `TerracottaScreen` 未接设置。

## 6. 功能缺口（设置项已在，但控件能力不完整；未用假实现糊过去）

1. **渲染器列表**：安卓从 `Renderers.getRenderers()` 枚举插件；iOS 无该接口，`renderer` 退化为文本输入。
2. **Vulkan 驱动列表**：安卓 `DriverPluginManager.getDriverList()`；iOS 无，退化为文本输入。
3. **Java 环境列表**：安卓 `RuntimesManager.getRuntimes()`；iOS 用文本输入（Java 管理页另有入口）。
4. **原生库插件列表**：安卓可逐项启用/禁用；iOS 只读显示“未指定”。
5. **手柄映射配置**：安卓可创建/删除/切换配置并重映射按键；iOS 只读展示当前配置名。
6. **手柄按键重绑定 / 重置映射**：未实现。
7. **物理按键捕获**：iOS 只能显示/清除键值，不能捕获按键（需 `UIKey` 事件桥）。
8. **鼠标指针图片导入/重置**：安卓每个指针卡片可导入图片；iOS 只实现热点坐标编辑。
9. **启动器背景导入/重置**、**分享启动器日志**：未实现（iOS 有 `LogView`，但未做打包分享）。
10. **主题 DYNAMIC / CUSTOM**：iOS 无 Material You 动态取色，也没有 PaletteStyle 配色风格实现；`launcherColorTheme` 可选值只落到 7 套预设。
11. **深色模式 FollowSystem**：`ZL2App.swift` 第 8 行 / RootView 硬编码 `.preferredColorScheme(.light)`，且 `ZLTheme` 只有浅色调色板；设置值会保存，但视觉上不会真正跟随系统。
12. **门控缺失**：安卓根据 Vulkan 支持显示 Zink“使用系统驱动”，根据陀螺仪可用性禁用陀螺仪项；iOS 无条件显示。
13. **下载源仅中国内地显示**：安卓用 `isChinaMainland()` 门控；iOS 无条件显示（设置本身仍有效）。

## 7. 不确定项（未猜，已标注）

1. **versionCustomInfo 的 `BuildKeys.LAUNCHER_IDENTIFIER`**：该常量是安卓构建期生成，仓库内没有其值；暂用 `"ZalithLauncher"`，需确认后替换。
2. **launcherColorTheme 默认值**：安卓按 `SDK_INT >= 31` 在 `DYNAMIC` / `EMBERMIRE` 间取；iOS 无动态取色，暂按安卓 12+ 记 `DYNAMIC`。若 iOS 以“稳定可见”为准，应改 `EMBERMIRE`。
3. **ramAllocation 上限**：安卓 `getMaxMemoryForSettings()` 动态计算；iOS 用物理内存（`ProcessInfo.physicalMemory`）作上限，可能与安卓允许值不同。
4. **`menuBallPos` 坐标语义**：安卓是 `Offset` 像素坐标，iOS 用 `"x,y"` 字符串表示，类型仍记为 parcelable；跨端同步时需换算。
5. **鼠标热点坐标语义**：安卓 `CursorHotspot` 是百分比（0–100），iOS 用 `"x,y"` 百分比字符串，已与默认值对齐。
6. **手柄输入模式 SDL 分支**：安卓枚举 case 为 `SdlDirect`（默认 `Mapped`），已按源码写入。
7. **`gamepadInputModePrompted` / `launcherCustom*` 等**：按源码判断为内部状态，未在设置页暴露；如产品要求暴露，需要产品确认。
