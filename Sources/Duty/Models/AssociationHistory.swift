import Foundation

/// 关联变化历史记录（全局文件类型级 + 单个文件级）
struct AssociationHistory: Codable, Identifiable {
    let id: UUID
    let associationID: UUID
    let fileExtension: String
    let filePath: String?              // 非 nil 表示「单文件级」记录
    let expectedApplicationName: String
    let expectedBundleIdentifier: String
    let detectedApplicationName: String?
    let detectedBundleIdentifier: String?
    let result: RestoreResult
    let errorMessage: String?
    let duration: TimeInterval?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        associationID: UUID,
        fileExtension: String,
        filePath: String? = nil,
        expectedApplicationName: String,
        expectedBundleIdentifier: String,
        detectedApplicationName: String? = nil,
        detectedBundleIdentifier: String? = nil,
        result: RestoreResult,
        errorMessage: String? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.associationID = associationID
        self.fileExtension = fileExtension
        self.filePath = filePath
        self.expectedApplicationName = expectedApplicationName
        self.expectedBundleIdentifier = expectedBundleIdentifier
        self.detectedApplicationName = detectedApplicationName
        self.detectedBundleIdentifier = detectedBundleIdentifier
        self.result = result
        self.errorMessage = errorMessage
        self.duration = duration
        self.createdAt = createdAt
    }
}
