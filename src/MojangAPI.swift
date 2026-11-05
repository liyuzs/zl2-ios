//
//  MojangAPI.swift
//  ZL2-iOS
//
//  Minecraft Java 版的 Mojang 官方元数据网络层：
//    1. 版本清单（version manifest）：正式版 / 快照列表
//    2. 版本详情（version detail）：mainClass、assets、libraries、downloads …
//    3. 单文件下载（带进度回调，临时文件 + 原子替换）
//
//  数据源（只读、匿名、无需鉴权）：
//    https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
//
//  约束：
//    - iOS 16+ / Swift 5.9，只依赖 Foundation（URLSession / Codable / FileManager）
//    - 全程 async/await，没有回调嵌套
//    - 本文件自包含：不引用本工程其他文件里定义的类型
//    - 所有类型都是 Codable，字段用 CodingKeys 显式映射
//      （Mojang 的键是 camelCase，个别带下划线 / 短横线，
//        如 client_mappings、default-user-jvm、minecraftArguments）
//

import Foundation

// MARK: - 错误

/// Mojang API 层可能抛出的全部错误，按「网络 / 解码 / HTTP 状态 / 本地 IO」分类。
public enum MojangAPIError: LocalizedError {

    /// URL 非法（空串、缺少 scheme、不是 http(s)、不是 file URL 等）。
    case invalidURL(String)
    /// 网络层错误：连不上、超时、TLS 失败等（原始错误包在里面）。
    case network(Error)
    /// 服务器返回了非 2xx 的 HTTP 状态码。
    case httpStatus(Int)
    /// JSON 解码失败（字段缺失、类型不匹配、日期格式不认识等）。
    case decoding(Error)
    /// 版本清单里找不到这个版本 id。
    case versionNotFound(String)
    /// 本地文件读写失败（建目录、写临时文件、原子替换等）。
    case fileIO(Error)
    /// 任务被取消（`URLError.cancelled` / `CancellationError`）。
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let string):
            return "无效的 URL：\(string)"
        case .network(let error):
            return "网络请求失败：\(error.localizedDescription)"
        case .httpStatus(let statusCode):
            return "服务器返回 HTTP \(statusCode)"
        case .decoding(let error):
            return "JSON 解析失败：\(error.localizedDescription)"
        case .versionNotFound(let id):
            return "版本清单中找不到版本：\(id)"
        case .fileIO(let error):
            return "文件写入失败：\(error.localizedDescription)"
        case .cancelled:
            return "请求已取消"
        }
    }
}

// MARK: - 版本类型

/// Mojang 的 `type` 字段：正式版 / 快照 / 远古 beta / 远古 alpha。
///
/// 用带 `unknown` 的枚举而不是裸 `String`，既能直接 `== .release` 判断，
/// 又不会因为 Mojang 将来加新类型而让整份清单解码失败。
public enum VersionType: Codable, Hashable, Sendable {

    case release
    case snapshot
    case oldBeta
    case oldAlpha
    /// 未知类型，原样保留，避免解码失败。
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "release":
            self = .release
        case "snapshot":
            self = .snapshot
        case "old_beta":
            self = .oldBeta
        case "old_alpha":
            self = .oldAlpha
        default:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .release:
            return "release"
        case .snapshot:
            return "snapshot"
        case .oldBeta:
            return "old_beta"
        case .oldAlpha:
            return "old_alpha"
        case .unknown(let rawValue):
            return rawValue
        }
    }

    /// 是否正式版（type == "release"）。
    public var isRelease: Bool { self == .release }
    /// 是否快照（包含 pre-release / rc）。
    public var isSnapshot: Bool { self == .snapshot }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - 版本清单 version_manifest_v2.json

/// `latest` 节点：当前最新的正式版 id 与最新快照 id。
public struct LatestVersions: Codable, Hashable, Sendable {

    /// 最新正式版的版本 id（如 "26.3"）。
    public let release: String
    /// 最新快照的版本 id（如 "26.4-snapshot-6"）。
    public let snapshot: String

    public enum CodingKeys: String, CodingKey {
        case release
        case snapshot
    }
}

/// 清单里的一条版本记录。
public struct ManifestVersionEntry: Codable, Identifiable, Hashable, Sendable {

