// ZL2-iOS · 加载器安装（Fabric / Quilt / Forge / NeoForge）
// 参考：ZL2 的 game/addons/modloader/*
// Fabric/Quilt 用官方 meta 的 profile JSON，合并进版本目录
import Foundation

// MARK: - 加载器安装结果
struct ZLLoaderInstallResult {
    var versionID: String
    var profileJSONPath: URL
    var mainClass: String
    var libraryCount: Int
}

enum ZLLoaderInstallerError: LocalizedError {
    case badURL
    case profileFailed(String)
    case mergeFailed(String)
    case libraryFailed(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "URL 无效"
        case .profileFailed(let s): return "获取加载器配置失败：\(s)"
        case .mergeFailed(let s): return "合并版本配置失败：\(s)"
        case .libraryFailed(let s): return "下载加载器库失败：\(s)"
        }
    }
}

// MARK: - 加载器安装器
struct ZLLoaderInstaller {

    /// 安装 Fabric
    static func installFabric(gameVersion: String,
                              loaderVersion: String,
                              onProgress: @escaping @Sendable (String, Double) -> Void) async throws -> ZLLoaderInstallResult {
        // 1. 拉取 profile JSON
        onProgress("获取 Fabric 配置…", 0.1)
        guard let url = URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(gameVersion)/\(loaderVersion)/profile/json") else {
            throw ZLLoaderInstallerError.badURL
        }
        let data = try await fetch(url)
        guard var profile = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZLLoaderInstallerError.profileFailed("JSON 解析失败")
        }
        return try await finishInstall(profile: &profile,
                                       gameVersion: gameVersion,
                                       loaderName: "fabric",
                                       loaderVersion: loaderVersion,
                                       onProgress: onProgress)
    }

    /// 安装 Quilt
    static func installQuilt(gameVersion: String,
                             loaderVersion: String,
                             onProgress: @escaping @Sendable (String, Double) -> Void) async throws -> ZLLoaderInstallResult {
        onProgress("获取 Quilt 配置…", 0.1)
        guard let url = URL(string: "https://meta.quiltmc.org/v3/versions/loader/\(gameVersion)/\(loaderVersion)/profile/json") else {
            throw ZLLoaderInstallerError.badURL
        }
        let data = try await fetch(url)
        guard var profile = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZLLoaderInstallerError.profileFailed("JSON 解析失败")
        }
        return try await finishInstall(profile: &profile,
                                       gameVersion: gameVersion,
                                       loaderName: "quilt",
                                       loaderVersion: loaderVersion,
                                       onProgress: onProgress)
    }

    /// 公共收尾：生成版本目录 + 下载库
    private static func finishInstall(profile: inout [String: Any],
                                      gameVersion: String,
                                      loaderName: String,
                                      loaderVersion: String,
                                      onProgress: @escaping @Sendable (String, Double) -> Void) async throws -> ZLLoaderInstallResult {
        // 版本 id 形如 "1.20.1-fabric-0.15.11"
        let shortLoader = loaderVersion.split(separator: "+").first.map(String.init) ?? loaderVersion
        let versionID = "\(gameVersion)-\(loaderName)-\(shortLoader)"
        profile["id"] = versionID
        // 确保 inheritsFrom 指回原版
        if profile["inheritsFrom"] == nil {
            profile["inheritsFrom"] = gameVersion
        }

        let mainClass = (profile["mainClass"] as? String) ?? ""
        let libs = (profile["libraries"] as? [[String: Any]]) ?? []

        // 写版本目录
        onProgress("写入版本配置…", 0.2)
        let dir = VersionRepository.shared.versionsDir.appendingPathComponent(versionID, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonURL = dir.appendingPathComponent("\(versionID).json")
        let out = try JSONSerialization.data(withJSONObject: profile,
                                             options: [.prettyPrinted, .sortedKeys])
        try out.write(to: jsonURL)

        // 下载库
        let libRoot = VersionRepository.shared.mcRoot.appendingPathComponent("libraries", isDirectory: true)
        var done = 0
        for lib in libs {
            guard let name = lib["name"] as? String else { continue }
            guard let artifact = (lib["downloads"] as? [String: Any])?["artifact"] as? [String: Any],
                  let path = artifact["path"] as? String,
                  let urlStr = artifact["url"] as? String,
                  let url = URL(string: urlStr) else {
                // 没有 downloads 段的（Quilt 常见），按 maven 规则拼路径
                if let maven = lib["url"] as? String,
                   let u = URL(string: maven + "/" + mavenPath(name)) {
                    let dest = libRoot.appendingPathComponent(mavenPath(name))
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                                 withIntermediateDirectories: true)
                        if let d = try? await fetch(u) {
                            try? d.write(to: dest)
                        }
                    }
                }
                continue
            }
            let dest = libRoot.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: dest.path) {
                done += 1
                continue
            }
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            do {
                let d = try await fetch(url)
                try d.write(to: dest)
            } catch {
                // 单个库失败不中断
            }
            done += 1
            let p = 0.2 + 0.75 * Double(done) / Double(max(libs.count, 1))
            onProgress("下载加载器库 \(done)/\(libs.count)", p)
        }

        onProgress("安装完成", 1.0)
        return ZLLoaderInstallResult(versionID: versionID,
                                     profileJSONPath: jsonURL,
                                     mainClass: mainClass,
                                     libraryCount: libs.count)
    }

    /// maven 坐标 → 路径：group:artifact:version → group/path/artifact/version/artifact-version.jar
    static func mavenPath(_ name: String) -> String {
        let parts = name.split(separator: ":")
        guard parts.count >= 3 else { return name }
        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]
        let version = parts[2]
        let classifier = parts.count > 3 ? parts[3] : ""
        let ext = parts.count > 4 ? parts[4] : "jar"
        let suffix = classifier.isEmpty ? "" : "-\(classifier)"
        return "\(group)/\(artifact)/\(version)/\(artifact)-\(version)\(suffix).\(ext)"
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw ZLLoaderInstallerError.profileFailed("HTTP \(http.statusCode)")
        }
        return data
    }
}
