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

    // MARK: - Associations

    func loadAssociations() -> [ManagedAssociation] {
        guard fileManager.fileExists(atPath: associationsFile.path),
              let data = try? Data(contentsOf: associationsFile) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([ManagedAssociation].self, from: data)) ?? []
    }

    func saveAssociations(_ associations: [ManagedAssociation]) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(associations) else { return }
        try? data.write(to: associationsFile, options: .atomic)
    }

    // MARK: - History

    func loadHistory() -> [AssociationHistory] {
        guard fileManager.fileExists(atPath: historyFile.path),
              let data = try? Data(contentsOf: historyFile) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([AssociationHistory].self, from: data)) ?? []
    }

    func saveHistory(_ history: [AssociationHistory]) {
        ensureDirectory()
        // 保留不超过上限
        let trimmed = history.suffix(maxHistoryRecords)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(Array(trimmed)) else { return }
        try? data.write(to: historyFile, options: .atomic)
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
        guard fileManager.fileExists(atPath: managedFilesFile.path),
              let data = try? Data(contentsOf: managedFilesFile) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([ManagedFile].self, from: data)) ?? []
    }

    func saveManagedFiles(_ files: [ManagedFile]) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(files) else { return }
        try? data.write(to: managedFilesFile, options: .atomic)
    }

    /// 清空所有数据（测试用）
    func clearAll() {
        try? fileManager.removeItem(at: associationsFile)
        try? fileManager.removeItem(at: historyFile)
        try? fileManager.removeItem(at: managedFilesFile)
    }
}