    /// 版本 id，如 "1.21.10"、"26.4-snapshot-6"。
    public let id: String
    public let type: VersionType
    /// 该版本的 version detail JSON 地址（下载详情时用它）。
    public let url: URL
    /// Mojang 侧的更新时间。
    public let time: Date?
    /// 正式发布时间。远古条目个别可能缺失，所以是可选的。
    public let releaseTime: Date?
    /// 版本 JSON 的 SHA-1（可用于校验，本文件不做校验逻辑）。
    public let sha1: String?
    /// Mojang 的合规级别（新版本为 1，老版本为 0）。
    public let complianceLevel: Int?

    public enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case time
        case releaseTime
        case sha1
        case complianceLevel
    }

    public var isRelease: Bool { self.type == .release }
    public var isSnapshot: Bool { self.type == .snapshot }

    /// 优先用 releaseTime，缺失时退回 time。
    public var publishDate: Date? { self.releaseTime ?? self.time }
}

/// 版本清单根对象。
public struct VersionManifest: Codable, Hashable, Sendable {

    public let latest: LatestVersions
    public let versions: [ManifestVersionEntry]

    public enum CodingKeys: String, CodingKey {
        case latest
        case versions
    }
}

public extension VersionManifest {

    /// 只保留正式版，保持清单原有顺序（新 → 旧）。
    var releases: [ManifestVersionEntry] { self.versions.filter { $0.type == .release } }

    /// 只保留快照（含 pre-release / rc），保持清单原有顺序（新 → 旧）。
    var snapshots: [ManifestVersionEntry] { self.versions.filter { $0.type == .snapshot } }

    /// `latest.release` 对应的那条记录。
    var latestRelease: ManifestVersionEntry? { self.version(withID: self.latest.release) }

    /// `latest.snapshot` 对应的那条记录。
    var latestSnapshot: ManifestVersionEntry? { self.version(withID: self.latest.snapshot) }

    /// 按版本 id 查记录。
    func version(withID id: String) -> ManifestVersionEntry? {
        self.versions.first { $0.id == id }
    }
}

// MARK: - 版本详情 <version>.json

/// 某个版本完整的 version JSON。
///
/// 只强制要求 `id` / `type` / `mainClass`，其余字段在老版本里可能缺失，
/// 所以都是可选的；常用的取值提供了非可选的便利访问器。
public struct VersionDetail: Codable, Identifiable, Hashable, Sendable {

