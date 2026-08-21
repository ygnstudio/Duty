import SwiftUI

struct AddAssociationSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var searchText = StateValue("")
    @StateObject private var searchResults = StateValue<[ExtensionInfo]>([])
    @StateObject private var selectedExtension = OptionalStateValue<ExtensionInfo>()
    @StateObject private var showEditView = StateValue(false)
    @StateObject private var showCustomError = StateValue(false)
    @StateObject private var customErrorMessage = StateValue("")
    @StateObject private var showDuplicateAlert = StateValue(false)
    @StateObject private var duplicateExt = StateValue("")
    @StateObject private var showDutiGuide = StateValue(false)

    private let categories = ["document", "image", "video", "audio", "archive", "development"]

    var body: some View {
        Group {
            if let ext = selectedExtension.value, showEditView.value {
                EditAssociationView(
                    extensionInfo: ext,
                    onSave: { app, isLocked in
                        handleSave(ext: ext, app: app, isLocked: isLocked)
                    },
                    onCancel: {
                        showEditView.value = false
                    }
                )
            } else {
                searchContainer
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .sheet(isPresented: $showDutiGuide.value) {
            DutiNotInstalledView()
                .environmentObject(appState)
        }
        .alert(
            isChineseUI() ? "该文件类型已在管理中" : "Already Managed",
            isPresented: $showDuplicateAlert.value
        ) {
            Button(isChineseUI() ? "好的" : "OK", role: .cancel) {}
        } message: {
            Text(String(format:
                isChineseUI()
                    ? ".%@ 已在管理列表中。\n\n请回到列表中修改它的默认应用。"
                    : ".%@ is already in the managed list.\n\nGo back to the list to change its default app.",
                duplicateExt.value
            ))
        }
    }

    // MARK: - Duplicate Check

    private func isManaged(_ ext: String) -> Bool {
        let normalized = ManagedAssociation.normalizeExtension(ext)
        return appState.associations.contains { $0.fileExtension == normalized }
    }

    private func selectExtension(_ item: ExtensionInfo) {
        if isManaged(item.ext) {
            duplicateExt.value = item.ext
            showDuplicateAlert.value = true
        } else {
            selectedExtension.value = item
            showEditView.value = true
        }
    }

    // MARK: - Search Container（原生 searchable + 分区 List）

    private var searchContainer: some View {
        NavigationStack {
            Group {
                if searchText.value.isEmpty {
                    categoryListView
                } else if searchResults.value.isEmpty {
                    noResultsView
                } else {
                    resultsListView
                }
            }
            .navigationTitle(isChineseUI() ? "添加文件类型" : "Add File Type")
            .searchable(
                text: $searchText.value,
                prompt: isChineseUI() ? "搜索扩展名或文件类型" : "Search extensions or file types"
            )
            .onChange(of: searchText.value) { newValue in
                searchResults.value = appState.extensionCatalog.search(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChineseUI() ? "关闭" : "Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
    }

    // MARK: - Category List（未输入时按分类浏览）

    private var categoryListView: some View {
        List {
            ForEach(categories, id: \.self) { category in
                let items = appState.extensionCatalog.search(category)
                if !items.isEmpty {
                    Section(items.first!.localizedCategory) {
                        ForEach(items) { item in
                            extensionRow(item)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Results List（结果 + 常驻自定义扩展名入口）

    private var resultsListView: some View {
        List {
            ForEach(searchResults.value) { item in
                extensionRow(item)
            }

            // 搜索词本身可作为自定义扩展名（未管理且不在结果中时显示）
            if showCustomOption {
                Section {
                    Button {
                        addCustomExtension()
                    } label: {
                        Label(
                            String(format:
                                isChineseUI()
                                    ? "添加自定义扩展名「.%@」"
                                    : "Add Custom Extension \".%@\"",
                                normalizedSearch
                            ),
                            systemImage: "plus"
                        )
                    }

                    if showCustomError.value {
                        customErrorView
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var normalizedSearch: String {
        ManagedAssociation.normalizeExtension(searchText.value)
    }

    private var showCustomOption: Bool {
        // 常驻显示（精确命中时也显示，保证入口位置可预期），已管理的除外
        !normalizedSearch.isEmpty && !isManaged(normalizedSearch)
    }

    private func extensionRow(_ item: ExtensionInfo) -> some View {
        Button {
            selectExtension(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: fileTypeIcon(for: item.category))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.localizedDisplayName)
                    Text(".\(item.ext)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isManaged(item.ext) {
                    Text(isChineseUI() ? "已添加" : "Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Results（搜索词可直接作为自定义扩展名）

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "questionmark.folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(isChineseUI()
                ? "未找到匹配的文件类型"
                : "No matching file types found"
            )
            .foregroundStyle(.secondary)

            Button {
                addCustomExtension()
            } label: {
                Label(
                    String(format:
                        isChineseUI()
                            ? "添加自定义扩展名「.%@」"
                            : "Add Custom Extension \".%@\"",
                        ManagedAssociation.normalizeExtension(searchText.value)
                    ),
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(ManagedAssociation.normalizeExtension(searchText.value).isEmpty)

            if showCustomError.value {
                customErrorView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 自定义扩展名错误（含 duti 按需提示）

    /// 无法识别扩展名时的错误区：duti 未安装时附带可选安装入口
    @ViewBuilder
    private var customErrorView: some View {
        VStack(spacing: 8) {
            Text(customErrorMessage.value)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if !appState.dutiInstalled {
                Button {
                    showDutiGuide.value = true
                } label: {
                    Label(
                        isChineseUI() ? "安装可选组件 duti…" : "Install Optional duti…",
                        systemImage: "puzzlepiece.extension"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func addCustomExtension() {
        let normalized = ManagedAssociation.normalizeExtension(searchText.value)
        guard !normalized.isEmpty else { return }

        // 已存在：提示回列表修改
        if isManaged(normalized) {
            duplicateExt.value = normalized
            showDuplicateAlert.value = true
            return
        }

        // 尝试解析 UTI
        guard let resolvedUTI = appState.associationService.resolveUTI(for: normalized) else {
            showCustomError.value = true
            if appState.dutiInstalled {
                customErrorMessage.value = isChineseUI()
                    ? "无法识别 \".\(normalized)\" 对应的文件类型。\n\n请确认此扩展名已被系统中的某个应用注册。"
                    : "Cannot recognize the file type for \".\(normalized)\".\n\nPlease make sure this extension is registered by an application on your system."
            } else {
                customErrorMessage.value = isChineseUI()
                    ? "无法识别 \".\(normalized)\" 对应的文件类型。\n\n该扩展名未被系统注册，安装可选组件 duti 后可能支持识别。"
                    : "Cannot recognize the file type for \".\(normalized)\".\n\nThis extension is not registered on the system. The optional duti component may help recognize it."
            }
            return
        }

        let displayNameDict = [
            "zh-Hans": ".\(normalized) 文件",
            "en": ".\(normalized) File"
        ]
        let extInfo = ExtensionInfo(
            ext: normalized,
            displayName: displayNameDict,
            category: "custom",
            preferredUTI: resolvedUTI
        )

        selectedExtension.value = extInfo
        showEditView.value = true
    }

    private func handleSave(ext: ExtensionInfo, app: AppInfo, isLocked: Bool) {
        // 解析 UTI
        guard let resolvedUTI = appState.associationService.resolveUTI(for: ext.ext)
                ?? ext.preferredUTI
        else {
            appState.showErrorMessage(
                isChineseUI()
                    ? "无法解析 .\(ext.ext) 的文件类型"
                    : "Cannot resolve file type for .\(ext.ext)"
            )
            return
        }

        // 如果开启了锁定，先写入默认应用
        if isLocked {
            Task {
                do {
                    try await appState.associationService.setDefaultApplication(
                        bundleIdentifier: app.bundleIdentifier,
                        forUTI: resolvedUTI
                    )
                } catch {
                    appState.showErrorMessage(
                        isChineseUI()
                            ? "写入默认应用失败"
                            : "Failed to set default application"
                    )
                    return
                }

                appState.addAssociation(
                    fileExtension: ext.ext,
                    displayName: ext.localizedDisplayName,
                    uti: resolvedUTI,
                    targetApp: app,
                    isLocked: true
                )
                dismiss()
            }
        } else {
            appState.addAssociation(
                fileExtension: ext.ext,
                displayName: ext.localizedDisplayName,
                uti: resolvedUTI,
                targetApp: app,
                isLocked: false
            )
            dismiss()
        }
    }

    // MARK: - Helpers

    private func fileTypeIcon(for category: String) -> String {
        switch category {
        case "document": return "doc.text"
        case "image": return "photo"
        case "video": return "film"
        case "audio": return "music.note"
        case "archive": return "archivebox"
        case "development": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}
