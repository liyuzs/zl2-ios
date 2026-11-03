// ZL2-iOS · 版本安装器
// 负责：拉版本 JSON → 下载 client.jar / libraries → 落盘到 Amethyst 约定的目录
// 目录结构（对齐 Amethyst AME_HOME）：
//   <AME_HOME>/instances/<name>/.minecraft/versions/<id>/<id>.json
//   <AME_HOME>/instances/<name>/.minecraft/versions/<id>/<id>.jar
//   <AME_HOME>/instances/<name>/.minecraft/libraries/...
import Foundation

// MARK: - 安装进度
struct InstallProgress: Sendable {
    enum Phase: String, Sendable {
        case preparing = "准备中"
        case metadata  = "获取版本信息"
        case jar       = "下载核心 jar"
        case libraries = "下载依赖库"
        case assets    = "下载资源文件"
        case done      = "安装完成"
        case failed    = "安装失败"
    }
    var phase: Phase
    var completed: Int
    var total: Int
    var message: String

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(completed) / Double(total))
    }
}

enum InstallError: LocalizedError {
    case badMetadata
    case noDownloads
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .badMetadata: return "版本元数据解析失败"
        case .noDownloads: return "该版本没有可用的下载链接"
        case .failed(let m): return m
        }
    }
}

// MARK: - 安装器
actor VersionInstaller {
    private let session: URLSession
    private let fm = FileManager.default

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: cfg)
    }

    /// 根目录：<Documents>/instances/<instanceName>
    static func instanceDir(_ name: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("instances/\(name)", isDirectory: true)
    }

    /// 安装一个版本
    func install(versionID: String,
                 instanceName: String = "default",
                 includeAssets: Bool = true,
                 onProgress: @Sendable @escaping (InstallProgress) -> Void) async throws {
        let mcDir = Self.instanceDir(instanceName).appendingPathComponent(".minecraft", isDirectory: true)
        let versionDir = mcDir.appendingPathComponent("versions/\(versionID)", isDirectory: true)
        try fm.createDirectory(at: versionDir, withIntermediateDirectories: true)

        onProgress(.init(phase: .metadata, completed: 0, total: 1, message: "获取 \(versionID) 元数据"))

        // 1) 版本详情 JSON
        let api = MojangAPI()
        let manifest = try await api.fetchManifest()
        guard let entry = manifest.version(withID: versionID) else {
            throw InstallError.badMetadata
        }
        let detail = try await api.fetchVersionDetail(from: entry.url)
        onProgress(.init(phase: .metadata, completed: 1, total: 1, message: "元数据就绪"))

        // 保存版本 JSON（Amethyst 需要读它）
        let jsonData = try JSONSerialization.data(withJSONObject: versionJSONObject(entry: entry, detail: detail),
                                                  options: [.prettyPrinted])
        try jsonData.write(to: versionDir.appendingPathComponent("\(versionID).json"))

        // 2) client.jar
        guard let clientURL = detail.downloads?.client?.url else {
            throw InstallError.noDownloads
        }
        let jarPath = versionDir.appendingPathComponent("\(versionID).jar")
        if !fm.fileExists(atPath: jarPath.path) {
            onProgress(.init(phase: .jar, completed: 0, total: 1, message: "下载 \(versionID).jar"))
            try await download(clientURL, to: jarPath)
            onProgress(.init(phase: .jar, completed: 1, total: 1, message: "jar 完成"))
        }

        // 3) libraries
        let libs = detail.libraries ?? []
        let libRoot = mcDir.appendingPathComponent("libraries", isDirectory: true)
        var tasks: [(URL, URL)] = []
        for lib in libs {
            // 只下主 artifact（跳过 natives/classifiers，iOS 不吃原生库）
            guard let artifact = lib.downloads?.artifact, let path = artifact.path else { continue }
            let dest = libRoot.appendingPathComponent(path)
            if fm.fileExists(atPath: dest.path) { continue }
            tasks.append((artifact.url, dest))
        }
        if !tasks.isEmpty {
            let total = tasks.count
            var done = 0
            onProgress(.init(phase: .libraries, completed: 0, total: total, message: "依赖库 \(total) 个"))
            for (src, dst) in tasks {
                try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                do { try await download(src, to: dst) } catch { /* 单个失败不阻断 */ }
                done += 1
                if done % 3 == 0 || done == total {
                    onProgress(.init(phase: .libraries, completed: done, total: total, message: "依赖库 \(done)/\(total)"))
                }
            }
        }

        // 4) assets
        if includeAssets, let assetIndex = detail.assetIndex, let idxURL = assetIndex.url {
            onProgress(.init(phase: .assets, completed: 0, total: 1, message: "获取资源索引"))
            let indexPath = mcDir.appendingPathComponent("assets/indexes/\(assetIndex.id).json",
                                                         isDirectory: false)
            try fm.createDirectory(at: indexPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: indexPath.path) {
                try await download(idxURL, to: indexPath)
            }
            // 资源对象数量很大（几千个），这里只下载索引，对象在首次启动时按需拉取
            onProgress(.init(phase: .assets, completed: 1, total: 1, message: "资源索引就绪"))
        }

        onProgress(.init(phase: .done, completed: 1, total: 1, message: "\(versionID) 安装完成"))
    }

    // MARK: 下载单文件（带重试）
    private func download(_ url: URL, to dest: URL) async throws {
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (tmp, resp) = try await session.download(from: url)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw InstallError.failed("HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)")
                }
                try? fm.removeItem(at: dest)
                try fm.moveItem(at: tmp, to: dest)
                return
            } catch {
                lastError = error
                if attempt < 3 { try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) }
            }
        }
        throw InstallError.failed(lastError?.localizedDescription ?? "下载失败：\(url.lastPathComponent)")
    }

    // MARK: 构造 Amethyst 可读的版本 JSON
    private func versionJSONObject(entry: ManifestVersionEntry, detail: VersionDetail) -> [String: Any] {
        var obj: [String: Any] = [
            "id": entry.id,
            "type": entry.isRelease ? "release" : (entry.isSnapshot ? "snapshot" : "old_beta"),
        ]
        if let d = detail.downloads?.client?.url { obj["clientUrl"] = d.absoluteString }
        // 尽量保留原始 JSON 里的关键字段
        obj["mainClass"] = detail.mainClass
        obj["assetIndex"] = detail.assetIndex.map { ["id": $0.id, "url": $0.url.absoluteString] }
        obj["libraries"] = detail.libraries?.map { lib -> [String: Any] in
            var o: [String: Any] = ["name": lib.name]
            if let a = lib.downloads?.artifact {
                o["downloads"] = ["artifact": ["path": a.path ?? "", "url": a.url.absoluteString]]
            }
            return o
        }
        return obj
    }
}
