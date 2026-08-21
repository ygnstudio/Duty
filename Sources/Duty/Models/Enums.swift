import Foundation
import AppKit

/// 关联保护状态
enum AssociationStatus: String, Codable, CaseIterable {
    /// 正常：已锁定且当前默认应用与目标一致
    case normal
    /// 未保护：未开启锁定
    case unlocked
    /// 已变化：检测到默认应用被修改，等待恢复
    case changed
    /// 恢复失败：尝试恢复但失败
    case restoreFailed
    /// 目标应用不存在
    case targetApplicationMissing

    var displayName: String {
        switch self {
        case .normal:
            return isChineseUI() ? "正常" : "Normal"
        case .unlocked:
            return isChineseUI() ? "未保护" : "Unprotected"
        case .changed:
            return isChineseUI() ? "已变化" : "Changed"
        case .restoreFailed:
            return isChineseUI() ? "恢复失败" : "Restore Failed"
        case .targetApplicationMissing:
            return isChineseUI() ? "目标应用不存在" : "App Missing"
        }
    }
}

/// 恢复结果
enum RestoreResult: String, Codable {
    /// 已恢复
    case restored
    /// 恢复失败
    case failed
    /// 跳过（目标应用缺失等）
    case skipped

    var displayName: String {
        switch self {
        case .restored:
            return isChineseUI() ? "已恢复" : "Restored"
        case .failed:
            return isChineseUI() ? "恢复失败" : "Failed"
        case .skipped:
            return isChineseUI() ? "已跳过" : "Skipped"
        }
    }
}

/// 界面语言设置
enum AppLanguage: String, CaseIterable, Identifiable {
    /// 跟随系统（默认）
    case system
    /// 简体中文
    case zh
    /// English
    case en

    var id: String { rawValue }

    /// 设置面板中的显示名称
    var displayName: String {
        switch self {
        case .system:
            return isChineseUI() ? "跟随系统" : "System"
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

/// 当前界面是否使用中文
/// 优先读取用户设置（UserDefaults "appLanguage"），默认跟随系统语言
func isChineseUI() -> Bool {
    let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
    switch AppLanguage(rawValue: raw) ?? .system {
    case .zh: return true
    case .en: return false
    case .system: return Locale.current.isChinese
    }
}

/// 外观设置
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return isChineseUI() ? "跟随系统" : "System"
        case .light: return isChineseUI() ? "浅色" : "Light"
        case .dark: return isChineseUI() ? "深色" : "Dark"
        }
    }
}

/// 应用外观设置（读 UserDefaults "appearance"：system/light/dark）
func applyAppearance(_ raw: String? = nil) {
    let value = raw ?? UserDefaults.standard.string(forKey: "appearance") ?? AppAppearance.system.rawValue
    switch value {
    case AppAppearance.light.rawValue:
        NSApp.appearance = NSAppearance(named: .aqua)
    case AppAppearance.dark.rawValue:
        NSApp.appearance = NSAppearance(named: .darkAqua)
    default:
        NSApp.appearance = nil   // 跟随系统
    }
}

extension Locale {
    var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }
}