    public let id: String
    public let type: VersionType
    /// 主类，如 "net.minecraft.client.main.Main"。
    public let mainClass: String
    /// 资源版本号（如 "34"）。
    public let assets: String?
    public let assetIndex: AssetIndex?
    public let downloads: Downloads?
    public let libraries: [Library]?
    public let javaVersion: JavaVersion?
    public let minimumLauncherVersion: Int?
    public let complianceLevel: Int?
    public let releaseTime: Date?
    public let time: Date?
    public let logging: Logging?
    /// 1.13+ 的结构化启动参数。
    public let arguments: Arguments?
    /// 1.13 以前拼接好的启动参数字符串（用空格分隔）。
    public let minecraftArguments: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case type
        case mainClass
        case assets
        case assetIndex
        case downloads
        case libraries
        case javaVersion
        case minimumLauncherVersion
        case complianceLevel
        case releaseTime
        case time
        case logging
        case arguments
        case minecraftArguments
    }

    // MARK: 资源索引

    /// `assetIndex`：资源索引文件的元数据。
    public struct AssetIndex: Codable, Hashable, Sendable {

        public let id: String
        public let sha1: String?
        public let size: Int?
        public let totalSize: Int?
        public let url: URL?

        public enum CodingKeys: String, CodingKey {
            case id
            case sha1
            case size
            case totalSize
            case url
        }
    }

    // MARK: 下载

    /// 版本级下载项（客户端 jar / 服务端 jar / 混淆映射）。
    public struct Downloads: Codable, Hashable, Sendable {

        public let client: Artifact?
        public let server: Artifact?
        public let clientMappings: Artifact?
        public let serverMappings: Artifact?

        public enum CodingKeys: String, CodingKey {
            case client
            case server
            case clientMappings = "client_mappings"
            case serverMappings = "server_mappings"
        }
    }

    /// 一个可下载文件：sha1 + 大小 + URL（库文件另有仓库内的相对路径）。
    public struct Artifact: Codable, Hashable, Sendable {

        public let sha1: String?
        public let size: Int?
        public let url: URL
        public let path: String?

        public enum CodingKeys: String, CodingKey {
            case sha1
            case size
            case url
            case path
        }

        /// 落到磁盘时用的相对路径；老 JSON 没有 path 时退回 URL 的最后一段。
        public var relativePath: String {
            if let path = self.path, !path.isEmpty { return path }
            return self.url.lastPathComponent
        }
    }

    // MARK: 依赖库

    /// `libraries[]` 的一项。
    public struct Library: Codable, Hashable, Sendable {

        /// Maven 坐标，如 "com.mojang:brigadier:1.3.11"。
        public let name: String
        public let downloads: LibraryDownloads?
        /// 平台规则，决定这个库在当前系统上要不要下载。
        public let rules: [Rule]?
        /// 老版本（1.19 以前）的原生库映射，如 ["windows": "natives-windows"]。
        public let natives: [String: String]?
        /// 解压时的排除规则。
        public let extract: Extract?

        public enum CodingKeys: String, CodingKey {
            case name
            case downloads
            case rules
            case natives
            case extract
        }

        /// 主 artifact（classpath 上那个 jar）。
        public var artifact: Artifact? { self.downloads?.artifact }

        /// 按 Mojang 的规则语义判断当前平台是否需要这个库：
        /// 没有 rules 视为允许；否则按顺序求值，最后一条命中的规则决定结果。
        public func isAllowed(osName: String?,
                              arch: String?,
                              features: [String: Bool] = [:]) -> Bool {
            guard let rules = self.rules, !rules.isEmpty else { return true }
            var allowed = false
            for rule in rules where rule.matches(osName: osName, arch: arch, features: features) {
                allowed = rule.action.isAllow
            }
            return allowed
        }

        /// 用 `MojangAPI.Platform` 的当前平台信息判断（iOS 默认按 "linux" 处理）。
        public func isAllowedForCurrentPlatform(features: [String: Bool] = [:]) -> Bool {
            self.isAllowed(osName: MojangAPI.Platform.osName,
                           arch: MojangAPI.Platform.arch,
                           features: features)
        }
    }

    /// 库的下载项：主 artifact + 平台分类器（natives）。
    public struct LibraryDownloads: Codable, Hashable, Sendable {

        public let artifact: Artifact?
        public let classifiers: [String: Artifact]?

        public enum CodingKeys: String, CodingKey {
            case artifact
            case classifiers
        }
    }

    /// `libraries[].extract`：解压排除规则。
    public struct Extract: Codable, Hashable, Sendable {

        public let exclude: [String]?

        public enum CodingKeys: String, CodingKey {
            case exclude
        }
    }

    // MARK: 规则

    /// rules 动作。老版本里出现的是 "disallow"（不是 "deny"），两种都兼容。
    public enum RuleAction: Codable, Hashable, Sendable {

        case allow
        case disallow
        /// 未知动作，原样保留。
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "allow":
                self = .allow
            case "disallow", "deny":
                self = .disallow
            default:
                self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .allow:
                return "allow"
            case .disallow:
                return "disallow"
            case .unknown(let rawValue):
                return rawValue
            }
        }

        public var isAllow: Bool {
            if case .allow = self { return true }
            return false
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.init(rawValue: try container.decode(String.self))
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
    }

    /// 一条规则：`{"action": "allow", "os": {"name": "osx"}}`。
    public struct Rule: Codable, Hashable, Sendable {

        public let action: RuleAction
        public let os: OSRule?
        public let features: [String: Bool]?

        public enum CodingKeys: String, CodingKey {
            case action
            case os
            case features
        }

        /// 这条规则是否命中当前环境。
        /// 只判断 os.name / os.arch / features，`versionRange`（仅 Windows 10 检测用）忽略。
        public func matches(osName: String?,
                            arch: String?,
                            features requested: [String: Bool]) -> Bool {
            if let os = self.os {
                if let expected = os.name, let current = osName, expected != current { return false }
                if let expected = os.arch, let current = arch, expected != current { return false }
            }
            if let features = self.features {
                for (key, expected) in features {
                    if (requested[key] ?? false) != expected { return false }
                }
            }
            return true
        }
    }

    /// 规则的 `os` 条件。
    public struct OSRule: Codable, Hashable, Sendable {

        public let name: String?
        public let arch: String?
        public let versionRange: VersionRange?

        public enum CodingKeys: String, CodingKey {
            case name
            case arch
            case versionRange
        }
    }

    /// 规则的 `os.versionRange` 条件。
    public struct VersionRange: Codable, Hashable, Sendable {

        public let min: String?
        public let max: String?

        public enum CodingKeys: String, CodingKey {
            case min
            case max
        }
    }

    // MARK: Java

    public struct JavaVersion: Codable, Hashable, Sendable {

        /// Java 运行时组件名，如 "java-runtime-epsilon"、"jre-legacy"。
        public let component: String?
        /// 主版本号，如 8 / 17 / 21 / 25。
        public let majorVersion: Int?

        public enum CodingKeys: String, CodingKey {
            case component
            case majorVersion
        }
    }

    // MARK: 日志配置

    public struct Logging: Codable, Hashable, Sendable {

        public let client: LogFile?

        public enum CodingKeys: String, CodingKey {
            case client
        }
    }

    /// 日志配置里的一个文件（log4j2 配置）。
    public struct LogFile: Codable, Hashable, Sendable {

        /// 启动参数模板，如 "-Dlog4j.configurationFile=${path}"。
        public let argument: String?
        public let type: String?
        public let file: Artifact?
        public let id: String?

        public enum CodingKeys: String, CodingKey {
            case argument
            case type
            case file
            case id
        }
    }

    // MARK: 启动参数（1.13+）

    public struct Arguments: Codable, Hashable, Sendable {

        public let game: [ArgumentEntry]?
        public let jvm: [ArgumentEntry]?
        /// 键在 JSON 里写作 "default-user-jvm"。
        public let defaultUserJVM: [ArgumentEntry]?

        public enum CodingKeys: String, CodingKey {
            case game
            case jvm
            case defaultUserJVM = "default-user-jvm"
        }
    }

    /// `arguments.game` / `arguments.jvm` 的一项：
    /// 可能直接是字符串 `"--username"`，也可能是带规则的对象。
    public struct ArgumentEntry: Codable, Hashable, Sendable {

        public let rules: [Rule]?
        public let value: ArgumentValue

        public enum CodingKeys: String, CodingKey {
            case rules
            case value
        }

        public init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            if let string = try? single.decode(String.self) {
                self.rules = nil
                self.value = .single(string)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.rules = try container.decodeIfPresent([Rule].self, forKey: .rules)
            self.value = try container.decode(ArgumentValue.self, forKey: .value)
        }

        public func encode(to encoder: Encoder) throws {
            if self.rules == nil, case .single(let string) = self.value {
                var single = encoder.singleValueContainer()
                try single.encode(string)
                return
            }
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.rules, forKey: .rules)
            try container.encode(self.value, forKey: .value)
        }

        /// 这条参数的字符串形式（单值 → 一个元素，数组 → 多个元素）。
        public var values: [String] { self.value.values }
    }

    /// 参数值：JSON 里可能是 `"..."`，也可能是 `["...", "..."]`。
    public enum ArgumentValue: Codable, Hashable, Sendable {

        case single(String)
        case multiple([String])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .single(string)
                return
            }
            self = .multiple(try container.decode([String].self))
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let string):
                try container.encode(string)
            case .multiple(let strings):
                try container.encode(strings)
            }
        }

        public var values: [String] {
            switch self {
            case .single(let string):
                return [string]
            case .multiple(let strings):
                return strings
            }
        }
    }
}

