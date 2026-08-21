import Foundation

/// 用户管理的「单个文件」的打开方式（文件级锁定）
/// 与全局的 ManagedAssociation 并列，针对某个具体文件锁定其打开应用
struct ManagedFile: Codable, Identifiable, Equatable {
    let id: UUID
    var filePath: String            // 绝对路径
    var fileExtension: String       // 扩展名（无点，小写）
    var targetBundleIdentifier: String
    var targetApplicationName: String
    var isLocked: Bool
    var status: AssociationStatus
    var createdAt: Date
    var updatedAt: Date
    var lastCheckedAt: Date?

    var displayName: String {
        (filePath as NSString).lastPathComponent
    }

    init(
        id: UUID = UUID(),
        filePath: String,
        targetBundleIdentifier: String,
        targetApplicationName: String,
        isLocked: Bool = false,
        status: AssociationStatus = .unlocked,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastCheckedAt: Date? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.fileExtension = ManagedAssociation.normalizeExtension(
            (filePath as NSString).pathExtension
        )
        self.targetBundleIdentifier = targetBundleIdentifier
        self.targetApplicationName = targetApplicationName
        self.isLocked = isLocked
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastCheckedAt = lastCheckedAt
    }
}
