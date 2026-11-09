// ZL2-iOS · 启动核心桥接
// 负责：环境初始化（AME_HOME / 偏好 / JRE 映射）→ 调用 Amethyst 的 launchJVM
import Foundation
import UIKit
import Darwin

enum CoreLaunchError: LocalizedError {
    case coreNotLinked
    case bootstrapFailed(String)
    case launchReturned(Int32)
    case missingRuntime

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "启动核心未链接（当前构建未启用 Amethyst 核心）"
        case .bootstrapFailed(let m):
            return "初始化失败：\(m)"
        case .launchReturned(let code):
            return "launchJVM 返回错误码 \(code)"
        case .missingRuntime:
            return "缺少 Java 运行时"
        }
    }
}

enum CoreBridge {
    /// 当前构建是否带核心（CI 通过 SWIFT_ACTIVE_COMPILATION_CONDITIONS 注入）
    static var isCoreLinked: Bool {
        #if ZL2_CORE_LINKED
        return true
        #else
        return false
        #endif
    }

    private static var bootstrapped = false

    /// 切换游戏目录后调用：下次启动/启动游戏时重新写入 GAME_DIR
    static func resetBootstrap() {
        bootstrapped = false
    }

    /// 初始化 Amethyst 运行环境（照搬 main.m 的逻辑）
    static func bootstrap() throws {
        guard isCoreLinked else { throw CoreLaunchError.coreNotLinked }
        guard !bootstrapped else { return }

        let fm = FileManager.default
        guard let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last else {
            throw CoreLaunchError.bootstrapFailed("无法获取 Documents 目录")
        }
        let home = docs
        if !fm.fileExists(atPath: home) {
            do {
                try fm.createDirectory(atPath: home, withIntermediateDirectories: true)
            } catch {
                throw CoreLaunchError.bootstrapFailed("创建数据目录失败：\(error.localizedDescription)")
            }
        }

        #if ZL2_CORE_LINKED
        // 日志重定向（真机调试必需：Amethyst 的 printf/NSLog 输出落到文件）
        setupLogging(home: home)
        // AME_HOME 是 Amethyst 全局数据根
        setenv("AME_HOME", home, 1)
        // GAME_DIR 必须指向实例的 .minecraft 目录：
        // 核心约定 <GAME_DIR>/versions/<id>/<id>.json，
        // VersionInstaller / LaunchScreen / VersionRepository 都用
        // <Documents>/instances/<name>/.minecraft，这里必须对齐，否则装好的版本找不到
        // 当前实例名由 VersionRepository 持有（游戏目录页可切换）。
        let gameDir = VersionRepository.shared.mcRoot.path
        try? fm.createDirectory(atPath: gameDir, withIntermediateDirectories: true)
        setenv("GAME_DIR", gameDir, 1)

        // 先把偏好加载出来，再做任何读写偏好的事。
        //
        // 这里踩过一个隐蔽的坑：loadPreferences() 会**新建**一个 PLPreferences 实例
        // （`pref = [[PLPreferences alloc] initWithAutomaticMigrator]`）。
        // 原来它在 applyUserSettings() 之后才调用，等于：
        //   ① applyUserSettings 里的 setPrefObject 写在一个还没初始化的全局 pref 上
        //      （ObjC 对 nil 发消息是静默无操作，不报错），全部丢失；
        //   ② 后面即便写了，也会被新实例的磁盘加载覆盖。
        // 顺序必须是：setenv（GAME_DIR 决定实例路径）→ loadPreferences → 再读写。
        loadPreferences(false)

        // 应用用户设置（每次启动游戏都要重新读，不能只做一次）
        applyUserSettings()

        // 以下是一次性初始化
        // 2) JIT 常驻（性能关键：避免反复 attach 造成卡顿）
        if getPrefObject("debug.debug_always_attached_jit") == nil {
            setPrefObject("debug.debug_always_attached_jit", true)
        }
        // 3) 关掉装饰性功能（省 GPU/CPU）
        if getPrefObject("general.cosmetica") == nil {
            setPrefObject("general.cosmetica", false)
        }
        // 4) 内存分配（统一走 syncMemorySetting，见那里的注释）
        syncMemorySetting()

        // 5) 控件布局目录 + 默认布局
        //
        // 核心里那个 generateAndSaveDefaultControl() **从来没有被任何地方调用过**，
        // 而 defaultTouchCtrl 的默认值就是 "default.json"。
        // 于是首次启动时核心会去读 <AME_HOME>/controlmap/default.json：
        //   · 文件不存在 → parseJSONFromFile 返回 NSErrorObject
        //   · ControlLayout loadControlFile: 弹 "Could not open ..."
        //   · 而且屏幕上没有任何控件 —— 进游戏等于没法操作
        //
        // 这里主动把目录建好再调一次生成。注意顺序不能反：
        // 该函数用 NSOutputStream 写文件，父目录不存在时会**静默失败**，
        // 不报错也不生成，症状和没调用一样。
        let controlMapDir = (home as NSString).appendingPathComponent("controlmap")
        try? fm.createDirectory(atPath: controlMapDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: (controlMapDir as NSString).appendingPathComponent("gamepads"),
                                withIntermediateDirectories: true)
        // 手柄默认布局也生成一份（没有手柄时用不到，但目录和文件先备好）
        generateAndSaveDefaultControlForGamepad()

        // UIKit 钩子：上游在 main.m 里调，我们用 SwiftUI @main 所以从没装过。
        // 放在这里是因为它依赖偏好（debug.debug_ipad_ui），而偏好刚在上面加载完。
        init_hookUIKitConstructor()
        generateAndSaveDefaultControl()
        let defaultLayoutPath = (controlMapDir as NSString).appendingPathComponent("default.json")
        if fm.fileExists(atPath: defaultLayoutPath) {
            NSLog("[ZL2] 默认控制布局已就位：%@", defaultLayoutPath)
        } else {
            NSLog("[ZL2] 警告：默认控制布局生成失败，进游戏会没有控件")
        }

        // 配置 Java 运行时映射：
        // "0" = 当前 profile 的默认选择；版本号 → "internal" 表示用 bundle 内 java_runtimes/java-<ver>-openjdk
        // 注意 "1_17_newer" 这里必须写 17，不能写 21。
        //
        // 核心 getSelectedJavaHome() 的逻辑是：先取 java_homes["0"][tag] 的版本，
        // 只有当 minVersion **大于**它时才往上调（遍历 allKeys 找第一个 >= minVersion 的）。
        // 也就是说这个值是"下限"，不是一个"固定选择"。
        //
        // 写成 21 的后果：MC 1.17 ~ 1.20.4 传进来的 minVersion 是 17，
        // 17 不大于 21 → 保持 21 → 拿 Java 21 去跑 1.20.1（最热门的模组版本）。
        // 而 1.17 用 Java 21 会直接崩（当时的 LWJGL 3.2.2 与 Mixin 不支持新字节码）。
        //
        // 写成 17 之后，1.20.5+ 传 minVersion=21、26+ 传 25，
        // 核心的向上调整逻辑会正确挑到 21 / 25，两种情况都对。
        let homes: [String: Any] = [
            "0": ["1_17_newer": "17", "1_16_5_older": "8", "execute_jar": "17"],
            "8": "internal",
            "17": "internal",
            "21": "internal",
            "25": "internal",
        ]
        // 只在没有配置时写默认（避免抹掉用户在 JRE 管理界面里的选择）
        if let existing = getPrefObject("java.java_homes") as? [String: Any] {
            // 补齐缺失的版本（老配置里可能只有 8/17）
            var merged = existing
            for (k, v) in homes where merged[k] == nil {
                merged[k] = v
            }
            // 定向纠正：修复前的版本会把 "1_17_newer" 写成 "21"，
            // 而 "21" 只有我们自己会写进去（用户在 JRE 管理界面里改的是各版本条目，
            // 不是这个 tag）。留着它会让 1.17~1.20.4 被拉去 Java 21 而崩。
            if var zero = merged["0"] as? [String: Any],
               (zero["1_17_newer"] as? String) == "21" {
                zero["1_17_newer"] = "17"
                merged["0"] = zero
                NSLog("[ZL2] 已纠正 java_homes 的 1_17_newer: 21 -> 17（旧版本写错了）")
            }
            setPrefObject("java.java_homes", merged)
        } else {
            setPrefObject("java.java_homes", homes)
        }
        #endif

        bootstrapped = true
    }

