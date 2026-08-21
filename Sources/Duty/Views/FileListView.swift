import SwiftUI

struct FileListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var itemToDelete = OptionalStateValue<ManagedFile>()

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { itemToDelete.value != nil },
            set: { if !$0 { itemToDelete.value = nil } }
        )
    }

    var body: some View {
        Table(appState.managedFiles) {
            TableColumn(isChineseUI() ? "文件" : "File") { file in
                cell(fileCell(file), for: file)
            }
            .width(min: 140, ideal: 220)

            TableColumn(isChineseUI() ? "打开方式" : "Open With") { file in
                cell(appCell(file), for: file)
            }
            .width(min: 120, ideal: 180)

            TableColumn(isChineseUI() ? "锁定" : "Lock") { file in
                cell(lockToggle(file), for: file)
            }
            .width(min: 44, ideal: 44, max: 60)

            TableColumn(isChineseUI() ? "状态" : "Status") { file in
                cell(statusBadge(file), for: file)
            }
            .width(min: 80, ideal: 110)

            TableColumn(isChineseUI() ? "操作" : "Actions") { file in
                cell(actionButtons(file), for: file)
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
                if let file = itemToDelete.value {
                    appState.deleteFile(file)
                }
            }
        } message: {
            if let file = itemToDelete.value {
                Text(String(format:
                    isChineseUI()
                        ? "确定要删除「%@」的管理项吗？\n\n不会修改任何系统设置。"
                        : "Remove \"%@\" from managed items?\n\nNo system settings will be changed.",
                    file.displayName
                ))
            }
        }
    }

    // MARK: - Cells（单行 + 左对齐与表头一致，tooltip 补全）

    private func fileCell(_ file: ManagedFile) -> some View {
        HStack(spacing: 6) {
            Text(file.displayName)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(file.filePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(file.filePath)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appCell(_ file: ManagedFile) -> some View {
        HStack(spacing: 6) {
            appIconView(for: file)
            Text(file.targetApplicationName)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(file.targetApplicationName)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockToggle(_ file: ManagedFile) -> some View {
        Toggle("", isOn: Binding(
            get: { file.isLocked },
            set: { _ in appState.toggleFileLock(for: file) }
        ))
        .labelsHidden()
        .toggleStyle(.checkbox)
        .help(isChineseUI() ? "锁定" : "Lock")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(_ file: ManagedFile) -> some View {
        AssociationStatusBadge(status: file.status)
            .help(file.status.displayName)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButtons(_ file: ManagedFile) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.selectedFile = file
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help(isChineseUI() ? "编辑" : "Edit")

            Button {
                itemToDelete.value = file
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
    private func cell<Content: View>(_ content: Content, for file: ManagedFile) -> some View {
        content.contextMenu {
            Button {
                appState.toggleFileLock(for: file)
            } label: {
                Label(
                    file.isLocked
                        ? (isChineseUI() ? "关闭锁定" : "Unlock")
                        : (isChineseUI() ? "开启锁定" : "Lock"),
                    systemImage: file.isLocked ? "lock.open" : "lock"
                )
            }

            Divider()

            Button(role: .destructive) {
                itemToDelete.value = file
            } label: {
                Label(isChineseUI() ? "删除" : "Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - App Icon

    @ViewBuilder
    private func appIconView(for file: ManagedFile) -> some View {
        if file.targetBundleIdentifier.isEmpty {
            Image(systemName: "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: file.targetBundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Edit File（原生 Form 面板：清除单文件覆盖）

struct EditFileView: View {
    let file: ManagedFile
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(isChineseUI() ? "文件" : "File") {
                    LabeledContent(isChineseUI() ? "名称" : "Name") {
                        Text(file.displayName)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent(isChineseUI() ? "路径" : "Path") {
                        Text(file.filePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(file.filePath)
                    }
                }

                Section {
                    Text(isChineseUI()
                        ? "此文件当前可能被单独设置了打开方式。点击下方按钮可清除单文件覆盖，让该文件回退到按扩展名的全局默认应用打开。"
                        : "This file may have a per-file open-with override. Clear it below to make the file follow the global default app for its type."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            // 底部按钮行
            HStack {
                Spacer()
                Button(isChineseUI() ? "取消" : "Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button {
                    Task {
                        await appState.resetFileDefaultApp(for: file)
                        dismiss()
                    }
                } label: {
                    Label(
                        isChineseUI() ? "清除覆盖" : "Clear Override",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 460, height: 320)
    }
}
