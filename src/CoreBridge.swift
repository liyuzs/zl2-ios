// ZL2-iOS · 启动核心桥接
// 负责：环境初始化（AME_HOME / 偏好 / JRE 映射）→ 调用 Amethyst 的 launchJVM
import Foundation
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
        let gameDir = (home as NSString)
            .appendingPathComponent("instances/default/.minecraft")
        try? fm.createDirectory(atPath: gameDir, withIntermediateDirectories: true)
        setenv("GAME_DIR", gameDir, 1)

        // 加载/创建偏好
        loadPreferences(false)

        // 配置 Java 运行时映射：
        // "0" = 当前 profile 的默认选择；版本号 → "internal" 表示用 bundle 内 java_runtimes/java-<ver>-openjdk
        let homes: [String: Any] = [
            "0": ["1_17_newer": "17", "1_16_5_older": "8", "execute_jar": "17"],
            "17": "internal",
            "8": "internal",
        ]
        // 只在没有配置时写默认（避免抹掉用户在 JRE 管理界面里的选择）
        if getPrefObject("java.java_homes") == nil {
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
    static func launchVersion(_ metadata: [String: Any],
                              width: Int = 1280,
                              height: Int = 720) async throws {
        try bootstrap()
        #if ZL2_CORE_LINKED
        guard runtimeCheck() else {
            throw CoreLaunchError.bootstrapFailed("找不到内置 JRE（java_runtimes/java-17-openjdk/lib/libjli.dylib）")
        }
        // Java 版本从版本元数据读（1.8~1.16 要 Java 8，1.20.5+ 要 Java 21）
        let minJava = Self.requiredJavaVersion(metadata)
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
    static func currentUsername() -> String {
        if let name = UserDefaults.standard.string(forKey: "zl.currentUsername"), !name.isEmpty {
            return name
        }
        // 兜底：离线账户名
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
                    if mi >= 17 { return 17 }
                    if mi >= 12 { return 17 }
                    return 8
                }
                if ma >= 22 { return 21 }
            }
        }
        return 17
    }
}