    /// 把 stdout/stderr 重定向到 Documents/ame.log
    static func setupLogging(home: String) {
        let logPath = (home as NSString).appendingPathComponent("ame.log")
        // 保留最近一次：超过 2MB 就清空
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
           let size = attrs[.size] as? Int, size > 2 * 1024 * 1024 {
            try? FileManager.default.removeItem(atPath: logPath)
        }
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        freopen(logPath, "a", stdout)
        freopen(logPath, "a", stderr)
        setvbuf(stdout, nil, _IOLBF, 0)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("\n===== ZL2 启动 \(f.string(from: Date())) =====")
        print("AME_HOME=\(home)")
        print("bundle=\(Bundle.main.bundlePath)")
    }

    /// 用版本元数据启动（需要完整的版本 JSON 与已下载的游戏文件）
    /// 按「分辨率缩放」设置和屏幕尺寸算出渲染宽高
    /// 安卓的 resolutionRatio 是百分比（25~300），即渲染分辨率 = 屏幕分辨率 × 比例
    static func renderSize() -> (width: Int, height: Int) {
        let ratio = UserDefaults.standard.object(forKey: "resolutionRatio") as? Int ?? 100
        let rule = UserDefaults.standard.string(forKey: "resolutionRule") ?? "ResolutionRule.PERCENTAGE"

        // 自定义分辨率（用户直接填了宽高）
        if rule.contains("CUSTOM") {
            let w = UserDefaults.standard.object(forKey: "customResolutionWidth") as? Int ?? 0
            let h = UserDefaults.standard.object(forKey: "customResolutionHeight") as? Int ?? 0
            if w > 0 && h > 0 { return (w, h) }
        }

        // 按屏幕尺寸 × 百分比
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let baseW = Double(screen.width * scale)
        let baseH = Double(screen.height * scale)
        let pct = Double(max(25, min(300, ratio))) / 100.0
        // 偶数，避免某些渲染器要求
        var w = Int((baseW * pct).rounded())
        var h = Int((baseH * pct).rounded())
        if w % 2 != 0 { w += 1 }
        if h % 2 != 0 { h += 1 }
        return (max(320, w), max(240, h))
    }

