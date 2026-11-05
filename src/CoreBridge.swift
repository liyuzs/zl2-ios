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
        // 4) 内存分配：优先用设置页的 ramAllocation，没设过才按物理内存推算
        let userRam = UserDefaults.standard.object(forKey: "ramAllocation") as? Int ?? 0
        if userRam > 0 {
            // 用户明确设了，就用他的（同时同步给核心用的 key）
            setPrefObject("general.allocated_memory", userRam)
        } else if getPrefObject("general.allocated_memory") == nil {
            let ramMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
            let alloc = max(512, min(2048, ramMB / 3))
            setPrefObject("general.allocated_memory", alloc)
        }

        // 加载/创建偏好
        loadPreferences(false)

        // 配置 Java 运行时映射：
        // "0" = 当前 profile 的默认选择；版本号 → "internal" 表示用 bundle 内 java_runtimes/java-<ver>-openjdk
        let homes: [String: Any] = [
            "0": ["1_17_newer": "21", "1_16_5_older": "8", "execute_jar": "17"],
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
        if let home = ProcessInfo.processInfo.environment["AME_HOME"] {
            // 用当前实例目录，不能写死 default（切过游戏目录就打错地方了）
            writePerfOptionsIfNeeded(gameDir: VersionRepository.shared.mcRoot.path)
        }
        // JIT 检测：没开 JIT 的话游戏会非常卡，提前告知
        if let jitNote = jitStatusNote() {
            NSLog("[ZL2] \(jitNote)")
        }
        #if ZL2_CORE_LINKED
        guard runtimeCheck() else {
            throw CoreLaunchError.bootstrapFailed("找不到内置 JRE（java_runtimes/java-17-openjdk/lib/libjli.dylib）")
        }
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
        // Amethyst 的 launchJVM 内部会弹对话框、操作 UI，必须在主线程调用
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(Self.currentUsername(), metadata as NSDictionary,
                                  Int32(width), Int32(height), Int32(minJava))
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
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
        if let home = ProcessInfo.processInfo.environment["AME_HOME"] {
            // 用当前实例目录，不能写死 default（切过游戏目录就打错地方了）
            writePerfOptionsIfNeeded(gameDir: VersionRepository.shared.mcRoot.path)
        }
        // JIT 检测：没开 JIT 的话游戏会非常卡，提前告知
        if let jitNote = jitStatusNote() {
            NSLog("[ZL2] \(jitNote)")
        }
        guard FileManager.default.fileExists(atPath: jarPath) else {
            throw CoreLaunchError.bootstrapFailed("jar 不存在：\(jarPath)")
        }
        #if ZL2_CORE_LINKED
        guard runtimeCheck() else {
            throw CoreLaunchError.bootstrapFailed("找不到内置 JRE")
        }
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(Self.currentUsername(), jarPath as NSString, Int32(width), Int32(height), 17)
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
        #else
        throw CoreLaunchError.coreNotLinked
        #endif
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

    /// 运行时自检：JRE 是否就位
    static func runtimeCheck() -> Bool {
        let bundle = Bundle.main.bundlePath
        // Java 17+: lib/libjli.dylib；Java 8: lib/jli/libjli.dylib
        let candidates: [(String, String)] = [
            ("17", "lib/libjli.dylib"),
            ("8",  "lib/jli/libjli.dylib"),
            ("8",  "lib/libjli.dylib"),
        ]
        for (v, rel) in candidates {
            let p = "\(bundle)/java_runtimes/java-\(v)-openjdk/\(rel)"
            if FileManager.default.fileExists(atPath: p) { return true }
        }
        return false
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
                    if mi >= 21 { return 21 }
                    if mi >= 20 { return 21 }   // 1.20.5+ 要 Java 21
                    if mi >= 17 { return 17 }
                    if mi >= 12 { return 17 }
                    return 8
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
        let extraJV = UserDefaults.standard.string(forKey: "jvmArgs") ?? ""
        setenv("AME_EXTRA_JVM_ARGS", extraJV.trimmingCharacters(in: .whitespacesAndNewlines), 1)

        // 1) 渲染器
        let userRenderer = UserDefaults.standard.string(forKey: "renderer") ?? ""
        setenv("RENDERER", userRenderer.isEmpty ? "auto" : userRenderer, 1)

        // 2) 内存分配：用户设了就用他的，同时同步给核心
        let userRam = UserDefaults.standard.object(forKey: "ramAllocation") as? Int ?? 0
        if userRam > 0 {
            setPrefObject("general.allocated_memory", userRam)
        } else if getPrefObject("general.allocated_memory") == nil {
            let ramMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
            setPrefObject("general.allocated_memory", max(512, min(2048, ramMB / 3)))
        }
    }
}
