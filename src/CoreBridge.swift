// ZL2-iOS · 启动核心桥接
// 把 Amethyst 的 launchJVM(C) 包成 Swift 可用的异步接口
import Foundation

/// 启动失败原因
enum CoreLaunchError: LocalizedError {
    case coreNotLinked
    case launchReturned(Int32)
    case missingRuntime

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "启动核心尚未链接进 App（当前构建未启用 Amethyst 核心）"
        case .launchReturned(let code):
            return "launchJVM 返回错误码 \(code)"
        case .missingRuntime:
            return "缺少 Java 运行时（java_runtimes）"
        }
    }
}

enum CoreBridge {
    /// 当前构建是否带核心。链接成功后由 CI 注入 -DZL2_CORE_LINKED
    static var isCoreLinked: Bool {
        #if ZL2_CORE_LINKED
        return true
        #else
        return false
        #endif
    }

    /// 用 jar 路径直接启动（Amethyst 的最小验证路径）
    static func launchJar(_ jarPath: String,
                          width: Int = 1280,
                          height: Int = 720) async throws {
        guard isCoreLinked else { throw CoreLaunchError.coreNotLinked }
        let code = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = launchJVM(nil, jarPath as NSString, Int32(width), Int32(height), 8)
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
    }

    /// 用版本元数据启动（后续接 MojangAPI 的 VersionDetail）
    static func launchVersion(_ metadata: [String: Any],
                              width: Int = 1280,
                              height: Int = 720) async throws {
        guard isCoreLinked else { throw CoreLaunchError.coreNotLinked }
        let code = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = launchJVM(nil, metadata as NSDictionary, Int32(width), Int32(height), 8)
                cont.resume(returning: r)
            }
        }
        if code != 0 { throw CoreLaunchError.launchReturned(code) }
    }
}
