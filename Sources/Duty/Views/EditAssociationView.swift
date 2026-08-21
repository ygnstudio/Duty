import SwiftUI

struct EditAssociationView: View {
    let extensionInfo: ExtensionInfo
    let onSave: (AppInfo, Bool) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var appState: AppState
    @AppStorage("showAppRecommendations") private var showRecommendations = true
    @AppStorage("defaultLockOnAdd") private var defaultLockOnAdd = true

    @StateObject private var selectedApp = OptionalStateValue<AppInfo>()
    @StateObject private var isLocked = StateValue(false)
    @StateObject private var uti = StateValue("")
    @StateObject private var currentDefaultApp = OptionalStateValue<AppInfo>()
    @StateObject private var appsCount = StateValue(0)

    /// 窗口动态高度：基础高度 + 列表高度（最多 3 行，超出滚动）
    private var sheetHeight: CGFloat {
        guard showRecommendations else { return 340 }
        let rows = min(max(appsCount.value, 1), 3)
        return 330 + CGFloat(rows) * 34 + 12
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent(isChineseUI() ? "文件类型" : "File Type") {
                        Text(".\(extensionInfo.ext) · \(extensionInfo.localizedDisplayName)")
                            .foregroundStyle(.secondary)
                    }

                    if let current = currentDefaultApp.value {
                        LabeledContent(isChineseUI() ? "当前默认" : "Current Default") {
                            HStack(spacing: 6) {
                                if let icon = current.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                }
                                Text(current.name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // 已选择的新应用（与当前默认不同时显示）
                    if let selected = selectedApp.value,
                       selected.bundleIdentifier.lowercased()
                           != currentDefaultApp.value?.bundleIdentifier.lowercased() {
                        LabeledContent(isChineseUI() ? "将设为默认" : "New Default") {
                            HStack(spacing: 6) {
                                if let icon = selected.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                }
                                Text(selected.name)
                            }
                        }
                    }
                }

                Section(isChineseUI() ? "选择默认应用" : "Default App") {
                    ApplicationPicker(
                        uti: uti.value,
                        selectedApp: $selectedApp.value,
                        onAppsCountChange: { count in appsCount.value = count }
                    )
                }

                Section {
                    Toggle(isOn: $isLocked.value) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isChineseUI() ? "锁定此关联" : "Lock This Association")
                            Text(isChineseUI()
                                ? "当关联被其他应用修改时，自动恢复"
                                : "Automatically restore when changed by other apps"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(selectedApp.value == nil)
                }
            }
            .formStyle(.grouped)

            Divider()

            // 底部按钮行（原生面板样式）
            HStack {
                Spacer()
                Button(isChineseUI() ? "取消" : "Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button(isChineseUI() ? "保存" : "Save") {
                    if let app = selectedApp.value {
                        onSave(app, isLocked.value)
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp.value == nil)
            }
            .padding(16)
        }
        .frame(width: 480, height: sheetHeight)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        // 锁定开关初始值跟随设置项「添加时默认锁定」
        isLocked.value = defaultLockOnAdd

        // 解析 UTI
        if let resolved = appState.associationService.resolveUTI(for: extensionInfo.ext) {
            uti.value = resolved
        } else if let preferred = extensionInfo.preferredUTI {
            uti.value = preferred
        }

        // 获取当前默认应用
        if !uti.value.isEmpty {
            currentDefaultApp.value = appState.associationService.getDefaultApplication(forUTI: uti.value)
            // 默认选中当前应用
            if selectedApp.value == nil {
                selectedApp.value = currentDefaultApp.value
            }
        }
    }
}
