// ZL2-iOS · Modrinth 资源 API
// 文档：https://docs.modrinth.com/api/operations/searchprojects/
import Foundation

// MARK: - 项目类型
enum ModrinthProjectType: String {
    case mod = "mod"
    case modpack = "modpack"
    case resourcepack = "resourcepack"
    case shader = "shader"
    case datapack = "datapack"

    static func from(_ kind: AssetKind) -> ModrinthProjectType? {
        switch kind {
        case .mod: return .mod
        case .modpack: return .modpack
        case .resource: return .resourcepack
        case .shader: return .shader
        default: return nil
        }
    }
}

// MARK: - 搜索结果
struct ModrinthHit: Identifiable, Sendable {
    let id: String
    let slug: String
    let title: String
    let description: String
    let author: String
    let downloads: Int
    let follows: Int
    let iconURL: URL?
    let categories: [String]
    let versions: [String]
    let projectType: String
    let dateModified: String
}

struct ModrinthSearchResult: Sendable {
    let hits: [ModrinthHit]
    let totalHits: Int
    let offset: Int
    let limit: Int
}

// MARK: - 版本文件
struct ModrinthVersionFile: Sendable {
    let url: URL
    let filename: String
    let size: Int
    let primary: Bool
}

struct ModrinthVersion: Sendable {
    let id: String
    let versionNumber: String
    let gameVersions: [String]
    let loaders: [String]
    let files: [ModrinthVersionFile]
    let dependencies: [String]     // 前置项目 ID
}

enum ModrinthError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的搜索请求"
        case .badResponse(let c): return "Modrinth 返回 \(c)"
        case .decode(let m): return "解析失败：\(m)"
        }
    }
}

// MARK: - 服务
actor ModrinthAPI {
    static let shared = ModrinthAPI()
    private let base = "https://api.modrinth.com/v2"
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.httpAdditionalHeaders = [
            "User-Agent": "ZL2-iOS/1.0 (Minecraft launcher; iOS)",
            "Accept": "application/json",
        ]
        session = URLSession(configuration: cfg)
    }

    /// 搜索项目
    func search(query: String,
                type: ModrinthProjectType?,
                gameVersion: String? = nil,
                loader: String? = nil,
                categories: [String] = [],
                sortIndex: String = "relevance",
                offset: Int = 0,
                limit: Int = 20) async throws -> ModrinthSearchResult {
        var facets: [[String]] = []
        if let type { facets.append(["project_type:\(type.rawValue)"]) }
        if let gameVersion, !gameVersion.isEmpty {
            facets.append(["versions:\(gameVersion)"])
        }
        if let loader, !loader.isEmpty {
            facets.append(["categories:\(loader.lowercased())"])
        }
        if !categories.isEmpty {
            facets.append(categories.map { "categories:\($0)" })
        }

        var comps = URLComponents(string: "\(base)/search")!
        var items: [URLQueryItem] = [
            .init(name: "query", value: query),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
            .init(name: "index", value: sortIndex),
        ]
        if !facets.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: facets),
           let s = String(data: data, encoding: .utf8) {
            items.append(.init(name: "facets", value: s))
        }
        comps.queryItems = items
        guard let url = comps.url else { throw ModrinthError.invalidURL }

        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw ModrinthError.badResponse(0) }
        guard http.statusCode == 200 else { throw ModrinthError.badResponse(http.statusCode) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ModrinthError.decode("非 JSON")
        }
        let hits = (json["hits"] as? [[String: Any]] ?? []).compactMap { h -> ModrinthHit? in
            guard let id = h["project_id"] as? String,
                  let title = h["title"] as? String else { return nil }
            return ModrinthHit(
                id: id,
                slug: h["slug"] as? String ?? id,
                title: title,
                description: h["description"] as? String ?? "",
                author: h["author"] as? String ?? "",
                downloads: h["downloads"] as? Int ?? 0,
                follows: h["follows"] as? Int ?? 0,
                iconURL: (h["icon_url"] as? String).flatMap(URL.init(string:)),
                categories: h["categories"] as? [String] ?? [],
                versions: h["versions"] as? [String] ?? [],
                projectType: h["project_type"] as? String ?? "",
                dateModified: h["date_modified"] as? String ?? ""
            )
        }
        return ModrinthSearchResult(hits: hits,
                                    totalHits: json["total_hits"] as? Int ?? hits.count,
                                    offset: json["offset"] as? Int ?? offset,
                                    limit: json["limit"] as? Int ?? limit)
    }

    /// 拉取一个项目的版本列表
    func versions(projectID: String,
                  gameVersion: String? = nil,
                  loader: String? = nil) async throws -> [ModrinthVersion] {
        var comps = URLComponents(string: "\(base)/project/\(projectID)/version")!
        var qs: [URLQueryItem] = []
        if let g = gameVersion, !g.isEmpty,
           let d = try? JSONSerialization.data(withJSONObject: ["game_versions": [g]]),
           let s = String(data: d, encoding: .utf8) {
            qs.append(.init(name: "game_versions", value: s))
        }
        if let l = loader, !l.isEmpty,
           let d = try? JSONSerialization.data(withJSONObject: [l.lowercased()]),
           let s = String(data: d, encoding: .utf8) {
            qs.append(.init(name: "loaders", value: s))
        }
        if !qs.isEmpty { comps.queryItems = qs }
        guard let url = comps.url else { throw ModrinthError.invalidURL }

        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ModrinthError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ModrinthError.decode("版本列表非数组")
        }
        return arr.compactMap { v -> ModrinthVersion? in
            guard let vid = v["id"] as? String else { return nil }
            let files = (v["files"] as? [[String: Any]] ?? []).compactMap { f -> ModrinthVersionFile? in
                guard let u = f["url"] as? String, let url = URL(string: u) else { return nil }
                return ModrinthVersionFile(url: url,
                                           filename: f["filename"] as? String ?? url.lastPathComponent,
                                           size: f["size"] as? Int ?? 0,
                                           primary: f["primary"] as? Bool ?? false)
            }
            let deps = (v["dependencies"] as? [[String: Any]] ?? [])
                .compactMap { $0["project_id"] as? String }
            return ModrinthVersion(id: vid,
                                   versionNumber: v["version_number"] as? String ?? "",
                                   gameVersions: v["game_versions"] as? [String] ?? [],
                                   loaders: v["loaders"] as? [String] ?? [],
                                   files: files,
                                   dependencies: deps)
        }
    }

    /// 下载文件到指定目录
    func download(_ file: ModrinthVersionFile, to dir: URL, onProgress: ((Double) -> Void)? = nil) async throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(file.filename)
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        let (tmp, resp) = try await session.download(from: file.url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ModrinthError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        onProgress?(1.0)
        return dest
    }
}

