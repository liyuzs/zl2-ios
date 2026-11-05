// ZL2-iOS · 版本仓库（真实文件操作）
// 目录：<Documents>/instances/<实例>/.minecraft/versions/<id>/
import Foundation

enum VersionRepoError: LocalizedError {
    case notFound(String)
    case alreadyExists(String)
    case invalidName
    case io(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let n):      return "版本不存在：\(n)"
        case .alreadyExists(let n): return "此名称的版本已经存在：\(n)"
        case .invalidName:          return "版本名称不合法（不能为空，不能含 / 或 ..）"
        case .io(let m):            return "文件操作失败：\(m)"
        }
    }
}

/// 版本仓库：所有操作都走真实文件系统
final class VersionRepository {
    static let shared = VersionRepository()

    private let fm = FileManager.default

    /// 当前实例目录：GameDirsScreen 切换后会同步到这里，并持久化到 UserDefaults
    var instanceName: String {
        didSet { UserDefaults.standard.set(instanceName, forKey: "zl.game.instance") }
    }

    var mcRoot: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("instances/\(instanceName)/.minecraft", isDirectory: true)
    }

    var versionsDir: URL { mcRoot.appendingPathComponent("versions", isDirectory: true) }
    var librariesDir: URL { mcRoot.appendingPathComponent("libraries", isDirectory: true) }
    var assetsDir: URL { mcRoot.appendingPathComponent("assets", isDirectory: true) }

    init() {
        instanceName = UserDefaults.standard.string(forKey: "zl.game.instance") ?? "default"
        try? fm.createDirectory(at: versionsDir, withIntermediateDirectories: true)
    }

    // MARK: - 列出版本
    struct InstalledVersion {
        let id: String
        let jsonURL: URL
        let jarURL: URL?
        let sizeBytes: Int64
        let modified: Date?
        var hasJar: Bool { jarURL != nil }
    }

    func listVersions() -> [InstalledVersion] {
        guard let entries = try? fm.contentsOfDirectory(at: versionsDir,
                                                       includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                                                       options: [.skipsHiddenFiles]) else {
            return []
        }
        var result: [InstalledVersion] = []
        for dir in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let id = dir.lastPathComponent
            let json = dir.appendingPathComponent("\(id).json")
            let jar = dir.appendingPathComponent("\(id).jar")
            let hasJSON = fm.fileExists(atPath: json.path)
            let hasJar = fm.fileExists(atPath: jar.path)
            guard hasJSON || hasJar else { continue }
            let size = directorySize(dir)
            let mod = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            result.append(InstalledVersion(id: id,
                                           jsonURL: json,
                                           jarURL: hasJar ? jar : nil,
                                           sizeBytes: size,
                                           modified: mod))
        }
        return result.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    // MARK: - 复制版本
    func copyVersion(_ source: String, to newName: String) throws {
        let src = versionsDir.appendingPathComponent(source, isDirectory: true)
        let dst = versionsDir.appendingPathComponent(newName, isDirectory: true)
        guard fm.fileExists(atPath: src.path) else { throw VersionRepoError.notFound(source) }
        guard !fm.fileExists(atPath: dst.path) else { throw VersionRepoError.alreadyExists(newName) }
        guard isValidName(newName) else { throw VersionRepoError.invalidName }
        do {
            try fm.copyItem(at: src, to: dst)
            // 复制后要把里面的 <id>.json / <id>.jar 改成新名字
            let oldJSON = dst.appendingPathComponent("\(source).json")
            let newJSON = dst.appendingPathComponent("\(newName).json")
            if fm.fileExists(atPath: oldJSON.path) {
                try? fm.moveItem(at: oldJSON, to: newJSON)
            }
            let oldJar = dst.appendingPathComponent("\(source).jar")
            let newJar = dst.appendingPathComponent("\(newName).jar")
            if fm.fileExists(atPath: oldJar.path) {
                try? fm.moveItem(at: oldJar, to: newJar)
            }
        } catch {
            throw VersionRepoError.io(ZLFriendlyError.text(error))
        }
    }

    // MARK: - 重命名版本
    func renameVersion(_ old: String, to newName: String) throws {
        let src = versionsDir.appendingPathComponent(old, isDirectory: true)
        let dst = versionsDir.appendingPathComponent(newName, isDirectory: true)
        guard fm.fileExists(atPath: src.path) else { throw VersionRepoError.notFound(old) }
        guard !fm.fileExists(atPath: dst.path) else { throw VersionRepoError.alreadyExists(newName) }
        guard isValidName(newName) else { throw VersionRepoError.invalidName }
        do {
            try fm.moveItem(at: src, to: dst)
            let oldJSON = dst.appendingPathComponent("\(old).json")
            if fm.fileExists(atPath: oldJSON.path) {
                try? fm.moveItem(at: oldJSON, to: dst.appendingPathComponent("\(newName).json"))
            }
            let oldJar = dst.appendingPathComponent("\(old).jar")
            if fm.fileExists(atPath: oldJar.path) {
                try? fm.moveItem(at: oldJar, to: dst.appendingPathComponent("\(newName).jar"))
            }
        } catch {
            throw VersionRepoError.io(ZLFriendlyError.text(error))
        }
    }

    // MARK: - 删除版本
    func deleteVersion(_ id: String) throws {
        let dir = versionsDir.appendingPathComponent(id, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { throw VersionRepoError.notFound(id) }
        do { try fm.removeItem(at: dir) }
        catch { throw VersionRepoError.io(ZLFriendlyError.text(error)) }
    }

    // MARK: - 清理无用文件
    struct CleanResult {
        var removedFiles: Int = 0
        var freedBytes: Int64 = 0
        var failed: [String] = []
    }

    /// 扫描 libraries / assets，删除没有被任何已安装版本引用的
    func cleanUnusedFiles(dryRun: Bool = false) -> CleanResult {
        var result = CleanResult()

        // 1. 收集所有版本 json 里引用的 library path
        var referencedLibs = Set<String>()
        var referencedAssets = Set<String>()

        for v in listVersions() {
            guard let data = try? Data(contentsOf: v.jsonURL),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let libs = obj["libraries"] as? [[String: Any]] {
                for lib in libs {
                    if let downloads = lib["downloads"] as? [String: Any],
                       let artifact = downloads["artifact"] as? [String: Any],
                       let path = artifact["path"] as? String {
                        referencedLibs.insert(path)
                    }
                }
            }
            if let ai = obj["assetIndex"] as? [String: Any],
               let id = ai["id"] as? String {
                referencedAssets.insert("indexes/\(id).json")
            }
        }

        // 2. libraries：删掉未被引用的文件
        if let files = fm.enumerator(at: librariesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let f as URL in files {
                guard !f.hasDirectoryPath else { continue }
                let rel = f.path.replacingOccurrences(of: librariesDir.path + "/", with: "")
                if referencedLibs.contains(rel) { continue }
                let size = Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                if !dryRun {
                    do { try fm.removeItem(at: f); result.removedFiles += 1; result.freedBytes += size }
                    catch { result.failed.append(rel) }
                } else {
                    result.removedFiles += 1; result.freedBytes += size
                }
            }
        }

        // 3. 清理空目录
        if !dryRun { pruneEmptyDirs(librariesDir) }
        return result
    }

    private func pruneEmptyDirs(_ root: URL) {
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                    options: [.skipsHiddenFiles]) else { return }
        var dirs: [URL] = []
        for case let u as URL in en {
            if (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { dirs.append(u) }
        }
        for d in dirs.sorted(by: { $0.path.count > $1.path.count }) {
            if let c = try? fm.contentsOfDirectory(atPath: d.path), c.isEmpty {
                try? fm.removeItem(at: d)
            }
        }
    }

    // MARK: - 工具
    private func isValidName(_ name: String) -> Bool {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != ".", t != ".." else { return false }
        guard !t.contains("/"), !t.contains("\\"), !t.contains(":") else { return false }
        return true
    }

    func directorySize(_ url: URL) -> Int64 {
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in en {
            if let s = try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize { total += Int64(s) }
        }
        return total
    }

    /// 版本文件夹快捷路径（供详情页跳转）
    func folder(for kind: String, versionID: String) -> URL? {
        switch kind {
        case "版本": return versionsDir.appendingPathComponent(versionID, isDirectory: true)
        case "模组": return mcRoot.appendingPathComponent("mods", isDirectory: true)
        case "资源包": return mcRoot.appendingPathComponent("resourcepacks", isDirectory: true)
        case "光影": return mcRoot.appendingPathComponent("shaderpacks", isDirectory: true)
        case "存档": return mcRoot.appendingPathComponent("saves", isDirectory: true)
        case "截图": return mcRoot.appendingPathComponent("screenshots", isDirectory: true)
        case "日志": return mcRoot.appendingPathComponent("logs", isDirectory: true)
        case "崩溃报告": return mcRoot.appendingPathComponent("crash-reports", isDirectory: true)
        default: return mcRoot
        }
    }
}
