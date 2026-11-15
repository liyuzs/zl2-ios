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
    /// 下载失败的库（URL 最后一段）。**不为空说明这个加载器很可能起不来** ——
    /// 原来单个库失败被空 catch 吞掉，结果里还报"已安装 N 个库"（第149轮）。
    var failedLibs: [String] = []
}

enum ZLLoaderInstallerError: LocalizedError {
    case badURL
    /// 下载到的内容不是合法的 jar/zip（第150轮加：服务器可能返回网页错误页）
    case badContent(String)
    case profileFailed(String)
    // 第175轮删掉两个死 case：`mergeFailed` / `libraryFailed` —— 从未被抛出。
    // · "合并"实际走 `try JSONSerialization.data` + `out.write(to:)`（系统错误）
    // · "库下载失败"走 `failedLibs` 收集（第149轮设计：不中断，最后一起报）
    // 留着它们会让人以为"库下载失败会抛错"，而实际不会。

    var errorDescription: String? {
        switch self {
        case .badURL: return "URL 无效"
        case .badContent(let s): return "下载到的不是 jar（可能是网页错误页）：\(s)"
        case .profileFailed(let s): return "获取加载器配置失败：\(s)"

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
        // versionID 会直接变成目录名和 JSON 文件名。它由「游戏版本 + 加载器版本」拼成，
        // 后两段来自远端元数据 —— 里面若出现 `/` 或 `..`，文件就会落到 versions/ 之外。
        if let why = ZLPathSafety.validateNewName(versionID, kind: "版本 ID") {
            throw ZLLoaderInstallerError.profileFailed(why)
        }
        let dir = VersionRepository.shared.versionsDir.appendingPathComponent(versionID, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonURL = dir.appendingPathComponent("\(versionID).json")
        let out = try JSONSerialization.data(withJSONObject: profile,
                                             options: [.prettyPrinted, .sortedKeys])
        try out.write(to: jsonURL, options: .atomic)

        // 下载库
        let libRoot = VersionRepository.shared.mcRoot.appendingPathComponent("libraries", isDirectory: true)
        var done = 0
        var failedLibs: [String] = []
        for lib in libs {
            guard let name = lib["name"] as? String else { continue }
            guard let artifact = (lib["downloads"] as? [String: Any])?["artifact"] as? [String: Any],
                  let path = artifact["path"] as? String,
                  let urlStr = artifact["url"] as? String,
                  let url = URL(string: urlStr) else {
                // 没有 downloads 段的（Quilt 常见），按 maven 规则拼路径
                if let maven = lib["url"] as? String,
                   let u = URL(string: maven + "/" + mavenPath(name)) {
                    // mavenPath 由 group:artifact:version 拼出，本身就是单层安全的；
                    // 仍过一遍校验，避免 group 里混进奇怪字符（远端元数据可控）。
                    let mavenRel = ZLPathSafety.safeRelativePath(mavenPath(name))
                    let dest = libRoot.appendingPathComponent(mavenRel ?? ZLPathSafety.safeComponent(mavenPath(name)))
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                                 withIntermediateDirectories: true)
                        if let d = try? await fetch(u) {
                            // **第179轮**：写失败会让库文件不存在，但 `failedLibs` 只记"下载失败"不记"写失败"，
                            // 于是后面报"缺库"时那个列表是空的 —— 误导排查。改成失败记下来。
                            do {
                                try d.write(to: dest, options: .atomic)
                            } catch {
                                failedLibs.append(u.lastPathComponent + "（写盘失败）")   // 第258轮：原来写 url，不在作用域
                            }
                        }
                    }
                }
                continue
            }
            // path 来自加载器元数据（远端）。不合法就跳过这个库。
            guard let safeRel = ZLPathSafety.safeRelativePath(path) else { continue }
            let dest = libRoot.appendingPathComponent(safeRel)
            if FileManager.default.fileExists(atPath: dest.path) {
                done += 1
                continue
            }
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            do {
                let d = try await fetch(url)
                // **ZIP/JAR 魔数（PK = 0x50 0x4B）**（第150轮补）：
                // 与 VersionInstaller / ModrinthAPI 的校验一致。没有它的话，
                // 服务器返回的网页错误页会被存成 .jar，且 failedLibs 不会记 ——
                // 用户看到"安装完成"，启动时 ClassNotFoundException。
                guard d.count >= 2, d[0] == 0x50, d[1] == 0x4B else {
                    throw ZLLoaderInstallerError.badContent(url.lastPathComponent)
                }
                try d.write(to: dest, options: .atomic)
            } catch {
                // 单个库失败不中断，但**要记下来** —— 缺库的加载器启动会崩
                failedLibs.append(url.lastPathComponent)
            }
            done += 1
            let p = 0.2 + 0.75 * Double(done) / Double(max(libs.count, 1))
            onProgress("下载加载器库 \(done)/\(libs.count)", p)
        }

        if failedLibs.isEmpty {
            onProgress("安装完成", 1.0)
        } else {
            onProgress("安装完成，但 \(failedLibs.count) 个库下载失败（这个加载器可能起不来）", 1.0)
        }
        return ZLLoaderInstallResult(versionID: versionID,
                                     profileJSONPath: jsonURL,
                                     mainClass: mainClass,
                                     libraryCount: libs.count,
                                     failedLibs: failedLibs)
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
