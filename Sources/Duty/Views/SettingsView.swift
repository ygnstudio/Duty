import SwiftUI
import AppKit
import ServiceManagement

/// 检查间隔单位
private enum IntervalUnit {
    case millisecond
    case second
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    // 设置项（使用 @AppStorage 自动持久化，在 SwiftUI View 中可用）
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStartProtection") private var autoStartProtection = true
    @AppStorage("checkInterval") private var checkInterval: Double = 10
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("showAppRecommendations") private var showAppRecommendations = true
    @AppStorage("defaultLockOnAdd") private var defaultLockOnAdd = true
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("maxHistoryRecords") private var maxHistoryRecords = 500
    @AppStorage("historyEnabled") private var historyEnabled = false
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    @StateObject private var loginItemError = OptionalStateValue<String>()
    @StateObject private var intervalInput = StateValue("10")
    @StateObject private var intervalUnit = StateValue(IntervalUnit.second)
    @StateObject private var showDisableHistoryAlert = StateValue(false)
    @StateObject private var confirmingDisableHistory = StateValue(false)
    @StateObject private var showDutiGuide = StateValue(false)
    @StateObject private var showUninstallConfirm = StateValue(false)
    @StateObject private var uninstallingDuti = StateValue(false)
    @StateObject private var uninstallError = OptionalStateValue<String>()