// MARK: - 版本详情的便利访问器

public extension VersionDetail {

    /// 依赖库列表（缺失时为空数组）。
    var libraryList: [Library] { self.libraries ?? [] }

    /// 客户端 jar。
    var clientDownload: Artifact? { self.downloads?.client }

    /// 服务端 jar。
    var serverDownload: Artifact? { self.downloads?.server }

    /// 当前平台真正需要下载、且带主 artifact 的库（已按 rules 过滤）。
    func applicableLibraries(osName: String = MojangAPI.Platform.osName,
                             arch: String = MojangAPI.Platform.arch,
                             features: [String: Bool] = [:]) -> [Library] {
        self.libraryList.filter {
            $0.artifact != nil && $0.isAllowed(osName: osName, arch: arch, features: features)
        }
    }
}

// MARK: - API

/// Mojang 元数据 API。
///
/// ```swift
/// let api = MojangAPI.shared
/// let manifest = try await api.fetchManifest()
/// let detail = try await api.fetchVersionDetail(id: manifest.latest.release)
/// ```
///
/// 所有属性都是 `let`（不可变），方法内部不共享可变状态，URLSession 本身线程安全，
/// 所以可以安全地跨 actor / Task 传递。
public struct MojangAPI: @unchecked Sendable {

    // MARK: 常量

