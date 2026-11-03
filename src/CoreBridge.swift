// ZL2-iOS · 启动核心桥接
// 负责：环境初始化（AME_HOME / 偏好 / JRE 映射）→ 调用 Amethyst 的 launchJVM
import Foundation

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
        // AME_HOME 是 Amethyst 全局数据根
        setenv("AME_HOME", home, 1)
        // GAME_DIR 用于隔离版本的偏好文件
        setenv("GAME_DIR", home, 1)

        // 加载/创建偏好
        loadPreferences(false)

        // 配置 Java 运行时映射：
        // "0" = 当前 profile 的默认选择；版本号 → "internal" 表示用 bundle 内 java_runtimes/java-<ver>-openjdk
        let homes: [String: Any] = [
            "0": ["1_17_newer": "17", "1_16_5_older": "8", "execute_jar": "17"],
            "17": "internal",
            "8": "internal",
        ]
        setPrefObject("java.java_homes", homes)
        #endif

        bootstrapped = true
    }

    /// 用版本元数据启动（需要完整的版本 JSON 与已下载的游戏文件）
    static func launchVersion(_ metadata: [String: Any],
                              width: Int = 1280,
                              height: Int = 720) async throws {
        try bootstrap()
        #if ZL2_CORE_LINKED
        guard runtimeCheck() else {
            throw CoreLaunchError.bootstrapFailed("找不到内置 JRE（java_runtimes/java-17-openjdk/lib/libjli.dylib）")
        }
        // Amethyst 的 launchJVM 内部会弹对话框、操作 UI，必须在主线程调用
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(nil, metadata as NSDictionary, Int32(width), Int32(height), 17)
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
        guard FileManager.default.fileExists(atPath: jarPath) else {
            throw CoreLaunchError.bootstrapFailed("jar 不存在：\(jarPath)")
        }
        #if ZL2_CORE_LINKED
        guard runtimeCheck() else {
            throw CoreLaunchError.bootstrapFailed("找不到内置 JRE")
        }
        let code: Int32 = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let r = launchJVM(nil, jarPath as NSString, Int32(width), Int32(height), 17)
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
        #else
        throw CoreLaunchError.coreNotLinked
        #endif
    }

    /// 运行时自检：JRE 是否就位
    static func runtimeCheck() -> Bool {
        let bundle = Bundle.main.bundlePath
        for v in ["17", "8"] {
            let p = "\(bundle)/java_runtimes/java-\(v)-openjdk/lib/libjli.dylib"
            if FileManager.default.fileExists(atPath: p) { return true }
        }
        let alt = "\(bundle)/java_runtimes/java-17-openjdk/lib/jli/libjli.dylib"
        return FileManager.default.fileExists(atPath: alt)
    }
}
