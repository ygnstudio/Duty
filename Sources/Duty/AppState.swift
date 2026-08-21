import Foundation
import AppKit
import SwiftUI
import Combine

/// 主窗口标签页
enum MainTab: String, CaseIterable, Identifiable {
    case global      // 文件类型（全局）
    case file        // 指定文件（文件级）
    var id: String { rawValue }
}

/// 全局应用状态
/// 使用 ObservableObject + @Published 实现响应式绑定
@MainActor
final class AppState: ObservableObject {
    // MARK: - Services

    let persistence = PersistenceController.shared
    let associationService = AssociationService.shared
    let protectionService = ProtectionService.shared
    let extensionCatalog = ExtensionCatalog.shared

    // Combine 订阅（用于转发内部服务的 objectWillChange）
    private var cancellables: Set<AnyCancellable> = []

    // duti 目录监控（自动检测运行中安装/卸载 duti）
    private var dutiDirectorySources: [DispatchSourceFileSystemObject] = []
    private var dutiRefreshPending = false

    // MARK: - Data

    @Published var associations: [ManagedAssociation] = []
    @Published var managedFiles: [ManagedFile] = []
    @Published var history: [AssociationHistory] = []
    @Published var mainTab: MainTab = .global

    // MARK: - UI State

    @Published var isMainWindowOpen = false
    @Published var showAddSheet = false
    @Published var showAddFileSheet = false
    @Published var showHistory = false
    @Published var showSettings = false
    @Published var selectedAssociation: ManagedAssociation?
    @Published var selectedFile: ManagedFile?
    @Published var editingAssociation: ManagedAssociation?
    @Published var dutiInstalled = false
    @Published var homebrewInstalled = false

    // MARK: - Error State

    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Init

    init() {
        migrateLegacyUserDefaults()

        // 转发 ProtectionService 的状态变化，
        // 避免 SwiftUI "嵌套 ObservableObject" 不自动响应的陷阱：
        // 视图只观察 appState，但会访问 appState.protectionService.isRunning 等，
        // 若不转发，按钮点击 pause/resume 后视图不会刷新。
        protectionService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        refreshDutiStatus()
        startDutiDirectoryWatch()
        loadData()
        applyAppearance()   // 启动时应用外观设置
        startProtectionIfNeeded()   // 静默启动（不开主窗口）时也要生效
    }

    /// 启动时自动开启保护（需在 loadData 之后调用，依赖已加载的锁定项）
    private func startProtectionIfNeeded() {
        let hasLockedItems = associations.contains(where: \.isLocked)
            || managedFiles.contains(where: \.isLocked)
        if hasLockedItems || protectionService.autoStartProtection {
            protectionService.start()
        }
    }

    // MARK: - duti Auto Detection

