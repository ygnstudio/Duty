import SwiftUI

struct AddFileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var selectedPath = OptionalStateValue<String>()
    @StateObject private var isLocked = StateValue(true)
    @AppStorage("defaultLockOnAdd") private var defaultLockOnAdd = true

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(isChineseUI() ? "文件" : "File") {
                    if let path = selectedPath.value {
                        LabeledContent(isChineseUI() ? "已选择" : "Selected") {
                            HStack(spacing: 6) {
                                Text((path as NSString).lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button(isChineseUI() ? "重新选择" : "Reselect") {
                                    selectFile()
                                }
                                .controlSize(.small)
                            }
                        }
                        LabeledContent(isChineseUI() ? "路径" : "Path") {
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                        }
                    } else {
                        Button {
                            selectFile()
                        } label: {
                            Label(
                                isChineseUI() ? "选择文件…" : "Choose File…",
                                systemImage: "folder"
                            )
                        }
                    }
                }

                Section {
                    Toggle(isOn: $isLocked.value) {
                        Text(isChineseUI() ? "锁定此文件" : "Lock This File")
                    }
                    .toggleStyle(.checkbox)
                } footer: {
                    Text(isChineseUI()
                        ? "锁定后，该文件若被单独改到其他应用打开（如右键「始终用…打开」），Duty 会自动清除覆盖，让文件跟随全局默认应用。"
                        : "When locked, if this file is set to open with another app (e.g. via \"Always Open With\"), Duty clears the override so the file follows the global default."
                    )
                    .font(.caption)
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

                Button(isChineseUI() ? "添加" : "Add") {
                    save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(selectedPath.value == nil)
            }
            .padding(16)
        }
        .frame(width: 460, height: 330)
        .onAppear {
            // 锁定开关初始值跟随设置项「添加时默认锁定」
            isLocked.value = defaultLockOnAdd
        }
    }

    // MARK: - Actions

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = isChineseUI() ? "选择" : "Select"
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath.value = url.path
        }
    }

    private func save() {
        guard let path = selectedPath.value else { return }

        // 已存在：提示回列表修改，不关窗
        guard !appState.managedFiles.contains(where: { $0.filePath == path }) else {
            appState.showErrorMessage(
                isChineseUI()
                    ? "该文件已在管理列表中。\n\n请回到列表中修改它的设置。"
                    : "This file is already in the managed list.\n\nGo back to the list to change its settings."
            )
            return
        }

        if isLocked.value {
            // 锁定：先清除该文件现有覆盖，让其跟随全局默认
            Task {
                await appState.associationService.resetFileOpenWith(forFile: path)
                appState.addFile(filePath: path, isLocked: true)
                dismiss()
            }
        } else {
            appState.addFile(filePath: path, isLocked: false)
            dismiss()
        }
    }
}
