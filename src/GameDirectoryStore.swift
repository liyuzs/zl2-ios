// ZL2-iOS · 游戏目录存储
// 对照 ZL2：游戏目录 = 每个「实例」下的 .minecraft。
// 这里把实例真正落到 <Documents>/instances/<实例名>/.minecraft，
// 切换实例会同步给 VersionRepository（版本 / 模组 / 存档等页面全部跟着切换），
// 并持久化到 UserDefaults，下次启动仍然使用上次选择的目录。
import Foundation
import SwiftUI

enum GameDirError: LocalizedError {
    case invalidName
    case exists(String)
    case protectedDir
    case notFound(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "目录名不能为空，且不能包含 / : \\ 等字符"
        case .exists(let n):
            return "目录「\(n)」已经存在"
        case .protectedDir:
            return "默认目录和正在使用的目录不能删除或重命名"
        case .notFound(let n):
            return "找不到目录「\(n)」"
        case .io(let m):
            return "文件操作失败：\(m)"
        }
    }
}

struct ZLGameInstance: Identifiable, Equatable {
    let id: String            // 实例目录名
    let root: URL             // <instances>/<id>/.minecraft
    let versionCount: Int
    let modified: Date?

    var displayPath: String {
        root.path.replacingOccurrences(
            of: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path,
            with: "Documents")
    }
}

final class GameDirectoryStore: ObservableObject {
    static let shared = GameDirectoryStore()

    @Published private(set) var instances: [ZLGameInstance] = []
    @Published private(set) var activeName: String

    private let fm = FileManager.default
    private let defaults = UserDefaults.standard

    let instancesRoot: URL

    private init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        instancesRoot = docs.appendingPathComponent("instances", isDirectory: true)

        let saved = defaults.string(forKey: "zl.game.instance") ?? "default"
        activeName = saved
        VersionRepository.shared.instanceName = saved

        try? fm.createDirectory(at: instancesRoot, withIntermediateDirectories: true)
        // 保证至少有一个 default 实例，和历史目录保持兼容
        if !fm.fileExists(atPath: instanceRoot("default").path) {
            try? fm.createDirectory(
                at: instanceRoot("default").appendingPathComponent("versions", isDirectory: true),
                withIntermediateDirectories: true)
        }
        reload()
    }

    // MARK: - 路径

    func instanceRoot(_ name: String) -> URL {
        instancesRoot
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(".minecraft", isDirectory: true)
    }

    var active: ZLGameInstance? {
        instances.first { $0.id == activeName }
    }

    // MARK: - 扫描

    func reload() {
        guard let names = try? fm.contentsOfDirectory(atPath: instancesRoot.path) else {
            instances = []
            return
        }
        var list: [ZLGameInstance] = []
        for name in names.sorted() where !name.hasPrefix(".") {
            let dir = instancesRoot.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let root = dir.appendingPathComponent(".minecraft", isDirectory: true)
            let mod = try? dir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            list.append(ZLGameInstance(id: name,
                                       root: root,
                                       versionCount: versionCount(root),
                                       modified: mod))
        }
        // 正在使用的排最前，其余按名称
        instances = list.sorted { a, b in
            if a.id == activeName { return true }
            if b.id == activeName { return false }
            return a.id.localizedStandardCompare(b.id) == .orderedAscending
        }
    }

    func versionCount(_ root: URL) -> Int {
        let versions = root.appendingPathComponent("versions", isDirectory: true)
        guard let dirs = try? fm.contentsOfDirectory(at: versions,
                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsHiddenFiles]) else {
            return 0
        }
        return dirs.filter { dir in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return false }
            let id = dir.lastPathComponent
            return fm.fileExists(atPath: dir.appendingPathComponent("\(id).json").path)
                || fm.fileExists(atPath: dir.appendingPathComponent("\(id).jar").path)
        }.count
    }

    // MARK: - 增删改

    @discardableResult
    func create(_ rawName: String) throws -> String {
        let name = try validated(rawName)
        let dir = instancesRoot.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: dir.path) else { throw GameDirError.exists(name) }
        do {
            try fm.createDirectory(at: dir.appendingPathComponent(".minecraft/versions", isDirectory: true),
                                   withIntermediateDirectories: true)
        } catch {
            throw GameDirError.io(error.localizedDescription)
        }
        activate(name)
        return name
    }

    /// 接管一个已存在的文件夹作为实例（没有 .minecraft 就创建）
    @discardableResult
    func adopt(_ directory: URL) throws -> String {
        let dir = directory.standardizedFileURL
        let root = dir.lastPathComponent == ".minecraft" ? dir : dir.appendingPathComponent(".minecraft", isDirectory: true)
        guard dir.path.hasPrefix(instancesRoot.path) else {
            throw GameDirError.io("请选择 instances 目录下的文件夹")
        }
        if !fm.fileExists(atPath: root.path) {
            do {
                try fm.createDirectory(at: root.appendingPathComponent("versions", isDirectory: true),
                                       withIntermediateDirectories: true)
            } catch {
                throw GameDirError.io(error.localizedDescription)
            }
        }
        let name = root.lastPathComponent == ".minecraft"
            ? root.deletingLastPathComponent().lastPathComponent
            : dir.lastPathComponent
        activate(name)
        return name
    }

    func rename(_ old: String, to rawName: String) throws {
        guard old != "default", old != activeName else { throw GameDirError.protectedDir }
        let name = try validated(rawName)
        let src = instancesRoot.appendingPathComponent(old, isDirectory: true)
        let dst = instancesRoot.appendingPathComponent(name, isDirectory: true)
        guard fm.fileExists(atPath: src.path) else { throw GameDirError.notFound(old) }
        guard !fm.fileExists(atPath: dst.path) else { throw GameDirError.exists(name) }
        do { try fm.moveItem(at: src, to: dst) }
        catch { throw GameDirError.io(error.localizedDescription) }
        reload()
    }

    func delete(_ name: String) throws {
        guard name != "default", name != activeName else { throw GameDirError.protectedDir }
        let dir = instancesRoot.appendingPathComponent(name, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { throw GameDirError.notFound(name) }
        do { try fm.removeItem(at: dir) }
        catch { throw GameDirError.io(error.localizedDescription) }
        reload()
    }

    func activate(_ name: String) {
        guard fm.fileExists(atPath: instanceRoot(name).path)
            || fm.fileExists(atPath: instancesRoot.appendingPathComponent(name).path) else { return }
        // 目录存在但还没有 .minecraft 时补一个，避免版本页空白
        let root = instanceRoot(name)
        if !fm.fileExists(atPath: root.path) {
            try? fm.createDirectory(at: root.appendingPathComponent("versions", isDirectory: true),
                                    withIntermediateDirectories: true)
        }
        activeName = name
        VersionRepository.shared.instanceName = name
        CoreBridge.resetBootstrap()
        defaults.set(name, forKey: "zl.game.instance")
        reload()
    }

    func isActive(_ name: String) -> Bool { name == activeName }

    // MARK: - 工具

    private func validated(_ raw: String) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", name.count <= 40,
              !name.contains("/"), !name.contains("\\"), !name.contains(":") else {
            throw GameDirError.invalidName
        }
        return name
    }
}
