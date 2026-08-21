import Foundation
import UniformTypeIdentifiers
import AppKit
import Darwin

/// 应用信息（用于显示，不暴露 Bundle ID 给 UI）
struct AppInfo: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let path: String?
    let icon: NSImage?

    init(name: String, bundleIdentifier: String, path: String? = nil, icon: NSImage? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

/// 默认应用关联服务
/// 负责 UTI 解析、查询默认应用、设置默认应用
@MainActor
final class AssociationService: Sendable {
    static let shared = AssociationService()

    private var dutiPath: String?

    private init() {
        refreshDutiPath()
    }

    // MARK: - Duti Path

    func refreshDutiPath() {
        dutiPath = DutiDetector.findDutiPath()
    }

    var isDutiAvailable: Bool {
        dutiPath != nil
    }

    var currentDutiPath: String? {
        dutiPath
    }

    // MARK: - UTI Resolution

    /// 扩展名 → UTI
    func resolveUTI(for fileExtension: String) -> String? {
        let normalized = ManagedAssociation.normalizeExtension(fileExtension)
        // 先尝试 UTType
        if let type = UTType(filenameExtension: normalized) {
            return type.identifier
        }
        // 回退：通过 duti 查询
        return resolveUTIViaDuti(extension: normalized)
    }

    /// 通过 duti 解析 UTI（回退方案）
    private func resolveUTIViaDuti(extension ext: String) -> String? {
        guard let path = dutiPath else { return nil }
        do {
            let result = try CommandRunner.run(
                executablePath: path,
                arguments: ["-x", ext],
                timeout: 5
            )
            return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - Query Default App

    /// 查询某个 UTI 的当前默认应用
    /// macOS 26 上 LSCopy* API 读 launchservicesd 缓存，写入后不自动刷新，
    /// 因此优先读取 LS secure plist 中的真实 handler，plist 无记录时回退到 LSCopy API。
    func getDefaultApplication(forUTI uti: String) -> AppInfo? {
        if let handler = defaultHandlerFromLSHandlers(forUTI: uti) {
            return appInfo(forBundleIdentifier: handler)
        }
        // 回退：使用 Launch Services 公开 API
        guard let handler = LSCopyDefaultRoleHandlerForContentType(
            uti as CFString,
            LSRolesMask.all
        )?.takeRetainedValue() as String? else {
            return nil
        }
        return appInfo(forBundleIdentifier: handler)
    }

    /// 从 LS secure plist 读取 UTI 的真实默认 handler（绕过 daemon 缓存）
    /// 取 LSHandlerModificationDate 最新的记录
    private func defaultHandlerFromLSHandlers(forUTI uti: String) -> String? {
        let plistPath = NSHomeDirectory()
            + "/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: Any],
              let handlers = plist["LSHandlers"] as? [[String: Any]] else {
            return nil
        }
        let matching = handlers.filter { ($0["LSHandlerContentType"] as? String) == uti }
        guard !matching.isEmpty else { return nil }
        return matching.max(by: {
            modificationDate($0) < modificationDate($1)
        })?["LSHandlerRoleAll"] as? String
    }

    /// 读取 LSHandlerModificationDate（plist 中可能为 NSDate 或 NSNumber）
    private func modificationDate(_ dict: [String: Any]) -> TimeInterval {
        if let date = dict["LSHandlerModificationDate"] as? Date {
            return date.timeIntervalSinceReferenceDate
        }
        if let number = dict["LSHandlerModificationDate"] as? NSNumber {
            return number.doubleValue
        }
        return 0
    }

    /// 查询某个扩展名的当前默认应用
    func getDefaultApplication(forExtension ext: String) -> AppInfo? {
        guard let uti = resolveUTI(for: ext) else { return nil }
        return getDefaultApplication(forUTI: uti)
    }

    // MARK: - Available Apps

    /// 获取能够打开某个 UTI 的所有应用
    func getAvailableApplications(forUTI uti: String) -> [AppInfo] {
        guard let handlers = LSCopyAllRoleHandlersForContentType(
            uti as CFString,
            LSRolesMask.all
        )?.takeRetainedValue() as? [String] else {
            return []
        }
        return handlers.compactMap { appInfo(forBundleIdentifier: $0) }
    }

    // MARK: - Set Default App

    /// 设置某个 UTI 的默认应用
    /// 优先 NSWorkspace 官方 API（macOS 12+，走完整系统路径，弹系统确认框），
    /// 失败时回退 Launch Services 底层 API（无需 duti 命令行依赖）。
    func setDefaultApplication(bundleIdentifier: String, forUTI uti: String) async throws {
        // 方案 1：NSWorkspace 官方 API
        if let appURL = findAppURL(forBundleIdentifier: bundleIdentifier),
           let type = UTType(uti) {
            do {
                try await setDefaultApplicationViaWorkspace(appURL: appURL, type: type)
                logger.info("已通过 NSWorkspace 设置默认应用: \(bundleIdentifier) → \(uti)")
                return
            } catch {
                logger.info("NSWorkspace 设置失败，回退 LS API: \(error.localizedDescription)")
            }
        }

        // 方案 2：Launch Services 底层 API 兜底（等价 duti 的 LSSetDefaultRoleHandlerForContentType）
        try await setDefaultApplicationViaLSAPI(bundleIdentifier: bundleIdentifier, uti: uti)
    }

    /// NSWorkspace 官方 API 设置默认应用（macOS 26 SDK 为 async 版本）
    private func setDefaultApplicationViaWorkspace(appURL: URL, type: UTType) async throws {
        try await NSWorkspace.shared.setDefaultApplication(
            at: appURL,
            toOpen: type
        )
    }

    /// Launch Services 底层 API 写入（兜底，无需 duti）
    private func setDefaultApplicationViaLSAPI(bundleIdentifier: String, uti: String) async throws {
        let status = LSSetDefaultRoleHandlerForContentType(
            uti as CFString,
            LSRolesMask.all,
            bundleIdentifier as CFString
        )
        guard status == noErr else {
            throw AssociationServiceError.writeFailed(reason: "Launch Services error \(status)")
        }
    }

    /// 验证 UTI 的默认应用是否为预期值
    /// LaunchServices 存储的 bundle id 为全小写，比较时忽略大小写
    func verifyDefaultApplication(forUTI uti: String, bundleIdentifier: String) -> Bool {
        guard let current = getDefaultApplication(forUTI: uti) else { return false }
        return current.bundleIdentifier.lowercased() == bundleIdentifier.lowercased()
    }

    // MARK: - File-Level (xattr) Open With

    /// 读取文件的「单文件打开方式」覆盖（com.apple.LaunchServices.OpenWith）的 bundle identifier
    /// 返回 nil 表示该文件没有单文件覆盖（跟随全局默认）
    func getOpenWithBundleIdentifier(forFile path: String) -> String? {
        let name = "com.apple.LaunchServices.OpenWith"
        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { (buf: UnsafeMutableRawBufferPointer) -> Int in
            getxattr(path, name, buf.baseAddress, size, 0, 0)
        }
        guard read == size else { return nil }
        guard let dict = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }
        return dict["bundleidentifier"] as? String
    }

    /// 写入文件的「单文件打开方式」覆盖（指向指定应用）
    @discardableResult
    func setOpenWith(forFile path: String, appPath: String, bundleIdentifier: String) -> Bool {
        // version 1 = 与 Finder「显示简介→始终打开」写入的格式一致
        let dict: [String: Any] = [
            "version": 1,
            "path": appPath,
            "bundleidentifier": bundleIdentifier
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict, format: .binary, options: 0
        ) else {
            return false
        }
        let result = data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Int32 in
            setxattr(path, "com.apple.LaunchServices.OpenWith", buf.baseAddress, data.count, 0, 0)
        }
        return result == 0
    }

    /// 清除文件的「单文件打开方式」覆盖（恢复跟随全局默认）
    func clearOpenWith(forFile path: String) {
        removexattr(path, "com.apple.LaunchServices.OpenWith", 0)
    }

    /// 清除文件的单文件覆盖并刷新 Finder（让文件立即回退跟随全局默认）
    func resetFileOpenWith(forFile path: String) async {
        clearOpenWith(forFile: path)
        _ = try? await CommandRunner.runAsync(
            executablePath: "/usr/bin/killall",
            arguments: ["Finder"],
            timeout: 5
        )
    }

    /// 根据 Bundle Identifier 查找应用路径（供文件级恢复使用）
    func appPath(forBundleIdentifier bundleID: String) -> String? {
        findAppURL(forBundleIdentifier: bundleID)?.path
    }

    // MARK: - Helpers

    /// 根据 Bundle Identifier 获取应用信息
    private func appInfo(forBundleIdentifier bundleID: String) -> AppInfo? {
        // 多种方法尝试找到应用 URL
        let appURL = findAppURL(forBundleIdentifier: bundleID)

        guard let url = appURL else {
            return AppInfo(
                name: bundleNameFromIdentifier(bundleID),
                bundleIdentifier: bundleID,
                path: nil,
                icon: nil
            )
        }

        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path

        // 加载图标：先尝试 NSWorkspace，再尝试从 Bundle 中直接读取
        let icon = loadAppIcon(from: url)

        return AppInfo(
            name: name,
            bundleIdentifier: bundleID,
            path: path,
            icon: icon
        )
    }

    /// 多种方式查找应用 URL
    private func findAppURL(forBundleIdentifier bundleID: String) -> URL? {
        // 方法 1：NSWorkspace
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        // 方法 2：Launch Services（更可靠）
        if let urls = LSCopyApplicationURLsForBundleIdentifier(
            bundleID as CFString, nil
        )?.takeRetainedValue() as? [URL],
           let first = urls.first {
            return first
        }
        // 方法 3：遍历 /Applications
        return findAppInCommonLocations(bundleID: bundleID)
    }

    /// 在常见目录中查找应用
    private func findAppInCommonLocations(bundleID: String) -> URL? {
        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]
        for dir in searchDirs {
            if let url = searchForBundleID(bundleID, in: dir) {
                return url
            }
        }
        return nil
    }

    private func searchForBundleID(_ bundleID: String, in directory: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                if let bundle = Bundle(url: url),
                   bundle.bundleIdentifier == bundleID {
                    return url
                }
            }
        }
        return nil
    }

    /// 加载应用图标
    private func loadAppIcon(from appURL: URL) -> NSImage? {
        let path = appURL.path

        // 先用 NSWorkspace 获取图标
        let icon = NSWorkspace.shared.icon(forFile: path)

        // 检查是否拿到了有效的非默认图标
        // NSWorkspace 总是返回非 nil，但可能是通用占位图标
        if icon.isValid {
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }

        // 备选：直接从 app bundle 的 Info.plist 中查找图标文件名
        if let bundle = Bundle(url: appURL),
           let iconFile = (bundle.infoDictionary?["CFBundleIconFile"] as? String)
                        ?? (bundle.infoDictionary?["CFBundleIconName"] as? String) {
            // 尝试 .icns 格式
            if let iconPath = bundle.path(forResource: iconFile, ofType: "icns"),
               let directIcon = NSImage(contentsOfFile: iconPath) {
                directIcon.size = NSSize(width: 32, height: 32)
                return directIcon
            }
            // 尝试无扩展名
            if let iconPath = bundle.path(forResource: iconFile, ofType: nil),
               let directIcon = NSImage(contentsOfFile: iconPath) {
                directIcon.size = NSSize(width: 32, height: 32)
                return directIcon
            }
            // 尝试 AppIcon
            if let iconPath = bundle.path(forResource: "AppIcon", ofType: "icns"),
               let directIcon = NSImage(contentsOfFile: iconPath) {
                directIcon.size = NSSize(width: 32, height: 32)
                return directIcon
            }
        }

        return icon
    }

    /// 从 Bundle Identifier 推测应用名称（回退方案）
    private func bundleNameFromIdentifier(_ identifier: String) -> String {
        // 取最后一段并美化
        let components = identifier.split(separator: ".")
        guard let last = components.last else { return identifier }
        let name = String(last)
        // 常见映射
        let knownNames: [String: String] = [
            "Preview": "预览",
            "Safari": "Safari",
            "Mail": "邮件",
            "Notes": "备忘录",
            "TextEdit": "文本编辑",
            "Finder": "访达",
            "QuickTime Player": "QuickTime Player",
            "Music": "音乐",
            "Photos": "照片",
        ]
        return knownNames[name] ?? name
    }
}

// MARK: - Errors

enum AssociationServiceError: LocalizedError {
    case writeFailed(reason: String)
    case verificationFailed
    case cannotResolveUTI(String)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let reason):
            return "Failed to set default application: \(reason)"
        case .verificationFailed:
            return "Verification failed after writing"
        case .cannotResolveUTI(let ext):
            return "Cannot resolve UTI for extension: \(ext)"
        }
    }
}
