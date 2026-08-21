import Foundation

/// 用户管理的文件关联
struct ManagedAssociation: Codable, Identifiable, Equatable {
    let id: UUID
    var fileExtension: String       // "pdf", "md"（无点号，小写）
    var displayName: String         // "PDF 文档" / "PDF Document"
    var uti: String                 // 内部 UTI，如 "com.adobe.pdf"
    var targetApplicationName: String
    var targetBundleIdentifier: String
    var targetApplicationPath: String?
    var isLocked: Bool
    var status: AssociationStatus
    var createdAt: Date
    var updatedAt: Date
    var lastCheckedAt: Date?
    var lastRestoredAt: Date?

    init(
        id: UUID = UUID(),
        fileExtension: String,
        displayName: String,
        uti: String,
        targetApplicationName: String,
        targetBundleIdentifier: String,
        targetApplicationPath: String? = nil,
        isLocked: Bool = false,
        status: AssociationStatus = .unlocked,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastCheckedAt: Date? = nil,
        lastRestoredAt: Date? = nil
    ) {
        self.id = id
        self.fileExtension = fileExtension.lowercased().replacingOccurrences(of: ".", with: "")
        self.displayName = displayName
        self.uti = uti
        self.targetApplicationName = targetApplicationName
        self.targetBundleIdentifier = targetBundleIdentifier
        self.targetApplicationPath = targetApplicationPath
        self.isLocked = isLocked
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastCheckedAt = lastCheckedAt
        self.lastRestoredAt = lastRestoredAt
    }

    /// 标准化扩展名：去点、小写
    static func normalizeExtension(_ ext: String) -> String {
        ext.lowercased().replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
    }
}