    var body: some View {
        Form {
            // 常规设置
            Section {
                // 登录时启动
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "登录时启动" : "Launch at Login")
                        Text(isChineseUI()
                            ? "登录后自动在后台启动 Duty"
                            : "Automatically start Duty in the background after login"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { newValue in
                    setLoginItem(enabled: newValue)
                }

                if let error = loginItemError.value {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // 启动时自动开启保护
                Toggle(isOn: $autoStartProtection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "启动时自动开启保护" : "Auto-start Protection")
                        Text(isChineseUI()
                            ? "启动后自动监控已锁定的文件关联"
                            : "Start monitoring locked associations after launch"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // 显示通知
                Toggle(isOn: $showNotifications) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "显示恢复通知" : "Show Restore Notifications")
                        Text(isChineseUI()
                            ? "当默认应用被自动恢复时发送通知"
                            : "Send a notification when default apps are auto-restored"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // 推荐应用
                Toggle(isOn: $showAppRecommendations) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "推荐应用" : "Suggest Applications")
                        Text(isChineseUI()
                            ? "选择默认应用时显示可打开该类型的应用列表"
                            : "Show apps that can open the file type when choosing a default app"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // 添加时默认锁定
                Toggle(isOn: $defaultLockOnAdd) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "添加时默认锁定" : "Lock by Default")
                        Text(isChineseUI()
                            ? "新建管理项时默认开启「锁定此关联」"
                            : "Turn on \"Lock This Association\" by default for new items"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // 检查间隔（数字输入 + 毫秒/秒单位）
                LabeledContent(isChineseUI() ? "检查间隔" : "Check Interval") {
                    HStack(spacing: 6) {
                        TextField("", text: $intervalInput.value)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: intervalInput.value) { newValue in
                                // 只保留数字与小数点
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    intervalInput.value = filtered
                                    return
                                }
                                applyIntervalInput()
                            }

                        Picker("", selection: $intervalUnit.value) {
                            Text(isChineseUI() ? "毫秒" : "ms").tag(IntervalUnit.millisecond)
                            Text(isChineseUI() ? "秒" : "s").tag(IntervalUnit.second)
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        .onChange(of: intervalUnit.value) { _ in
                            applyIntervalInput()
                        }
                    }
                }

                // 记录历史（默认关闭；关闭时若有记录需确认，确认后清空）
                Toggle(isOn: $historyEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isChineseUI() ? "记录历史" : "Record History")
                        Text(isChineseUI()
                            ? "记录默认应用的自动恢复历史"
                            : "Record the history of auto-restored default apps"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: historyEnabled) { newValue in
                    // 关闭且存在记录时：先回弹，弹确认框（确认后真正关闭并清空）
                    if !newValue && !confirmingDisableHistory.value && !appState.history.isEmpty {
                        historyEnabled = true
                        showDisableHistoryAlert.value = true
                    }
                }

                // 历史记录上限
                Picker(isChineseUI() ? "历史记录上限" : "History Limit", selection: $maxHistoryRecords) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("5000").tag(5000)
                }
                .disabled(!historyEnabled)
            } header: {
                Text(isChineseUI() ? "常规" : "General")
            }

            // 外观设置
            Section {
                // 界面语言
                Picker(isChineseUI() ? "界面语言" : "Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .onChange(of: appLanguage) { _ in
                    // 广播状态变化，让所有界面立即切换到新语言
                    appState.refreshLanguage()
                }

                // 外观（深浅色）
                Picker(isChineseUI() ? "外观" : "Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance.rawValue)
                    }
                }
                .onChange(of: appearance) { newValue in
                    applyAppearance(newValue)
                }
            } header: {
                Text(isChineseUI() ? "外观" : "Appearance")
            }

            // 增强组件（可选）
            Section {
                LabeledContent("duti") {
                    HStack(spacing: 8) {
                        if appState.dutiInstalled {
                            Label(
                                isChineseUI() ? "已安装" : "Installed",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                        } else {
                            Text(isChineseUI() ? "未安装" : "Not Installed")
                                .foregroundStyle(.secondary)
                            Text(isChineseUI() ? "可选" : "Optional")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }

                        Button {
                            appState.refreshDutiStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(isChineseUI() ? "重新检测" : "Check Again")
                    }
                }

                if appState.dutiInstalled, let path = appState.associationService.currentDutiPath {
                    LabeledContent(isChineseUI() ? "duti 路径" : "duti Path") {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if appState.dutiInstalled {
                    HStack(spacing: 8) {
                        Button(isChineseUI() ? "卸载 duti…" : "Uninstall duti…") {
                            showUninstallConfirm.value = true
                        }
                        .disabled(uninstallingDuti.value)

                        if uninstallingDuti.value {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let error = uninstallError.value {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if !appState.dutiInstalled {
                    Button(isChineseUI() ? "安装 duti…" : "Install duti…") {
                        showDutiGuide.value = true
                    }
                }
            } header: {
                Text(isChineseUI() ? "增强组件" : "Enhancements")
            } footer: {
                Text(isChineseUI()
                    ? "duti 是可选组件，仅帮助识别系统未知的冷门文件类型。Duty 的核心功能无需安装它。"
                    : "duti is optional and only helps recognize rare file types unknown to the system. Duty's core features work without it."
                )
            }

            // 关于
            Section {
                LabeledContent("Duty") {
                    Text("v1.0")
                        .foregroundStyle(.secondary)
                }

                // 重看首次引导（重置标记并立即打开引导窗口）
                Button(isChineseUI() ? "重新显示引导" : "Show Welcome Guide Again") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                }
            } header: {
                Text(isChineseUI() ? "关于" : "About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 500)
        .sheet(isPresented: $showDutiGuide.value) {
            DutiNotInstalledView()
                .environmentObject(appState)
        }
        .task {
            // 同步初始状态
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncIntervalInputFromStorage()
        }
        .alert(
            isChineseUI() ? "关闭记录历史？" : "Turn Off History?",
            isPresented: $showDisableHistoryAlert.value
        ) {
            Button(isChineseUI() ? "取消" : "Cancel", role: .cancel) {}
            Button(isChineseUI() ? "关闭并清空" : "Turn Off & Clear", role: .destructive) {
                confirmingDisableHistory.value = true
                historyEnabled = false
                confirmingDisableHistory.value = false
                appState.persistence.clearHistory()
                appState.history = []
            }
        } message: {
            Text(isChineseUI()
                ? "关闭记录历史将清空所有已有记录，该操作不可撤销。"
                : "Turning off history will erase all existing records. This cannot be undone."
            )
        }
        .alert(
            isChineseUI() ? "卸载 duti？" : "Uninstall duti?",
            isPresented: $showUninstallConfirm.value
        ) {
            Button(isChineseUI() ? "取消" : "Cancel", role: .cancel) {}
            Button(isChineseUI() ? "卸载" : "Uninstall", role: .destructive) {
                Task { await uninstallDuti() }
            }
        } message: {
            Text(isChineseUI()
                ? "将运行 brew uninstall duti。duti 是可选组件，卸载不影响 Duty 的核心功能，可随时重新安装。"
                : "This runs brew uninstall duti. duti is optional — removing it does not affect Duty's core features, and you can reinstall it anytime."
            )
        }
    }

    // MARK: - Uninstall duti

    private func uninstallDuti() async {
        uninstallError.value = nil
        guard let brewPath = DutiDetector.findBrewPath() else {
            uninstallError.value = isChineseUI()
                ? "找不到 brew 可执行文件，无法自动卸载。"
                : "brew executable not found; cannot uninstall automatically."
            return
        }

        uninstallingDuti.value = true
        defer { uninstallingDuti.value = false }

        do {
            let result = try await DutiDetector.uninstallDuti(brewPath: brewPath)
            if result.isSuccess {
                appState.refreshDutiStatus()
            } else {
                let log = result.standardError.isEmpty ? result.standardOutput : result.standardError
                uninstallError.value = (isChineseUI() ? "卸载失败：" : "Uninstall failed: ") + log
            }
        } catch {
            uninstallError.value = error.localizedDescription
        }
    }

    // MARK: - Check Interval Input

    /// 把存储的秒数回填到输入框与单位（< 1 秒用毫秒显示）
    private func syncIntervalInputFromStorage() {
        if checkInterval < 1 {
            intervalUnit.value = .millisecond
            intervalInput.value = String(Int((checkInterval * 1000).rounded()))
        } else {
            intervalUnit.value = .second
            intervalInput.value = checkInterval.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(checkInterval))
                : String(checkInterval)
        }
    }

    /// 解析输入并按单位换算为秒写回（范围 0.1s ~ 3600s）
    private func applyIntervalInput() {
        guard let raw = Double(intervalInput.value), raw > 0 else { return }
        let seconds = intervalUnit.value == .millisecond ? raw / 1000 : raw
        let clamped = min(max(seconds, 0.1), 3600)
        guard clamped != checkInterval else { return }
        checkInterval = clamped
        appState.protectionService.updateInterval()
    }

    // MARK: - Login Item

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError.value = nil
        } catch {
            loginItemError.value = error.localizedDescription
            // 回滚 UI
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
