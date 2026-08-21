import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("historyEnabled") private var historyEnabled = false
    @StateObject private var showHistorySheet = StateValue(false)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 主内容
                switch appState.mainTab {
                case .global:
                    if appState.associations.isEmpty {
                        EmptyStateView(mode: .global)
                    } else {
                        AssociationListView()
                    }
                case .file:
                    if appState.managedFiles.isEmpty {
                        EmptyStateView(mode: .file)
                    } else {
                        FileListView()
                    }
                }
            }
            .navigationTitle("Duty")
            .toolbar {
                // 左侧：保护开关
                ToolbarItem(placement: .navigation) {
                    protectionToggle
                }

                // 中央：标签页切换（原生工具栏分段控件，自适应宽度）
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $appState.mainTab) {
                        Text(isChineseUI() ? "文件类型" : "File Types").tag(MainTab.global)
                        Text(isChineseUI() ? "指定文件" : "Files").tag(MainTab.file)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // 右侧：操作按钮
                ToolbarItemGroup(placement: .primaryAction) {
                    SettingsButton {
                        Label(
                            isChineseUI() ? "设置" : "Settings",
                            systemImage: "gearshape"
                        )
                    }
                    .help(isChineseUI() ? "设置" : "Settings")

                    if historyEnabled {
                        Button {
                            showHistorySheet.value = true
                        } label: {
                            Label(
                                isChineseUI() ? "最近修改" : "Recent Changes",
                                systemImage: "clock.arrow.circlepath"
                            )
                        }
                        .disabled(appState.history.isEmpty)
                        .help(isChineseUI() ? "最近修改" : "Recent Changes")
                    }

                    Menu {
                        Button {
                            appState.showAddSheet = true
                        } label: {
                            Label(
                                isChineseUI() ? "添加文件类型" : "Add File Type",
                                systemImage: "doc.badge.plus"
                            )
                        }

                        Button {
                            appState.showAddFileSheet = true
                        } label: {
                            Label(
                                isChineseUI() ? "添加文件" : "Add File",
                                systemImage: "doc"
                            )
                        }
                    } label: {
                        Label(isChineseUI() ? "添加" : "Add", systemImage: "plus")
                    }
                    .help(isChineseUI() ? "添加管理项" : "Add Managed Item")
                }
            }
            .sheet(isPresented: $showHistorySheet.value) {
                HistoryView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $appState.showAddSheet) {
                AddAssociationSheet()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $appState.showAddFileSheet) {
                AddFileSheet()
                    .environmentObject(appState)
            }
            .sheet(item: $appState.selectedAssociation) { association in
                EditExistingAssociationView(association: association)
                    .environmentObject(appState)
            }
            .sheet(item: $appState.selectedFile) { file in
                EditFileView(file: file)
                    .environmentObject(appState)
            }
            .alert(
                isChineseUI() ? "错误" : "Error",
                isPresented: $appState.showError
            ) {
                Button("OK") {
                    appState.dismissError()
                }
            } message: {
                Text(appState.errorMessage ?? "")
            }
        }
    }

    // MARK: - Protection Control（工具栏按钮，tooltip 展示详情）

    private var lockedCount: Int {
        appState.associations.filter(\.isLocked).count
            + appState.managedFiles.filter(\.isLocked).count
    }

    private var isProtectionActive: Bool {
        appState.protectionService.isRunning && !appState.protectionService.isPaused
    }

    private var protectionToggle: some View {
        Button {
            toggleProtection()
        } label: {
            Image(systemName: protectionStatusIcon)
        }
        .foregroundStyle(isProtectionActive ? .green : .secondary)
        .help(protectionStatusDetail)
    }

    private var protectionStatusIcon: String {
        if !appState.protectionService.isRunning {
            return "shield"
        }
        return appState.protectionService.isPaused
            ? "shield.slash"
            : "checkmark.shield.fill"
    }

    private func toggleProtection() {
        let service = appState.protectionService
        if service.isRunning && !service.isPaused {
            service.pause()
        } else if service.isRunning {
            service.resume()
        } else {
            service.start()
        }
    }

    private var protectionStatusDetail: String {
        let status: String
        if !appState.protectionService.isRunning {
            status = isChineseUI() ? "保护未启动" : "Protection off"
        } else if appState.protectionService.isPaused {
            status = isChineseUI() ? "保护已暂停" : "Protection paused"
        } else {
            status = isChineseUI() ? "保护中" : "Protection active"
        }
        if lockedCount > 0 {
            return status + (isChineseUI()
                ? " · 已锁定 \(lockedCount) 项"
                : " · \(lockedCount) locked")
        }
        return status
    }
}