    /// 官方版本清单地址（常量字符串，不可能为 nil）。
    public static let defaultManifestURL = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!

    /// 国内镜像（BMCLAPI）。国内用户下载会快很多。
    public static let mirrorManifestURL = URL(string: "https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json")!

    /// 按设置里的「下载源」选择，返回该用的版本清单地址。
    /// 设置项 key 是 `gameDownloadSource`（在设置页的镜像分组里）。
    public static var preferredManifestURL: URL {
        let raw = UserDefaults.standard.string(forKey: "gameDownloadSource") ?? ""
        let lower = raw.lowercased()
        // OFFICIAL 才强制走官方；AUTO（默认）和 MIRROR 都走国内镜像
        if lower.contains("official") || lower.contains("官方") {
            return defaultManifestURL
        }
        if raw.isEmpty { return defaultManifestURL }
        return mirrorManifestURL
    }

    /// 是否启用了国内镜像
    public static var mirrorEnabled: Bool {
        let raw = (UserDefaults.standard.string(forKey: "gameDownloadSource") ?? "").lowercased()
        // OFFICIAL 走官方；AUTO（默认）和 MIRROR 都走镜像
        if raw.contains("official") || raw.contains("官方") { return false }
        if raw.isEmpty { return false }
        return true
    }

    /// 把 Mojang 官方下载地址改写成 BMCLAPI 镜像地址。
    /// 没开镜像时原样返回。库文件 / 资源文件这些大流量都会经过这里。
    public static func mirrored(_ url: URL) -> URL {
        guard mirrorEnabled else { return url }
        let s = url.absoluteString
        let rules: [(String, String)] = [
            ("https://piston-meta.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://launchermeta.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://launcher.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://piston-data.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://resources.download.minecraft.net", "https://bmclapi2.bangbang93.com/assets"),
            ("https://libraries.minecraft.net", "https://bmclapi2.bangbang93.com/maven"),
        ]
        for (from, to) in rules where s.hasPrefix(from) {
            return URL(string: s.replacingOccurrences(of: from, with: to)) ?? url
        }
        return url
    }

    /// 默认共享实例（使用 `makeSession()` 配置的 URLSession）。
    public static let shared = MojangAPI()

    // MARK: 平台信息

    /// 判断 Mojang `rules` 时用的当前平台标识。
    ///
    /// - 注意：Mojang 并没有 iOS 这个 os.name，Pojav / Amethyst 一类启动器
    ///   通常按 "linux"（少数按 "osx"）处理，这里默认给 "linux"，
    ///   需要别的行为时把参数显式传给 `Library.isAllowed(osName:arch:features:)`。
    public enum Platform {

        /// rules 里 `os.name` 的取值："linux" / "windows" / "osx"。
        public static var osName: String {
            #if os(Windows)
            return "windows"
            #elseif os(macOS)
            return "osx"
            #else
            return "linux"
            #endif
        }

        /// rules 里 `os.arch` 的取值："x86" / "x86_64" / "arm64"。
        public static var arch: String {
            #if arch(arm64)
            return "arm64"
            #elseif arch(x86_64)
            return "x86_64"
            #elseif arch(i386)
            return "x86"
            #else
            return "unknown"
            #endif
        }
    }

    // MARK: 属性