    static func launchVersion(_ metadata: [String: Any],
                              width: Int = 0,
                              height: Int = 0) async throws {
        try bootstrap()
        // 每次启动都重新读设置，改完设置不用重启 App
        applyUserSettings()

        // 版本隔离：开了「全局版本隔离」后，该版本用自己的目录（versions/<id>/），
        // 模组/存档/配置互不干扰。核心读的是 GAME_DIR 环境变量，
        // 所以必须在 launchJVM 之前把它改成隔离目录。
        let versionID = (metadata["id"] as? String) ?? ""
        // 隔离目录仍然准备好（万一以后核心支持了直接能用），但**不再拿它当 GAME_DIR**。
        //
        // 原因：核心 JavaLauncher.m:179-182 在元数据启动分支里会自己算游戏目录
        // （instances/<general.game_directory>/<profile.gameDir>），**完全忽略 GAME_DIR**。
        // 我们之前把 GAME_DIR 指向隔离目录，等于"告诉它 A、它实际用 B"，
        // 两边不一致，用户看到的模组目录和游戏真正读的不是同一个。
        // 现在统一用 mcRoot，与 applyUserSettings 里设置的 general.game_directory 对齐。
        _ = VersionRepository.shared.prepareIsolatedDir(for: versionID)
        let effectiveGameDir = VersionRepository.shared.mcRoot.path
        setenv("GAME_DIR", effectiveGameDir, 1)
        NSLog("[ZL2] GAME_DIR = %@ (隔离=%@)", effectiveGameDir,
              VersionRepository.shared.isolationEnabled ? "开" : "关")

        if ProcessInfo.processInfo.environment["AME_HOME"] != nil {
            // 用当前生效目录，不能写死 default（切过游戏目录就打错地方了）
            writePerfOptionsIfNeeded(gameDir: effectiveGameDir)
        }

        // 启动前把编辑器里当前选的布局同步给核心，
        // 否则改了控件位置进游戏还是不生效（两套格式不同，必须转换）
        syncControlLayoutIfNeeded()
        // JIT 检测：没开 JIT 的话游戏会非常卡，提前告知
        if let jitNote = jitStatusNote() {
            NSLog("[ZL2] \(jitNote)")
        }
        #if ZL2_CORE_LINKED
        // 宽高为 0 时按设置自动计算
        let (w0, h0) = (width > 0 && height > 0) ? (width, height) : Self.renderSize()
        let width = w0
        let height = h0
        // Java 版本：用户关了自动选择且填了运行时就照办，否则按版本自动判断
        let autoPick = UserDefaults.standard.object(forKey: "autoPickJavaRuntime") as? Bool ?? true
        let manual = UserDefaults.standard.string(forKey: "javaRuntime") ?? ""
        let manualVer = Int(manual.trimmingCharacters(in: .whitespaces))
        let minJava: Int
        if !autoPick, let mv = manualVer, mv > 0 {
            minJava = mv
        } else {
            minJava = Self.requiredJavaVersion(metadata)
        }
        // JRE 自检必须按 minJava 查 —— 只要"任意一个 JRE 在"就放行，
        // 会在缺对应版本时一路走到 launchJVM 才失败，且报错看不出是版本挑错了。
        guard Self.runtimeCheck(forJava: minJava) else {
            let have = Self.bundledJavaVersions().map { "Java \($0)" }
            throw CoreLaunchError.bootstrapFailed(
                "这个版本需要 Java \(minJava)，但包里只有：\(have.isEmpty ? "一套都没有" : have.joined(separator: "、"))"
            )
        }
        // Amethyst 的 launchJVM 内部会弹对话框、操作 UI，必须在主线程调用
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(Self.currentUsername(), metadata as NSDictionary,
                                  Int32(width), Int32(height), Int32(minJava))
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
        // 启动成功 → 累计一次（ZL2 的 finishedGame 计数，用于赞助提示）
        recordGameLaunch()
        #else
        throw CoreLaunchError.coreNotLinked
        #endif
    }

