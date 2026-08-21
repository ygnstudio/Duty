import Foundation
import UserNotifications

/// 自动保护服务
/// 定时检查已锁定的项目，发现变化后自动恢复
@MainActor
final class ProtectionService: ObservableObject {
    static let shared = ProtectionService()

    // MARK: - Published State

    @Published var isRunning = false
    @Published var isPaused = false

    // MARK: - Settings (backed by UserDefaults)

    private let defaults = UserDefaults.standard

    var checkInterval: Double {
        get {
            let value = defaults.double(forKey: "checkInterval")
            return value > 0 ? value : 10
        }
        set { defaults.set(newValue, forKey: "checkInterval") }
    }

    var showNotifications: Bool {
        get {
            if defaults.object(forKey: "showNotifications") == nil { return true }
            return defaults.bool(forKey: "showNotifications")
        }
        set { defaults.set(newValue, forKey: "showNotifications") }
    }

    var autoStartProtection: Bool {
        get {
            if defaults.object(forKey: "autoStartProtection") == nil { return true }
            return defaults.bool(forKey: "autoStartProtection")
        }
        set { defaults.set(newValue, forKey: "autoStartProtection") }
    }

    // MARK: - Private

    private var timer: Timer?
    private var isChecking = false
    private var plistMonitor: DispatchSourceFileSystemObject?
    private var plistFileDescriptor: Int32 = -1
    private let persistence = PersistenceController.shared
    private let associationService = AssociationService.shared

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        scheduleTimer()
        startPlistMonitoring()
    }

    func stop() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        stopPlistMonitoring()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        stopPlistMonitoring()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        scheduleTimer()
        startPlistMonitoring()
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performCheck()
            }
        }
    }

    /// 更新检查间隔（从设置中读取新值后调用）
    func updateInterval() {
        guard isRunning, !isPaused else { return }
        scheduleTimer()
    }

    // MARK: - LS Plist Monitoring

    /// LaunchServices 安全数据库路径（默认应用的真实存储位置）
    private var lsPlistPath: String {
        NSHomeDirectory()
            + "/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
    }

    /// 监控 LS secure plist 文件变化：默认应用被篡改（无论通过何种方式）
    /// 最终都会写入该文件，文件一变立即触发检查，比定时轮询更及时。
    private func startPlistMonitoring() {
        stopPlistMonitoring()
        plistFileDescriptor = open(lsPlistPath, O_EVTONLY)
        guard plistFileDescriptor >= 0 else { return }

        plistMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: plistFileDescriptor,
            eventMask: [.write, .extend, .delete],
            queue: .main
        )
        plistMonitor?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.performCheck()
            }
        }
        plistMonitor?.resume()
    }

    private func stopPlistMonitoring() {
        plistMonitor?.cancel()
        plistMonitor = nil
        if plistFileDescriptor >= 0 {
            close(plistFileDescriptor)
            plistFileDescriptor = -1
        }
    }

    // MARK: - Check Logic

    private func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        let associations = persistence.loadAssociations()
        let lockedItems = associations.filter { $0.isLocked }

        for var item in lockedItems {
            // 检查目标应用是否存在
            if item.targetApplicationPath != nil {
                let pathExists = FileManager.default.fileExists(atPath: item.targetApplicationPath!)
                if !pathExists {
                    // 目标应用不存在
                    item.status = .targetApplicationMissing
                    item.updatedAt = Date()
                    persistence.saveAssociations(
                        associations.map { $0.id == item.id ? item : $0 }
                    )
                    continue
                }
            }

            // 查询当前默认应用
            guard let currentApp = associationService.getDefaultApplication(forUTI: item.uti) else {
                continue
            }

            // 更新检查时间
            item.lastCheckedAt = Date()

            // 对比（LaunchServices 的 bundle id 为全小写，忽略大小写比较）
            if currentApp.bundleIdentifier.lowercased() == item.targetBundleIdentifier.lowercased() {
                // 一致：恢复正常状态
                if item.status != .normal {
                    item.status = .normal
                    item.updatedAt = Date()
                }
            } else {
                // 不一致：尝试恢复
                item.status = .changed
                let startTime = Date()

                do {
                    try await associationService.setDefaultApplication(
                        bundleIdentifier: item.targetBundleIdentifier,
                        forUTI: item.uti
                    )
                    let duration = Date().timeIntervalSince(startTime)

                    item.status = .normal
                    item.lastRestoredAt = Date()
                    item.updatedAt = Date()

                    // 写入历史记录
                    let history = AssociationHistory(
                        associationID: item.id,
                        fileExtension: item.fileExtension,
                        expectedApplicationName: item.targetApplicationName,
                        expectedBundleIdentifier: item.targetBundleIdentifier,
                        detectedApplicationName: currentApp.name,
                        detectedBundleIdentifier: currentApp.bundleIdentifier,
                        result: .restored,
                        duration: duration,
                        createdAt: Date()
                    )
                    persistence.appendHistory(history)

                    // 发送通知
                    sendRestoreSuccessNotification(ext: item.fileExtension, appName: item.targetApplicationName)

                } catch {
                    let duration = Date().timeIntervalSince(startTime)
                    item.status = .restoreFailed
                    item.updatedAt = Date()

                    let history = AssociationHistory(
                        associationID: item.id,
                        fileExtension: item.fileExtension,
                        expectedApplicationName: item.targetApplicationName,
                        expectedBundleIdentifier: item.targetBundleIdentifier,
                        detectedApplicationName: currentApp.name,
                        detectedBundleIdentifier: currentApp.bundleIdentifier,
                        result: .failed,
                        errorMessage: error.localizedDescription,
                        duration: duration,
                        createdAt: Date()
                    )
                    persistence.appendHistory(history)

                    sendRestoreFailedNotification(ext: item.fileExtension, appName: item.targetApplicationName)
                }
            }

            // 保存更新后的关联状态
            persistence.saveAssociations(
                associations.map { $0.id == item.id ? item : $0 }
            )
        }

        // 文件级检查
        let managedFiles = persistence.loadManagedFiles()
        let lockedFiles = managedFiles.filter { $0.isLocked }
        var anyFileRestored = false
        for var file in lockedFiles {
            await checkFile(&file, restored: &anyFileRestored)
            persistence.saveManagedFiles(
                managedFiles.map { $0.id == file.id ? file : $0 }
            )
        }
        // 若本次有文件级恢复，刷新 Finder 缓存，让双击立即使用新打开方式
        if anyFileRestored {
            _ = try? await CommandRunner.runAsync(
                executablePath: "/usr/bin/killall",
                arguments: ["Finder"],
                timeout: 5
            )
        }
    }

    /// 检查单个文件：若被单独设置了打开方式（存在 OpenWith xattr），则清除，
    /// 让文件回退跟随全局默认（这是 macOS 上唯一可靠的 per-file 保护方式）
    private func checkFile(_ file: inout ManagedFile, restored: inout Bool) async {
        // 文件不存在
        guard FileManager.default.fileExists(atPath: file.filePath) else {
            file.status = .targetApplicationMissing
            file.updatedAt = Date()
            return
        }

        file.lastCheckedAt = Date()

        let currentBundleID = associationService.getOpenWithBundleIdentifier(forFile: file.filePath)

        // 无单文件覆盖 → 跟随全局默认 → 正常
        if currentBundleID == nil {
            if file.status != .normal {
                file.status = .normal
                file.updatedAt = Date()
            }
            return
        }

        // 存在单文件覆盖 → 视为被单独改 → 清除，回退全局默认
        file.status = .changed
        let startTime = Date()

        associationService.clearOpenWith(forFile: file.filePath)
        file.status = .normal
        file.updatedAt = Date()
        restored = true

        let duration = Date().timeIntervalSince(startTime)
        let history = AssociationHistory(
            associationID: file.id,
            fileExtension: file.fileExtension,
            filePath: file.filePath,
            expectedApplicationName: isChineseUI() ? "跟随全局默认" : "Follow Global Default",
            expectedBundleIdentifier: "",
            detectedApplicationName: currentBundleID,
            detectedBundleIdentifier: currentBundleID,
            result: .restored,
            duration: duration,
            createdAt: Date()
        )
        persistence.appendHistory(history)
    }

    // MARK: - Notifications

    private func sendRestoreSuccessNotification(ext: String, appName: String) {
        guard showNotifications else { return }
        let isChinese = isChineseUI()

        let content = UNMutableNotificationContent()
        content.title = isChinese
            ? "已恢复 .\(ext) 的默认应用"
            : "Restored Default App for .\(ext)"
        content.body = isChinese
            ? "默认应用已恢复为\"\(appName)\"。"
            : "Default app restored to \"\(appName)\"."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendRestoreFailedNotification(ext: String, appName: String) {
        guard showNotifications else { return }
        let isChinese = isChineseUI()

        let content = UNMutableNotificationContent()
        content.title = isChinese
            ? "无法恢复 .\(ext) 的默认应用"
            : "Failed to Restore Default App for .\(ext)"
        content.body = isChinese
            ? "目标应用\"\(appName)\"可能已被删除。"
            : "Target app \"\(appName)\" may have been deleted."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