    /// 监控 brew bin 目录变化：应用运行中 brew install/uninstall duti 后自动刷新状态，
    /// 无需重启。事件做 0.5s 去抖（brew 一次安装/卸载会触发多次目录写入）。
    private func startDutiDirectoryWatch() {
        let binDirs = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]
        for dir in binDirs {
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                guard let self, !self.dutiRefreshPending else { return }
                self.dutiRefreshPending = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    self.dutiRefreshPending = false
                    self.refreshDutiStatus()
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            dutiDirectorySources.append(source)
        }
    }

    // MARK: - Legacy Migration

    /// 应用由 DutiUI 更名为 Duty：bundle id 变化导致 UserDefaults 域变化，
    /// 首次启动时把旧域（com.ygnstudio.DutiUI）的设置一次性拷贝到新域
    private func migrateLegacyUserDefaults() {
        let migratedKey = "didMigrateFromDutiUI"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey),
              let legacy = UserDefaults(suiteName: "com.ygnstudio.DutiUI") else { return }
        let keys = [
            "launchAtLogin", "autoStartProtection", "checkInterval",
            "showNotifications", "showAppRecommendations", "defaultLockOnAdd",
            "appLanguage", "maxHistoryRecords", "historyEnabled", "appearance",
        ]
        for key in keys {
            if let value = legacy.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migratedKey)
    }

    // MARK: - Data Loading

    func loadData() {
        associations = persistence.loadAssociations()
        managedFiles = persistence.loadManagedFiles()
        history = persistence.loadHistory()
    }

    func refreshDutiStatus() {
        dutiInstalled = DutiDetector.isDutiInstalled()
        homebrewInstalled = DutiDetector.isHomebrewInstalled()
        associationService.refreshDutiPath()
    }

    // MARK: - Association Management

    /// 添加新的管理项
    func addAssociation(
        fileExtension: String,
        displayName: String,
        uti: String,
        targetApp: AppInfo,
        isLocked: Bool
    ) {
        let normalized = ManagedAssociation.normalizeExtension(fileExtension)

        // 检查是否已存在
        guard !associations.contains(where: { $0.fileExtension == normalized }) else {
            showErrorMessage(
                isChineseUI()
                    ? "已存在 .\(normalized) 的管理项"
                    : "A managed item for .\(normalized) already exists"
            )
            return
        }

        let association = ManagedAssociation(
            fileExtension: normalized,
            displayName: displayName,
            uti: uti,
            targetApplicationName: targetApp.name,
            targetBundleIdentifier: targetApp.bundleIdentifier,
            targetApplicationPath: targetApp.path,
            isLocked: isLocked,
            status: isLocked ? .normal : .unlocked
        )

        associations.append(association)
        save()
    }

    /// 更新管理项
    func updateAssociation(_ association: ManagedAssociation) {
        guard let index = associations.firstIndex(where: { $0.id == association.id }) else { return }
        var updated = association
        updated.updatedAt = Date()
        associations[index] = updated
        save()
    }

    /// 删除管理项（不修改系统默认应用）
    func deleteAssociation(_ association: ManagedAssociation) {
        associations.removeAll { $0.id == association.id }
        save()
    }

    /// 切换锁定状态
    func toggleLock(for association: ManagedAssociation) {
        guard let index = associations.firstIndex(where: { $0.id == association.id }) else { return }
        var updated = associations[index]
        updated.isLocked.toggle()
        updated.status = updated.isLocked ? .normal : .unlocked
        updated.updatedAt = Date()

        if updated.isLocked {
            // 锁定开启时，刷新最后恢复时间
            updated.lastCheckedAt = Date()
        }

        associations[index] = updated
        save()
    }

    /// 为一个关联设置新的默认应用并写入系统
    func setDefaultApp(for association: ManagedAssociation, to app: AppInfo) async {
        guard let index = associations.firstIndex(where: { $0.id == association.id }) else { return }

        do {
            try await associationService.setDefaultApplication(
                bundleIdentifier: app.bundleIdentifier,
                forUTI: association.uti
            )

            var updated = associations[index]
            updated.targetApplicationName = app.name
            updated.targetBundleIdentifier = app.bundleIdentifier
            updated.targetApplicationPath = app.path
            updated.updatedAt = Date()

            if updated.isLocked {
                updated.status = .normal
            }

            associations[index] = updated
            save()

        } catch {
            showErrorMessage(
                isChineseUI()
                    ? "无法修改 .\(association.fileExtension) 的默认应用"
                    : "Failed to change default app for .\(association.fileExtension)"
            )
        }
    }

    // MARK: - Managed File

    /// 添加文件级管理项（文件级锁定 = 保持跟随全局默认，防被单独改到别的 app）
    func addFile(filePath: String, isLocked: Bool) {
        guard !managedFiles.contains(where: { $0.filePath == filePath }) else {
            showErrorMessage(isChineseUI() ? "已添加该文件" : "This file is already managed")
            return
        }
        let file = ManagedFile(
            filePath: filePath,
            targetBundleIdentifier: "",
            targetApplicationName: isChineseUI() ? "跟随全局默认" : "Follow Global Default",
            isLocked: isLocked,
            status: isLocked ? .normal : .unlocked
        )
        managedFiles.append(file)
        saveManagedFiles()
    }

    /// 删除文件级管理项
    func deleteFile(_ file: ManagedFile) {
        managedFiles.removeAll { $0.id == file.id }
        saveManagedFiles()
    }

    /// 切换文件级锁定状态
    func toggleFileLock(for file: ManagedFile) {
        guard let index = managedFiles.firstIndex(where: { $0.id == file.id }) else { return }
        var updated = managedFiles[index]
        updated.isLocked.toggle()
        updated.status = updated.isLocked ? .normal : .unlocked
        updated.updatedAt = Date()
        managedFiles[index] = updated
        saveManagedFiles()
    }

    /// 立即清除该文件的单文件覆盖，让其跟随全局默认
    func resetFileDefaultApp(for file: ManagedFile) async {
        guard let index = managedFiles.firstIndex(where: { $0.id == file.id }) else { return }
        await associationService.resetFileOpenWith(forFile: file.filePath)
        var updated = managedFiles[index]
        updated.updatedAt = Date()
        updated.status = .normal
        managedFiles[index] = updated
        saveManagedFiles()
    }

    // MARK: - Save

    func save() {
        persistence.saveAssociations(associations)
    }

    func saveManagedFiles() {
        persistence.saveManagedFiles(managedFiles)
    }

    // MARK: - Error

    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        errorMessage = nil
        showError = false
    }

    // MARK: - Language

    /// 界面语言已切换：广播一次状态变化，强制所有观察 appState 的视图重绘，
    /// 使 isChineseUI() 读取到新的 UserDefaults 值，界面文本立即切换
    func refreshLanguage() {
        objectWillChange.send()
    }
}