    /// 用 jar 路径直接启动（Amethyst 的最小验证路径）
    static func launchJar(_ jarPath: String,
                          width: Int = 1280,
                          height: Int = 720) async throws {
        try bootstrap()
        applyUserSettings()
        // 直接跑 jar 时没有版本 ID，用 jar 文件名当前缀建一个隔离目录，
        // 免得把测试产生的存档混进主目录
        let pseudoID = URL(fileURLWithPath: jarPath).deletingPathExtension().lastPathComponent
        let isolatedDir = VersionRepository.shared.prepareIsolatedDir(for: pseudoID)
        setenv("GAME_DIR", isolatedDir.path, 1)
        if ProcessInfo.processInfo.environment["AME_HOME"] != nil {
            writePerfOptionsIfNeeded(gameDir: isolatedDir.path)
        }
        // JIT 检测：没开 JIT 的话游戏会非常卡，提前告知
        if let jitNote = jitStatusNote() {
            NSLog("[ZL2] \(jitNote)")
        }
        guard FileManager.default.fileExists(atPath: jarPath) else {
            throw CoreLaunchError.bootstrapFailed("jar 不存在：\(jarPath)")
        }
        #if ZL2_CORE_LINKED
        // launchJar 固定用 Java 17，所以按 17 查
        guard Self.runtimeCheck(forJava: 17) else {
            let have = Self.bundledJavaVersions().map { "Java \($0)" }
            throw CoreLaunchError.bootstrapFailed(
                "运行 jar 需要 Java 17，但包里只有：\(have.isEmpty ? "一套都没有" : have.joined(separator: "、"))"
            )
        }
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(Self.currentUsername(), jarPath as NSString, Int32(width), Int32(height), 17)
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
        // 启动成功 → 累计一次（ZL2 的 finishedGame 计数，用于赞助提示）
        recordGameLaunch()
        #else
        throw CoreLaunchError.coreNotLinked
        #endif
    }

    /// 记录一次成功启动（对应 ZL2 的 finishedGame 设置项）
    ///
    /// ZL2 用它统计「启动器已经帮你跑了多少次游戏」，攒够了弹一次赞助提示。
    /// 顺便记录首次启动时间，方便以后做使用时长统计。
    static func recordGameLaunch() {
        let d = UserDefaults.standard
        let count = d.integer(forKey: "finishedGame") + 1
        d.set(count, forKey: "finishedGame")
        if d.object(forKey: "firstLaunchDate") == nil {
            d.set(Date(), forKey: "firstLaunchDate")
        }
        d.set(Date(), forKey: "lastLaunchDate")
        NSLog("[ZL2] 第 %ld 次启动游戏", count)
    }