    /// 实际发请求用的 session；测试时可以换成一个自定义配置的。
    public let session: URLSession
    /// 版本清单地址；测试时也可以指向本地文件服务器。
    public let manifestURL: URL

    // MARK: 初始化

    public init(session: URLSession = MojangAPI.makeSession(),
                manifestURL: URL = MojangAPI.defaultManifestURL) {
        self.session = session
        self.manifestURL = manifestURL
    }

    /// 给元数据 / 文件下载用的默认 session：
    /// 请求超时 30s、整体超时 600s（客户端 jar 可能几十 MB）。
    /// 不打开 waitsForConnectivity：否则断网时 requests 会一直等到资源超时，
    /// 界面上的「拉清单」会长时间转圈；这里希望它快速失败、由调用方决定重试。
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.httpAdditionalHeaders = ["User-Agent": "ZL2-iOS/0.1 (MojangAPI)"]
        return URLSession(configuration: configuration)
    }

    // MARK: 版本清单

    /// 拉取版本清单（正式版 + 快照 + 远古版本，约 1000+ 条）。
    public func fetchManifest() async throws -> VersionManifest {
        // 每次拉清单都按当前设置选源：选了国内镜像就走 BMCLAPI
        try await self.fetchJSON(from: Self.preferredManifestURL)
    }

    // MARK: 版本详情

    /// 从 manifest 里找到 `id` 对应的 url，再拉该版本的详情 JSON。
    public func fetchVersionDetail(id: String) async throws -> VersionDetail {
        let manifest = try await self.fetchManifest()
        guard let summary = manifest.version(withID: id) else {
            throw MojangAPIError.versionNotFound(id)
        }
        return try await self.fetchVersionDetail(from: summary.url)
    }

    /// 直接按 url 拉版本详情（已缓存过 manifest、想省一次请求时用）。
    public func fetchVersionDetail(from url: URL) async throws -> VersionDetail {
        try await self.fetchJSON(from: url)
    }

    // MARK: 文件下载

    /// 下载单个文件到 `destination`。
    ///
    /// - 先写同目录下的临时文件（`<名字>.<UUID>.part`），全部写完后再原子替换目标文件，
    ///   所以中途失败/取消不会留下半截的目标文件，也不会破坏已有的旧文件。
    /// - `onProgress` 回调 0...1（HTTP 没给 Content-Length 时只在结束时回调 1.0）；
    ///   回调发生在后台上下文，UI 更新请自己切到 MainActor。
    public func downloadFile(from rawURL: URL,
                             to destination: URL,
                             onProgress: (@Sendable (Double) -> Void)? = nil) async throws {

        let url = Self.mirrored(rawURL)
        guard Self.isSupported(url) else {
            throw MojangAPIError.invalidURL(url.absoluteString)
        }
        guard destination.isFileURL else {
            throw MojangAPIError.invalidURL(destination.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        let stream: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (stream, response) = try await self.session.bytes(for: request)
        } catch {
            throw Self.mapNetworkError(error)
        }
        try Self.validate(response)

        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw MojangAPIError.fileIO(error)
        }

        let temporaryURL = directory.appendingPathComponent(
            "\(destination.lastPathComponent).\(UUID().uuidString).part"
        )
        guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw MojangAPIError.fileIO(
                NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
            )
        }

        var finished = false
        defer {
            if !finished {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        do {
            try await Self.write(stream,
                                 to: temporaryURL,
                                 expectedSize: response.expectedContentLength,
                                 onProgress: onProgress)
        } catch let error as MojangAPIError {
            throw error
        } catch {
            throw Self.mapNetworkError(error)
        }

        // 原子替换：同一目录内 move / replace，目标文件要么是旧的、要么是完整的新文件。
        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destination)
            }
        } catch {
            throw MojangAPIError.fileIO(error)
        }

        finished = true
        onProgress?(1.0)
    }

    /// 按 artifact 的 `relativePath`（如 "org/lwjgl/lwjgl/3.4.3/lwjgl-3.4.3.jar"）
    /// 下载到 `directory` 下，返回最终文件 URL。
    @discardableResult
    public func download(artifact: VersionDetail.Artifact,
                         toDirectory directory: URL,
                         onProgress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        let destination = directory.appendingPathComponent(artifact.relativePath)
        try await self.downloadFile(from: artifact.url, to: destination, onProgress: onProgress)
        return destination
    }

    // MARK: 内部实现 —— JSON

    /// 拉 JSON 并解码成 `T`。
    private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {

        guard Self.isSupported(url) else {
            throw MojangAPIError.invalidURL(url.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await self.session.data(for: request)
        } catch {
            throw Self.mapNetworkError(error)
        }
        try Self.validate(response)

        do {
            return try makeJSONDecoder().decode(T.self, from: data)
        } catch {
            throw MojangAPIError.decoding(error)
        }
    }

    // MARK: 内部实现 —— 流式写盘

    /// 把 AsyncBytes 按 64 KB 分块写进已经创建好的文件，并回调进度。
    private static func write(_ stream: URLSession.AsyncBytes,
                              to url: URL,
                              expectedSize: Int64,
                              onProgress: (@Sendable (Double) -> Void)?) async throws {

        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: url)
        } catch {
            throw MojangAPIError.fileIO(error)
        }
        defer { try? handle.close() }

        let chunkSize = 64 * 1024
        var buffer = Data()
        buffer.reserveCapacity(chunkSize)
        var received: Int64 = 0

        if expectedSize > 0 {
            onProgress?(0)
        }

        func flush() throws {
            guard !buffer.isEmpty else { return }
            do {
                try handle.write(contentsOf: buffer)
            } catch {
                throw MojangAPIError.fileIO(error)
            }
            received += Int64(buffer.count)
            buffer.removeAll(keepingCapacity: true)
            if expectedSize > 0 {
                onProgress?(min(1.0, Double(received) / Double(expectedSize)))
            }
        }

        for try await byte in stream {
            buffer.append(byte)
            if buffer.count >= chunkSize {
                try flush()
            }
        }
        try flush()

        if expectedSize > 0 && received < expectedSize {
            // 服务器提前断流：按错误处理，避免把残缺文件当成下载成功。
            throw MojangAPIError.network(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
            )
        }
    }

    // MARK: 内部实现 —— 校验

    /// 只放行 http / https。
    private static func isSupported(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http"
    }

    /// 非 2xx 一律当错误抛。
    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw MojangAPIError.httpStatus(http.statusCode)
        }
    }

    /// 把底层错误归一化（取消单独归类，其余归到 network）。
    private static func mapNetworkError(_ error: Error) -> MojangAPIError {
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError, urlError.code == .cancelled { return .cancelled }
        return .network(error)
    }
}

