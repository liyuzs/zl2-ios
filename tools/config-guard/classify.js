// 分析 78 个未标注 key 在 iOS 上是否适用
const fs = require('fs');

// 安卓专属 / iOS 不存在的能力 → 应该标注 unsupported
// 依据：iOS 没有陀螺仪 API（CoreMotion 有但游戏内不用）、没有物理鼠标热区、没有 Android SDL 那一套
const androidOnly = {
  // 陀螺仪（安卓 SensorManager，iOS 游戏内未接 CoreMotion）
  gyroscopeControl: '陀螺仪控制',
  gyroscopeInvertX: '陀螺仪反转X',
  gyroscopeInvertY: '陀螺仪反转Y',
  gyroscopeSampleRate: '陀螺仪采样率',
  gyroscopeSensitivity: '陀螺仪灵敏度',
  gyroscopeSmoothing: '陀螺仪平滑',
  gyroscopeSmoothingWindow: '陀螺仪平滑窗口',

  // 手柄（安卓 SDL 直通，iOS 需 GameController.framework 另接）
  gamepadCameraSensitivity: '手柄镜头灵敏度',
  gamepadControl: '手柄控制',
  gamepadCursorSensitivity: '手柄光标灵敏度',
  gamepadDeadZoneScale: '手柄死区',
  gamepadInputMode: '手柄输入模式',
  gamepadInputModePrompted: '手柄提示已读',
  gamepadMappingConfig: '手柄映射',

  // 鼠标热区（安卓 SurfaceView 触摸热区，iOS 无此概念）
  arrowMouseHotspot: '箭头鼠标热区',
  crossHairMouseHotspot: '准星鼠标热区',
  iBeamMouseHotspot: 'I型鼠标热区',
  linkMouseHotspot: '链接鼠标热区',
  notAllowedMouseHotspot: '禁止鼠标热区',
  resizeAllMouseHotspot: '全向缩放热区',
  resizeEWMouseHotspot: '横向缩放热区',
  resizeNSMouseHotspot: '纵向缩放热区',

  // 物理键 IME（安卓物理键盘输入法码）
  physicalKeyImeCode: '物理键输入法码',
  physicalMouseMode: '物理鼠标模式',

  // SDL / 安卓输入法
  sdlAutoShowIme: 'SDL自动弹输入法',
  imeMagnifierAutoShow: '输入法放大镜',

  // 悬浮菜单球（安卓悬浮窗，iOS 无悬浮窗权限）
  showMenuBall: '显示悬浮球',
  menuBallOpacity: '悬浮球透明度',
  menuBallPos: '悬浮球位置',

  // 安卓启动器外观（Material3 主题 / 暗色模式由系统控制）
  launcherActionMenuSide: '动作菜单方向',
  launcherCustomColor: '自定义主题色',
  launcherCustomPaletteStyle: '自定义配色风格',
  launcherDarkMode: '暗色模式',
  launcherTaskMenuExpanded: '任务菜单展开',

  // 热键栏（安卓专属触控热键）
  hotbarDoubleClick: '热键栏双击',
  hotbarHeight: '热键栏高度',
  hotbarLongClick: '热键栏长按',
  hotbarLongClickDelay: '热键栏长按延迟',
  hotbarRule: '热键栏规则',
  hotbarWidth: '热键栏宽度',

  // 平台搜索（iOS 版搜索走 Modrinth 单平台）
  searchModpackPlatform: '整合包平台',
  searchModPlatform: '模组平台',
  searchResourcePackPlatform: '资源包平台',
  searchShadersPlatform: '光影平台',

  // 杂项安卓专属
  mouseSize: '鼠标大小',
  mouseTouchBlockMode: '鼠标触摸阻断',
  controlsOpacity: '控制透明度',
  cursorSensitivity: '光标灵敏度',
  mouseCaptureSensitivity: '鼠标捕获灵敏度',
  mouseControlMode: '鼠标控制模式',
  mouseLongPressDelay: '鼠标长按延迟',
  gestureControl: '手势控制',
  gestureLongPressDelay: '手势长按延迟',
  gestureLongPressMouseAction: '手势长按动作',
  gestureTapMouseAction: '手势点击动作',
  joystickControlMode: '摇杆控制模式',
  requestMaxRefreshRate: '请求最大刷新率',
  showSponsorship: '显示赞助',
  hideMouse: '隐藏鼠标',
  enableMouseClick: '启用鼠标点击',
};

// iOS 上「应该」生效但没接线的 → 列出来当 TODO（真 bug）
const shouldWork = {
  controlLayout: '当前控制布局',
  enableTerracotta: '启用Terracotta联机',
  enableTerracottaNodes: 'Terracotta节点',
  terracottaNodes: 'Terracotta节点列表',
  fpsDisplayMode: 'FPS显示模式',
  showFPS: '显示FPS',
  showMemory: '显示内存',
  versionIsolation: '版本隔离',
  currentAccount: '当前账号',
  currentGamePathId: '当前游戏目录',
  editorEnableWidgetSnap: '编辑器吸附',
  editorSnapInAllLayers: '全图层吸附',
  editorWidgetSnapMode: '吸附模式',
  finishedGame: '完成游戏标记',
};

const unknown = [
  'lastIgnoredVersion','lastSponsorReportMonth','lastUpgradeCheck','terracottaNoticeVer'
];

const keys = Object.keys(androidOnly);
console.log('=== 应标注为 unsupported（安卓专属）: ' + keys.length + ' 个 ===');
keys.forEach(k => console.log('  ' + k.padEnd(30) + androidOnly[k]));

const sw = Object.keys(shouldWork);
console.log('\n=== 应该生效但没接线（真 TODO）: ' + sw.length + ' 个 ===');
sw.forEach(k => console.log('  ' + k.padEnd(30) + shouldWork[k]));

console.log('\n=== 无 UI 的内部状态位（保持现状即可）: ' + unknown.length + ' 个 ===');
unknown.forEach(k => console.log('  ' + k));