    /// 累计启动次数（供 UI 显示）
    static var gameLaunchCount: Int {
        UserDefaults.standard.integer(forKey: "finishedGame")
    }

    /// 把编辑器当前布局翻译成核心格式（启动前调用一次）
    ///
    /// 编辑器和核心用的 JSON 结构完全不同，必须转换。
    /// 转换失败不应该阻断启动，所以这里吞掉错误只打日志。
    static func syncControlLayoutIfNeeded() {
        let name = UserDefaults.standard.string(forKey: "zl.currentControlLayout") ?? ""
        guard !name.isEmpty else { return }   // 用户没选过自定义布局，用核心自带默认
        do {
            let synced = try CoreLayoutExporter.syncFromEditor(name: name)
            // 光把 JSON 写进 controlmap/ 是不够的 —— 还得告诉核心「去加载这个文件」。
            //
            // 核心读布局文件名的位置是 SurfaceViewController.m:464 的
            //   [PLProfiles resolveKeyForCurrentProfile:@"defaultTouchCtrl"]
            // 而 PLProfiles.m:35 的 resolveKey: 只查两个地方：
            //   ① profile["defaultTouchCtrl"]  → <GAME_DIR>/launcher_profiles.json
            //   ② 兜底 getPrefObject("control.default_ctrl") → PLPreferences 的 plist
            // 原来这两处都没写（只写了 UserDefaults.standard，核心根本不看），
            // 结果就是：布局文件导出成功，核心却还在加载默认布局。
            //
            // 这里写第 ② 处：用 setPrefObject 走核心的偏好系统。
            // 必须在 bootstrap()（内部 loadPreferences）之后调用，否则 pref 还是 nil，
            // ObjC 对 nil 发消息是静默无操作，写了也白写。
            setPrefObject("control.default_ctrl", synced)
            NSLog("[ZL2] 控制布局已同步：%@（已告知核心加载）", synced)
        } catch {
            NSLog("[ZL2] 控制布局同步失败（不影响启动）：%@", error.localizedDescription)
        }
    }

    /// 当前账户名（核心要把它写进 argv，传 nil 会崩）
    /// 优先用账号系统里选中的账号，其次看旧的 UserDefaults 键，最后兜底 Player。
    static func currentUsername() -> String {
        if let name = AccountStore.shared.current?.username, !name.isEmpty {
            return name
        }
        if let name = UserDefaults.standard.string(forKey: "zl.currentUsername"), !name.isEmpty {
            return name
        }
        return "Player"
    }

    /// 某个 Java 大版本的内置运行时是否就位。
    ///
    /// 为什么要按版本查：`runtimeCheck()` 只要任意一个 JRE 在就返回 true，
    /// 但真正启动时用的是按游戏版本算出来的 minJava（MC 26+ 要 25，1.20.5+ 要 21）。
    /// 三个 JRE 里恰好缺了要用的那个时，「自检通过」会一路放行到 launchJVM 才失败，
    /// 报错还看不出来是版本挑错了。
    static func hasRuntime(java major: Int) -> Bool {
        let base = "\(Bundle.main.bundlePath)/java_runtimes/java-\(major)-openjdk"
        // Java 8 的 jli 在 lib/jli/ 下，17+ 在 lib/ 下；两个都试，别让布局差异造成误判
        let rels = ["lib/libjli.dylib", "lib/jli/libjli.dylib"]
        return rels.contains { FileManager.default.fileExists(atPath: base + "/" + $0) }
    }

    /// 按需要的 Java 大版本自检。
    static func runtimeCheck(forJava major: Int) -> Bool {
        guard hasRuntime(java: major) else { return false }
        // 映射表里写明某版本用 internal，但 internal 指的是"用包里自带的那套"。
        // 这里只校验文件在不在，映射对不对由 bootstrap 的 java.java_homes 负责。
        return true
    }

    /// 包里实际带了的 Java 大版本（升序），用于报错时告诉用户"你有这些，但需要那个"
    static func bundledJavaVersions() -> [Int] {
        [8, 17, 21, 25].filter { hasRuntime(java: $0) }
    }

