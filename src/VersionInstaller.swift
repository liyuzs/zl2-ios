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
                 instanceName: String = VersionRepository.shared.instanceName,
                 includeAssets: Bool = true,
                 onProgress: @Sendable @escaping (InstallProgress) -> Void) async throws {
        var failCount = 0
        var failedLibs: [String] = []

        // 全局进度：把各阶段内部进度折算成 0~100，避免进度条来回跳
        func report(_ phase: InstallProgress.Phase, _ frac: Double, _ msg: String) {
            let lo: Double, hi: Double
            switch phase {
            case .metadata:  (lo, hi) = (0.00, 0.05)
            case .jar:       (lo, hi) = (0.05, 0.20)
            case .libraries: (lo, hi) = (0.20, 0.70)
            case .assets:    (lo, hi) = (0.70, 1.00)
            default:         (lo, hi) = (0.00, 1.00)
            }
            let overall = lo + (hi - lo) * min(max(frac, 0), 1)
            onProgress(.init(phase: phase, completed: Int(overall * 100),
                             total: 100, message: msg))
        }
        let mcDir = Self.instanceDir(instanceName).appendingPathComponent(".minecraft", isDirectory: true)
        let versionDir = mcDir.appendingPathComponent("versions/\(versionID)", isDirectory: true)
        try fm.createDirectory(at: versionDir, withIntermediateDirectories: true)

        report(.metadata, 0, "获取 \(versionID) 元数据")

        // 1) 版本详情 JSON
        let api = MojangAPI()
        let manifest = try await api.fetchManifest()
        guard let entry = manifest.version(withID: versionID) else {
            throw InstallError.badMetadata
        }
        let detail = try await api.fetchVersionDetail(from: entry.url)
        report(.metadata, Double(1) / Double(max(1, 1)), "元数据就绪")

        // 保存版本 JSON：必须保存**原始完整 JSON**（含 arguments / javaVersion / logging /
        // libraries.rules / downloads.sha1），Amethyst 靠这些字段拼 JVM 和游戏参数。
        // 自己重组会丢字段，导致启动必失败。
        let jsonPath = versionDir.appendingPathComponent("\(versionID).json")
        do {
            let raw = try await downloadData(entry.url)
            // 校验是合法 JSON 再落盘
            if let o = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
               o["id"] as? String != nil, o["mainClass"] as? String != nil {
                try raw.write(to: jsonPath)
            } else {
                throw InstallError.badMetadata
            }
        } catch {
            // 兜底：用重组版（字段不全，但至少能起来排查）
            let jsonData = try JSONSerialization.data(withJSONObject: versionJSONObject(entry: entry, detail: detail),
                                                      options: [.prettyPrinted])
            try jsonData.write(to: jsonPath)
        }

        // 2) client.jar
        guard let clientURL = detail.downloads?.client?.url else {
            throw InstallError.noDownloads
        }
        let jarPath = versionDir.appendingPathComponent("\(versionID).jar")
        let jarSize = (try? fm.attributesOfItem(atPath: jarPath.path)[.size] as? Int) ?? 0
        if !fm.fileExists(atPath: jarPath.path) || jarSize < 1024 {
            report(.jar, 0, "下载 \(versionID).jar")
            try await download(clientURL, to: jarPath)
            report(.jar, Double(1) / Double(max(1, 1)), "jar 完成")
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
            report(.libraries, 0, "依赖库 \(total) 个")
            for (src, dst) in tasks {
                try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                do {
                    try await download(src, to: dst)
                } catch {
                    failCount += 1
                    failedLibs.append(src.lastPathComponent)
                }
                done += 1
                if done % 3 == 0 || done == total {
                    report(.libraries, Double(done) / Double(max(total, 1)), "依赖库 \(done)/\(total)")
                }
            }
        }

        // 4) assets
        if includeAssets, let assetIndex = detail.assetIndex, let idxURL = assetIndex.url {
            report(.assets, Double(0) / Double(max(1, 1)), "获取资源索引")
            let indexPath = mcDir.appendingPathComponent("assets/indexes/\(assetIndex.id).json",
                                                         isDirectory: false)
            try fm.createDirectory(at: indexPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: indexPath.path) {
                try await download(idxURL, to: indexPath)
            }
            // 下载资源对象（objects/<前2位>/<hash>）
            if let data = try? Data(contentsOf: indexPath),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let objects = obj["objects"] as? [String: [String: Any]] {
                let objRoot = mcDir.appendingPathComponent("assets/objects", isDirectory: true)
                // 只下需要的（按 uses 判断太复杂，这里全下，已存在的跳过）
                var pending: [(String, Int)] = []
                for (_, meta) in objects {
                    guard let hash = meta["hash"] as? String,
                          let size = meta["size"] as? Int else { continue }
                    let dst = objRoot.appendingPathComponent("\(hash.prefix(2))/\(hash)")
                    if fm.fileExists(atPath: dst.path) { continue }
                    pending.append((hash, size))
                }
                if !pending.isEmpty {
                    let total = pending.count
                    var done = 0
                    var assetFail = 0
                    report(.assets, Double(0) / Double(max(total, 1)), "资源文件 \(total) 个")
                    // 并发 8 路下载
                    await withTaskGroup(of: Bool.self) { group in
                        var idx = 0
                        let concurrency = 8
                        while idx < min(concurrency, total) {
                            let (hash, _) = pending[idx]
                            group.addTask { await Self.downloadAsset(hash: hash, root: objRoot, session: self.session, fm: self.fm) }
                            idx += 1
                        }
                        while let ok = await group.next() {
                            done += 1
                            if !ok { assetFail += 1 }
                            if idx < total {
                                let (hash, _) = pending[idx]
                                group.addTask { await Self.downloadAsset(hash: hash, root: objRoot, session: self.session, fm: self.fm) }
                                idx += 1
                            }
                            if done % 20 == 0 || done == total {
                                report(.assets, Double(done) / Double(max(total, 1)), "资源文件 \(done)/\(total)")
                            }
                        }
                    }
                    if assetFail > 0 {
                        report(.assets, Double(total) / Double(max(total, 1)), "资源完成，\(assetFail) 个失败（可重试）")
                    }
                }
            }
            report(.assets, Double(1) / Double(max(1, 1)), "资源索引就绪")
        }

        if failCount > 0 {
            report(.done, Double(1) / Double(max(1, 1)), "\(versionID) 安装完成，但有 \(failCount) 个依赖库失败")
        } else {
            report(.done, 1, "\(versionID) 安装完成")
        }
    }

    /// 下载原始字节（用于版本 JSON）
    private func downloadData(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("ZL2-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw InstallError.failed("HTTP \(http.statusCode)")
        }
        return data
    }

    static func downloadAsset(hash: String, root: URL, session: URLSession, fm: FileManager) async -> Bool {
        let dst = root.appendingPathComponent("\(hash.prefix(2))/\(hash)")
        if fm.fileExists(atPath: dst.path) { return true }
        guard let url = URL(string: "https://resources.download.minecraft.net/\(hash.prefix(2))/\(hash)") else { return false }
        for _ in 0..<2 {
            do {
                let (tmp, resp) = try await session.download(from: url)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                try? fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: dst)
                try fm.moveItem(at: tmp, to: dst)
                return true
            } catch { continue }
        }
        return false
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
        obj["assetIndex"] = detail.assetIndex.map { ["id": $0.id, "url": $0.url?.absoluteString ?? ""] }
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
