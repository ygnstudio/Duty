import SwiftUI

struct ApplicationPicker: View {
    let uti: String
    @Binding var selectedApp: AppInfo?
    /// 应用列表数量变化回调（供父视图动态调整窗口高度）
    var onAppsCountChange: ((Int) -> Void)? = nil

    @EnvironmentObject var appState: AppState

    /// 设置项：是否在选默认应用时展示系统推荐的应用列表
    @AppStorage("showAppRecommendations") private var showRecommendations = true

    @StateObject private var availableApps = StateValue<[AppInfo]>([])
    @StateObject private var selectedBundleID = OptionalStateValue<String>()
    @StateObject private var isLoading = StateValue(true)

    /// 列表动态高度：按应用数量撑开，最多 3 行，超出滚动
    private var listHeight: CGFloat {
        let rows = min(max(availableApps.value.count, 1), 3)
        return CGFloat(rows) * 34 + 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showRecommendations {
                if isLoading.value {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(isChineseUI() ? "正在加载应用列表…" : "Loading applications…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if availableApps.value.isEmpty {
                    emptyOrSelectedView
                } else {
                    recommendedList
                }
            } else {
                // 推荐关闭：只显示已选应用 + 手动选择按钮
                emptyOrSelectedView
            }

            // 手动选择应用
            Button {
                selectFromFinder()
            } label: {
                Label(
                    isChineseUI() ? "从 Applications 中选择…" : "Choose from Applications…",
                    systemImage: "folder"
                )
                .font(.caption)
            }
        }
        .task {
            if showRecommendations {
                await loadAvailableApps()
            }
        }
    }

    // MARK: - Subviews

    /// 空列表 / 推荐关闭时的展示：已选应用行或"未找到"提示
    @ViewBuilder
    private var emptyOrSelectedView: some View {
        if let selected = selectedApp {
            HStack(spacing: 10) {
                appIconView(selected)
                Text(selected.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        } else if showRecommendations {
            Text(isChineseUI()
                ? "未找到可以打开此文件类型的应用"
                : "No applications found for this file type"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// 系统推荐的应用列表（选中高亮自动渲染，深浅模式自适应）
    private var recommendedList: some View {
        List(selection: $selectedBundleID.value) {
            ForEach(availableApps.value) { app in
                HStack(spacing: 10) {
                    appIconView(app)
                    Text(app.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                .tag(app.bundleIdentifier)
            }
        }
        .listStyle(.inset)
        .frame(height: listHeight)
        .onChange(of: selectedBundleID.value) { newValue in
            if let id = newValue,
               let app = availableApps.value.first(where: {
                   $0.bundleIdentifier.lowercased() == id.lowercased()
               }) {
                selectedApp = app
            }
        }
        .onAppear {
            // 预设选中项：LaunchServices 返回的 bundle id 为小写，忽略大小写匹配
            if let sel = selectedApp?.bundleIdentifier {
                selectedBundleID.value = availableApps.value.first(where: {
                    $0.bundleIdentifier.lowercased() == sel.lowercased()
                })?.bundleIdentifier ?? sel
            }
        }
    }

    // MARK: - App Icon

    @ViewBuilder
    private func appIconView(_ app: AppInfo) -> some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Load

    private func loadAvailableApps() async {
        isLoading.value = true
        defer { isLoading.value = false }

        let apps = appState.associationService.getAvailableApplications(forUTI: uti)
        availableApps.value = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        onAppsCountChange?(availableApps.value.count)
    }

    private func selectFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = isChineseUI() ? "选择" : "Select"

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            let name = url.deletingPathExtension().lastPathComponent
            let bundleID = bundle?.bundleIdentifier ?? ""
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            let app = AppInfo(
                name: name,
                bundleIdentifier: bundleID,
                path: url.path,
                icon: icon
            )
            selectedApp = app
            selectedBundleID.value = bundleID
        }
    }
}