// MARK: - 项目详情（资源详情页用）

struct ModrinthGalleryImage: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let title: String?
    let featured: Bool
}

struct ModrinthProject: Sendable {
    let id: String
    let slug: String
    let title: String
    let description: String
    let body: String
    let iconURL: URL?
    let downloads: Int
    let followers: Int
    let categories: [String]
    let gameVersions: [String]
    let loaders: [String]
    let sourceURL: URL?
    let issuesURL: URL?
    let wikiURL: URL?
    let licenseName: String?
    let licenseURL: URL?
    let gallery: [ModrinthGalleryImage]
    let updated: String
}

extension ModrinthAPI {
    /// 拉取项目详情：GET /v2/project/{id|slug}
    func project(idOrSlug: String) async throws -> ModrinthProject {
        guard let url = URL(string: "\(base)/project/\(idOrSlug)") else {
            throw ModrinthError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ModrinthError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ModrinthError.decode("项目详情不是 JSON 对象")
        }

        let gallery = (json["gallery"] as? [[String: Any]] ?? []).compactMap { g -> ModrinthGalleryImage? in
            guard let u = g["url"] as? String, let url = URL(string: u) else { return nil }
            return ModrinthGalleryImage(url: url,
                                        title: g["title"] as? String,
                                        featured: g["featured"] as? Bool ?? false)
        }
        let license = json["license"] as? [String: Any]
        return ModrinthProject(
            id: json["id"] as? String ?? idOrSlug,
            slug: json["slug"] as? String ?? idOrSlug,
            title: json["title"] as? String ?? "未命名项目",
            description: json["description"] as? String ?? "",
            body: json["body"] as? String ?? "",
            iconURL: (json["icon_url"] as? String).flatMap(URL.init(string:)),
            downloads: json["downloads"] as? Int ?? 0,
            followers: json["followers"] as? Int ?? 0,
            categories: json["categories"] as? [String] ?? [],
            gameVersions: json["game_versions"] as? [String] ?? [],
            loaders: json["loaders"] as? [String] ?? [],
            sourceURL: (json["source_url"] as? String).flatMap(URL.init(string:)),
            issuesURL: (json["issues_url"] as? String).flatMap(URL.init(string:)),
            wikiURL: (json["wiki_url"] as? String).flatMap(URL.init(string:)),
            licenseName: license?["name"] as? String,
            licenseURL: (license?["url"] as? String).flatMap(URL.init(string:)),
            gallery: gallery,
            updated: json["updated"] as? String ?? ""
        )
    }
}
