import SwiftUI

struct AssociationListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var itemToDelete = OptionalStateValue<ManagedAssociation>()

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { itemToDelete.value != nil },
            set: { if !$0 { itemToDelete.value = nil } }
        )
    }

    var body: some View {
        Table(appState.associations) {
            TableColumn(isChineseUI() ? "文件类型" : "File Type") { association in
                cell(fileTypeCell(association), for: association)
            }
            .width(min: 120, ideal: 170)

            TableColumn(isChineseUI() ? "默认应用" : "Default App") { association in
                cell(appCell(association), for: association)
            }
            .width(min: 140, ideal: 200)

            TableColumn(isChineseUI() ? "锁定" : "Lock") { association in
                cell(lockToggle(association), for: association)
            }
            .width(min: 44, ideal: 44, max: 60)

            TableColumn(isChineseUI() ? "状态" : "Status") { association in
                cell(statusBadge(association), for: association)
            }
            .width(min: 80, ideal: 110)

            TableColumn(isChineseUI() ? "操作" : "Actions") { association in
                cell(actionButtons(association), for: association)
            }
            .width(min: 64, ideal: 64, max: 90)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .alert(
            isChineseUI() ? "删除管理项" : "Remove Managed Item",
            isPresented: deleteAlertPresented
        ) {
            Button(isChineseUI() ? "取消" : "Cancel", role: .cancel) {}
            Button(isChineseUI() ? "删除" : "Remove", role: .destructive) {
                if let assoc = itemToDelete.value {
                    appState.deleteAssociation(assoc)
                }
            }
        } message: {
            if let assoc = itemToDelete.value {
                Text(String(format:
                    isChineseUI()
                        ? "确定要删除 .%@ 的管理项吗？\n\n当前默认应用不会被修改。"
                        : "Remove .%@ from managed items?\n\nThe current default app will not be changed.",
                    assoc.fileExtension
                ))
            }
        }
    }

    // MARK: - Cells（单行 + 居中对齐，截断文本 tooltip 补全）

    private func fileTypeCell(_ association: ManagedAssociation) -> some View {
        HStack(spacing: 6) {
            Text(".\(association.fileExtension)")
                .fontWeight(.semibold)
            Text(association.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(".\(association.fileExtension) · \(association.displayName)")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appCell(_ association: ManagedAssociation) -> some View {
        HStack(spacing: 6) {
            appIconView(for: association)
            Text(association.targetApplicationName)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(association.targetBundleIdentifier)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockToggle(_ association: ManagedAssociation) -> some View {
        Toggle("", isOn: Binding(
            get: { association.isLocked },
            set: { _ in appState.toggleLock(for: association) }
        ))
        .labelsHidden()
        .toggleStyle(.checkbox)
        .help(isChineseUI() ? "锁定" : "Lock")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(_ association: ManagedAssociation) -> some View {
        AssociationStatusBadge(status: association.status)
            .help(association.status.displayName)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButtons(_ association: ManagedAssociation) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.selectedAssociation = association
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help(isChineseUI() ? "编辑" : "Edit")

            Button {
                itemToDelete.value = association
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(isChineseUI() ? "删除" : "Delete")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 统一包裹右键菜单
    @ViewBuilder
    private func cell<Content: View>(_ content: Content, for association: ManagedAssociation) -> some View {
        content.contextMenu {
            Button {
                appState.toggleLock(for: association)
            } label: {
                Label(
                    association.isLocked
                        ? (isChineseUI() ? "关闭锁定" : "Unlock")
                        : (isChineseUI() ? "开启锁定" : "Lock"),
                    systemImage: association.isLocked ? "lock.open" : "lock"
                )
            }

            Divider()

            Button(role: .destructive) {
                itemToDelete.value = association
            } label: {
                Label(
                    isChineseUI() ? "删除" : "Delete",
                    systemImage: "trash"
                )
            }
        }
    }

    // MARK: - App Icon

    @ViewBuilder
    private func appIconView(for association: ManagedAssociation) -> some View {
        if let path = association.targetApplicationPath,
           FileManager.default.fileExists(atPath: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Status Badge

/// 关联状态徽章（仅使用 SF Symbols 与系统语义色）
struct AssociationStatusBadge: View {
    let status: AssociationStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(status.displayName)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    private var iconName: String {
        switch status {
        case .normal: return "checkmark.circle.fill"
        case .unlocked: return "circle"
        case .changed: return "exclamationmark.triangle.fill"
        case .restoreFailed: return "xmark.circle.fill"
        case .targetApplicationMissing: return "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .normal: return .green
        case .unlocked: return .secondary
        case .changed: return .orange
        case .restoreFailed: return .red
        case .targetApplicationMissing: return .red
        }
    }
}

// MARK: - Edit Existing Association（原生 Form 面板）

struct EditExistingAssociationView: View {
    let association: ManagedAssociation
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showAppRecommendations") private var showRecommendations = true

    @StateObject private var selectedApp = OptionalStateValue<AppInfo>()
    @StateObject private var appsCount = StateValue(0)

    /// 窗口动态高度：基础高度 + 列表高度（最多 3 行，超出滚动）
    private var sheetHeight: CGFloat {
        guard showRecommendations else { return 300 }
        let rows = min(max(appsCount.value, 1), 3)
        return 250 + CGFloat(rows) * 34 + 12
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent(isChineseUI() ? "文件类型" : "File Type") {
                        Text(".\(association.fileExtension) · \(association.displayName)")
                            .foregroundStyle(.secondary)
                    }

                    // 已选择的新应用（与当前目标不同时显示）
                    if let selected = selectedApp.value,
                       selected.bundleIdentifier.lowercased()
                           != association.targetBundleIdentifier.lowercased() {
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

                Section(isChineseUI() ? "默认应用" : "Default App") {
                    ApplicationPicker(
                        uti: association.uti,
                        selectedApp: $selectedApp.value,
                        onAppsCountChange: { count in appsCount.value = count }
                    )
                }
            }
            .formStyle(.grouped)

            Divider()

            // 底部按钮行（原生面板样式）
            HStack {
                Spacer()
                Button(isChineseUI() ? "取消" : "Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(isChineseUI() ? "保存" : "Save") {
                    if let app = selectedApp.value {
                        Task {
                            await appState.setDefaultApp(for: association, to: app)
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp.value == nil)
            }
            .padding(16)
        }
        .frame(width: 480, height: sheetHeight)
        .onAppear {
            // 预选当前目标应用
            if selectedApp.value == nil {
                let icon: NSImage? = {
                    if let path = association.targetApplicationPath {
                        return NSWorkspace.shared.icon(forFile: path)
                    }
                    return nil
                }()
                selectedApp.value = AppInfo(
                    name: association.targetApplicationName,
                    bundleIdentifier: association.targetBundleIdentifier,
                    path: association.targetApplicationPath,
                    icon: icon
                )
            }
        }
    }
}