// MARK: - JSON 解码策略

/// Mojang 的时间字段是 ISO8601，如 `2026-09-15T11:23:02+00:00`；
/// 个别条目带毫秒，两种都尝试。
private enum MojangDateParser {

    private static let plainFormatter: DateFormatter = makeFormatter("yyyy-MM-dd'T'HH:mm:ssXXXXX")
    private static let fractionalFormatter: DateFormatter = makeFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")

    static func date(from string: String) -> Date? {
        if let date = plainFormatter.date(from: string) { return date }
        return fractionalFormatter.date(from: string)
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}

/// 统一的解码器：键不做自动转换（全部由 CodingKeys 显式映射），日期走 ISO8601。
private func makeJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    decoder.dateDecodingStrategy = .custom { dateDecoder in
        let container = try dateDecoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = MojangDateParser.date(from: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析时间字段：\(string)"
            )
        }
        return date
    }
    return decoder
}

// MARK: - 用法示例
//
// let api = MojangAPI.shared
// let manifest = try await api.fetchManifest()
// print("最新正式版：\(manifest.latest.release)，共 \(manifest.releases.count) 个正式版")
//
// let detail = try await api.fetchVersionDetail(id: manifest.latest.release)
// if let client = detail.clientDownload {
//     let target = docs.appendingPathComponent("\(detail.id)/client.jar")
//     try await api.downloadFile(from: client.url, to: target) { progress in
//         print("下载进度：\(Int(progress * 100))%")
//     }
// }
//
// 只下载当前平台需要的依赖库：
// for library in detail.applicableLibraries() {
//     guard let artifact = library.artifact else { continue }
//     try await api.download(artifact: artifact, toDirectory: librariesRoot)
// }
