import Foundation

/// 内置扩展名信息
struct ExtensionInfo: Codable, Identifiable {
    var id: String { ext }
    let ext: String
    let displayName: [String: String]  // "zh-Hans": "...", "en": "..."
    let category: String
    let preferredUTI: String?

    /// 根据当前语言获取显示名称
    var localizedDisplayName: String {
        let lang = isChineseUI() ? "zh-Hans" : "en"
        return displayName[lang] ?? displayName["en"] ?? ext
    }

    /// 分类的本地化名称
    var localizedCategory: String {
        let isChinese = isChineseUI()
        switch category {
        case "document":
            return isChinese ? "文档" : "Document"
        case "image":
            return isChinese ? "图片" : "Image"
        case "video":
            return isChinese ? "视频" : "Video"
        case "audio":
            return isChinese ? "音频" : "Audio"
        case "archive":
            return isChinese ? "压缩文件" : "Archive"
        case "development":
            return isChinese ? "开发文件" : "Development"
        default:
            return category
        }
    }

    enum CodingKeys: String, CodingKey {
        case ext = "extension"
        case displayName, category, preferredUTI
    }
}
