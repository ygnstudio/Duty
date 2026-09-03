import Foundation

/// JSON 文件持久化管理
/// 数据存储在 ~/Library/Application Support/Duty/
@MainActor
final class PersistenceController: Sendable {
    static let shared = PersistenceController()

    private let fileManager = FileManager.default

    /// 历史记录保留上限（可由设置在 UserDefaults "maxHistoryRecords" 中调整，默认 500）
    private var maxHistoryRecords: Int {
        let value = UserDefaults.standard.integer(forKey: "maxHistoryRecords")
        return value > 0 ? value : 500
    }

    private var dataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Duty", isDirectory: true)
    }

    private var associationsFile: URL {
        dataDirectory.appendingPathComponent("associations.json")
    }

    private var historyFile: URL {
        dataDirectory.appendingPathComponent("history.json")
    }

    private var managedFilesFile: URL {
        dataDirectory.appendingPathComponent("managedFiles.json")
    }

    private init() {
        migrateLegacyDataDirectory()
        ensureDirectory()
    }

    // MARK: - Directory Setup

    /// 应用由 DutiUI 更名为 Duty：一次性迁移旧数据目录
    private func migrateLegacyDataDirectory() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let legacy = appSupport.appendingPathComponent("DutiUI", isDirectory: true)
        let current = appSupport.appendingPathComponent("Duty", isDirectory: true)
        guard fileManager.fileExists(atPath: legacy.path),
              !fileManager.fileExists(atPath: current.path) else { return }
        try? fileManager.moveItem(at: legacy, to: current)
    }

    private func ensureDirectory() {
        guard !fileManager.fileExists(atPath: dataDirectory.path) else { return }
        try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Generic Load/Save

    /// 带版本号的存储包裹结构：写入一律用新格式；读取时兼容旧裸数组格式
    private struct VersionedFile<T: Codable>: Codable {
        let schemaVersion: Int
        let items: [T]
    }

    /// 当前存储格式版本（未来字段变更时递增并在读取处做迁移）
    private static let schemaVersion = 1

    /// 通用读取：新格式（带 schemaVersion）→ 旧裸数组格式（下次保存自动升级）→
    /// 都失败视为文件损坏：先把原文件备份为 *.corrupt-时间戳.json，再以空数据降级启动，
    /// 绝不让一次解码失败无声清掉用户全部配置
    private func loadItems<T: Codable>(from url: URL, label: String) -> [T] {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(VersionedFile<T>.self, from: data) {
            return wrapped.items
        }
        if let legacy = try? decoder.decode([T].self, from: data) {
            return legacy
        }
        backupCorruptFile(at: url, label: label)
        return []
    }

    private func saveItems<T: Codable>(_ items: [T], to url: URL) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let wrapped = VersionedFile<T>(schemaVersion: Self.schemaVersion, items: items)
        guard let data = try? encoder.encode(wrapped) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 把损坏的数据文件移到同目录 *.corrupt-时间戳.json 保留现场，便于用户找回
    private func backupCorruptFile(at url: URL, label: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: Date())
        let dest = url.deletingLastPathComponent()
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".corrupt-\(ts).json")
        do {
            try fileManager.moveItem(at: url, to: dest)
            NSLog("[Duty] %@ 数据文件无法解析，已备份为 %@，本次以空数据启动", label, dest.lastPathComponent)
        } catch {
            NSLog("[Duty] %@ 数据文件无法解析，且备份失败：%@", label, error.localizedDescription)
        }
    }

    // MARK: - Associations

    func loadAssociations() -> [ManagedAssociation] {
        loadItems(from: associationsFile, label: "关联配置")
    }

    func saveAssociations(_ associations: [ManagedAssociation]) {
        saveItems(associations, to: associationsFile)
    }

    // MARK: - History

    func loadHistory() -> [AssociationHistory] {
        loadItems(from: historyFile, label: "历史记录")
    }

    func saveHistory(_ history: [AssociationHistory]) {
        // 保留不超过上限
        saveItems(Array(history.suffix(maxHistoryRecords)), to: historyFile)
    }

    /// 添加一条历史记录
    func appendHistory(_ record: AssociationHistory) {
        // 设置项「记录历史」默认关闭：未开启时不写入
        guard UserDefaults.standard.bool(forKey: "historyEnabled") else { return }
        var history = loadHistory()
        history.append(record)
        saveHistory(history)
    }

    /// 清空历史记录
    func clearHistory() {
        saveHistory([])
    }

    // MARK: - Managed Files

    func loadManagedFiles() -> [ManagedFile] {
        loadItems(from: managedFilesFile, label: "受管文件")
    }

    func saveManagedFiles(_ files: [ManagedFile]) {
        saveItems(files, to: managedFilesFile)
    }

    /// 清空所有数据（测试用）
    func clearAll() {
        try? fileManager.removeItem(at: associationsFile)
        try? fileManager.removeItem(at: historyFile)
        try? fileManager.removeItem(at: managedFilesFile)
    }
}
