# FPS / 内存显示接入说明

> 日期：2026-11-08
> 状态：**已接线，待真机验证数值**

---

## 一、问题是什么

`GameOverlay.swift` 里那套 FPS 显示早就写好了（594 行），但有三个断点：

1. **`GameOverlay` 从来没被挂到任何视图上** —— 全局搜 `GameOverlay(` 零结果
2. **`fpsProvider` 没有调用方传入** —— 代码注释里写着「不传时显示 0」
3. **`showMenuBall` 默认 false** —— 而启动采样器的条件是 `showMenuBall && showFPS`，所以永远不启动

结果：设置里能打开「显示 FPS」，但游戏里什么都不会出现。

---

## 二、修复方案：打通 8 个环节

```
① 渲染线程每帧
   core/egl_bridge.m : pojavSwapBuffers()
        ↓ 调用
② 原子计数器
   core/ZL2FrameStats.m : atomic_fetch_add_explicit(&g_frameCount, 1)
        ↓ 加入构建
③ core/CMakeLists.txt : ZL2Core STATIC 源列表加入 ZL2FrameStats.m
        ↓ 静态库导出符号
④ Swift 侧声明
   src/ZL2FrameStats.swift : @_silgen_name("ZL2FrameStatsTotal")
        ↓ 每秒读一次
⑤ 差分算 FPS
   fps = (本次累计 - 上次累计) / 经过时间
        ↓
⑥ 悬浮层订阅
   src/GameOverlay.swift : @StateObject var perf = ZL2PerfSampler()
        ↓
⑦ 挂到游戏视图
   src/ZLOverlayHost.swift : attach(to: container)
        ↓
⑧ ObjC 侧调用
   core/SurfaceViewController.m : viewDidLoad → [ZLOverlayHost attachTo:self.rootView]
                                  viewDidDisappear → [ZLOverlayHost detach]
```

---

## 三、关键设计说明

### 为什么在渲染线程只做计数

`pojavSwapBuffers()` 在渲染线程上，每帧调用一次。这里**只做一次原子加**，不加锁、不碰 UI、不分配内存。

真正的 FPS 计算放在 Swift 的主线程 Timer 里，每秒读一次累计值做差分。这样：

- 渲染线程零额外开销
- 不会因为计算逻辑拖慢游戏
- 暂停/切后台时的异常值可以在这里钳制（已加入 `> 240` 的钳位）

### 为什么用 `@_silgen_name`

ZL2Core 是 ObjC/C 静态库，Swift 要调用 `ZL2FrameStatsTotal()` 这类 C 函数有两种方式：

- 走 Bridging Header（要额外维护头文件）
- `@_silgen_name` 直接声明符号（更轻，但要注意签名必须完全一致）

选了后者，并用 `#if ZL2_CORE_LINKED` 包住——因为模拟器构建不链接核心（见 `project.yml` 的 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`），没有这个条件编译模拟器编不过。

### 为什么 `showMenuBall` 默认改成 true

安卓默认 false，是因为它画的是**系统级悬浮窗**，需要额外权限，默认关是怕用户被拒。

iOS 版画的是 **App 自己游戏画面之上的 SwiftUI 视图**，走 `rootView.addSubview`，不涉及任何系统权限。所以默认开是安全的，也让用户一进游戏就能看到 FPS。

### 内存为什么用 mach task_info

`ProcessInfo.physicalMemory` 返回的是**设备总内存**，不是进程占用。
`task_vm_info.phys_footprint` 返回的是**本进程真实物理内存占用**，和安卓的「已用内存」含义最接近。

两者配合才能显示「已用 / 总量」。

---

## 四、涉及文件

| 文件 | 改动 |
|---|---|
| `core/egl_bridge.m` | `pojavSwapBuffers()` 里加一行 `ZL2FrameStatsTick()` |
| `core/ZL2FrameStats.m` | **新增**，原子计数 + mach 内存读取 |
| `core/CMakeLists.txt` | 源列表加 `ZL2FrameStats.m` |
| `core/SurfaceViewController.m` | `viewDidLoad` 挂载、`viewDidDisappear` 摘除 |
| `src/ZL2FrameStats.swift` | **新增**，`ZL2PerfSampler` 每秒采样 |
| `src/ZLOverlayHost.swift` | **新增**，SwiftUI ↔ UIKit 桥接 |
| `src/GameOverlay.swift` | 改用 `ZL2PerfSampler`；`showMenuBall` 默认 true；采样条件放宽 |
| `src/SettingsScreen.swift` | 把 `showFPS`/`showMemory`/`fpsDisplayMode`/`showMenuBall` 从「不支持」名单移出 |

---

## 五、真机验证要点

装到手机后，按这个顺序查：

1. **进游戏 → 右下角有没有悬浮球？**
   - 没有 → `ZLOverlayHost.attach` 没被调用，看 `NSClassFromString` 是否找到类
   - 类名可能是 `ZL2iOS.ZLOverlayHost`，也可能只是 `ZLOverlayHost`（代码里两种都试了）

2. **点悬浮球 → 有没有 FPS 数字？**
   - 一直是 0 → `ZL2FrameStatsTick` 没被调用，检查 `pojavSwapBuffers` 是否真的走这条路
   - 可能是别的渲染路径（比如 Vulkan 直接 present，不走 eglSwapBuffers）

3. **内存条有没有数值？**
   - 有 → mach 读取正常
   - 0 / 0 → `phys_footprint` 失败

4. **拖动悬浮球位置能不能保存？**
   - 松手后退出再进，位置应该记住（存 `menuBallPos`）

---

## 六、已知限制

- **Zink 渲染路径可能测不到 FPS** —— 只有走 `pojavSwapBuffers` 的路径会计数。如果玩家选了 Zink（OSMesa），渲染走的是 `osm_bridge`，那条路目前没插桩。真机上如果发现 Zink 下 FPS 恒为 0，需要在 `osm_bridge.m` 的 present 处补一次 `ZL2FrameStatsTick()`。
- **模拟器下 FPS 恒为 0** —— 没有核心，这是预期行为，界面仍能正常显示。