    /// 运行时自检（通用）：只要有任何一套 JRE 就返回 true。
    /// 界面上的"环境自检"用它；真正启动前必须用 runtimeCheck(forJava:)。
    static func runtimeCheck() -> Bool {
        !bundledJavaVersions().isEmpty
    }
    /// 检查 JIT 是否已启用（iOS 上需要 StikDebug 等外部工具附加）
    /// 返回 nil 表示正常；返回字符串表示需要提示用户
    static func jitStatusNote() -> String? {
        // 核心用 JIT26CreateRegionLegacy 检测；这里做轻量判断：
        // 有 JIT 时 W^X 可写可执行区域能创建；没有时 malloc 的页不可执行
        let page = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 4096)
        defer { page.deallocate() }
        // 尝试 mprotect 为可写可执行（JIT 未开时 iOS 会拒绝）
        let result = mprotect(page, 4096, PROT_READ | PROT_WRITE | PROT_EXEC)
        if result != 0 {
            return "JIT 未启用：请在 StikDebug 里对 ZL2 启用 JIT 后再启动游戏，否则会非常卡或闪退"
        }
        return nil
    }

    /// 首次启动前写入性能优先的 options.txt（视距 4、快速画质、关粒子）
    static func writePerfOptionsIfNeeded(gameDir: String) {
        let path = (gameDir as NSString).appendingPathComponent("options.txt")
        guard !FileManager.default.fileExists(atPath: path) else { return }
        let content = """
        version:3465
        renderDistance:4
        simulationDistance:4
        graphicsMode:0
        particles:2
        ao:false
        entityShadows:false
        maxFps:60
        enableVsync:false
        fov:0.0
        gamma:0.5
        clouds:false
        fancyGraphics:false
        smoothLighting:false
        biomeBlendRadius:1
        mipmapLevels:0
        """
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func requiredJavaVersion(_ metadata: [String: Any]) -> Int {
        if let jv = metadata["javaVersion"] as? [String: Any],
           let major = jv["majorVersion"] as? Int, major > 0 {
            return major
        }
        if let id = metadata["id"] as? String {
            let parts = id.split(separator: ".")
            if parts.count >= 2, let ma = Int(parts[0]), let mi = Int(parts[1]) {
                if ma == 1 {
                    if mi >= 21 { return 21 }            // 1.21+ 要 Java 21
                    if mi == 20 {
                        // 1.20 这条线要拆开：分界点是 1.20.5。
                        // 1.20.0 ~ 1.20.4（含很常见的 1.20.1）要 Java 17，
                        // 1.20.5 起才改要 21。只看次版本号会把整个 1.20.x 都判成 21，
                        // 拿 21 跑 1.20.1 时部分 Fabric/Sodium 模组会出问题。
                        let patch = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
                        return patch >= 5 ? 21 : 17
                    }
                    if mi >= 17 { return 17 }            // 1.17 ~ 1.19.x 要 Java 17
                    // 1.12 ~ 1.16 官方要求 Java 8。包里没有 Java 8，这里仍然返回 17：
                    // 原版在 17 上能跑，返回 8 只会让这批版本一律启动失败。
                    // 真需要 Java 8 的场景（老 Forge）由用户自己配运行时的开关兜。
                    if mi >= 12 { return 17 }
                    return 8                              // ≤1.11 必须 Java 8，包里没有 → 明确报错
                }
                if ma >= 26 { return 25 }        // MC 26+ 要 Java 25
                if ma >= 22 { return 25 }
            }
        }
        return 17
    }

    /// 把用户设置写进环境变量。每次启动游戏前都要调一次，
    /// 否则用户改了渲染器/内存/JVM 参数后不重启 App 就不会生效。
    static func applyUserSettings() {
        // 0) 自定义 JVM 参数
        var extraJV = UserDefaults.standard.string(forKey: "jvmArgs") ?? ""
        extraJV = extraJV.trimmingCharacters(in: .whitespacesAndNewlines)

        // 配置了皮肤站就挂 authlib-injector，皮肤/披风才能在游戏里显示
        if let agent = ZLAuthlibInjector.javaAgentArgument() {
            if extraJV.isEmpty {
                extraJV = agent
            } else if !extraJV.contains("authlib-injector") {
                extraJV += " " + agent
            }
        }
        setenv("AME_EXTRA_JVM_ARGS", extraJV, 1)

        // 1) 渲染器
        // 存进去的值可能是老版本留下的（比如 iOS 上根本不存在的 MobileGlues），
        // 也可能是用户手输错的。核心拿到名字会直接 dlopen("@rpath/<名字>")，
        // 名字对不上就是启动失败，所以写进环境变量之前先净化一遍。
        let storedRenderer = UserDefaults.standard.string(forKey: "renderer") ?? ""
        let safeRenderer = ZLRenderers.sanitize(storedRenderer)
        if safeRenderer != storedRenderer {
            NSLog("[ZL2] 渲染器 %@ 不可用，已改为 %@",
                  storedRenderer, ZLRenderers.displayName(for: safeRenderer))
            UserDefaults.standard.set(safeRenderer, forKey: "renderer")
        }
        // 只设环境变量不够。JavaLauncher.m:175 进到启动流程后会重新读一次：
        //     NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"];
        //     setenv("RENDERER", renderer.UTF8String, 1);
        // 而 resolveKey 的兜底是 getPrefObject("video.renderer")（默认 "auto"），
        // 于是我们刚设的环境变量立刻被冲掉 —— 用户选的渲染器实际不生效，
        // 最终总是回落到 auto。所以必须同时写进 video.renderer。
        setPrefObject("video.renderer", safeRenderer)
        setenv("RENDERER", safeRenderer, 1)

        // 2) 内存分配
        syncMemorySetting()

        // 3) 游戏目录：必须让核心算出来的路径 = 我们实际安装的路径
        //
        // 核心（JavaLauncher.m:179-182）自己拼：
        //   <AME_HOME>/instances/<general.game_directory>/<profile.gameDir>
        // 而我们把版本装在 <Documents>/instances/<实例名>/.minecraft/
        //
        // 这两个值核心都有硬编码默认：「general.game_directory」默认 "default"、
        // profile 的 gameDir 默认 "."（PLProfiles.m:44）。拼出来是
        //   <Documents>/instances/default/.
        // 经 stringByStandardizingPath 去掉 "/." 之后变成
        //   <Documents>/instances/default
        // —— 比我们的实际目录少一层 .minecraft。
        //
        // 后果：Java 侧去 instances/default/versions/<id>/<id>.json 找版本，
        // 而文件在 instances/default/.minecraft/versions/<id>/<id>.json，
        // 表现是「版本明明装好了，启动却说找不到」。
        //
        // 修法：把 general.game_directory 设成 "<实例名>/.minecraft"，
        // 与默认的 gameDir "." 拼起来正好是我们要的目录。
        // 这里不写 launcher_profiles.json —— 那要多一套 JSON 读写，
        // 而 profile 里 gameDir 不填就走默认 "."，一个 pref 就够。
        let instance = VersionRepository.shared.instanceName
        setPrefObject("general.game_directory", "\(instance)/.minecraft")
    }

    /// 把设置页的内存分配同步到核心真正读的键。
    ///
    /// 踩过的坑（两个叠在一起）：
    ///  ① 原来写的是 `general.allocated_memory`，但核心读的是
    ///     `java.allocated_memory`（JavaLauncher.m:217，SurfaceViewController.m:322
    ///     算内存上限时也用这个键）。名字对不上 → 用户拖了滑块完全没用，
    ///     JVM 一直拿默认值。这是典型的「写了没人读」。
    ///  ② 核心在 `java.auto_ram` 为真时**根本不看** allocated_memory
    ///     （JavaLauncher.m:213 走自动比例），而在没有内存 entitlement 的设备上
    ///     `java.auto_ram` 默认就是真（PLPreferences.m:63）。所以即使用对了键名，
    ///     不把它关掉也照样无效。
    ///
    /// 另外把值压到物理内存的一半以内：滑块的范围是 256...Int.max，
    /// 填个离谱的数会让 JVM 申请不到连续内存，核心那边只会弹一句英文报错。
    static func syncMemorySetting() {
        let userRam = UserDefaults.standard.object(forKey: "ramAllocation") as? Int ?? 0
        // 用户没设过：不插手，保持核心的自动策略（物理内存的 25%）
        guard userRam > 0 else { return }

        let ramMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
        let cap = max(512, ramMB / 2)
        let alloc = min(max(256, userRam), cap)

        setPrefObject("java.allocated_memory", alloc)
        setPrefBool("java.auto_ram", false)

        if alloc != userRam {
            NSLog("[ZL2] 内存分配 %d MB 超出合理范围，已压到 %d MB（物理内存 %d MB）",
                  userRam, alloc, ramMB)
        }
    }
}
