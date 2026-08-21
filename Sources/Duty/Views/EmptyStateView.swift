import SwiftUI

struct EmptyStateView: View {
    enum Mode {
        case global   // 文件类型
        case file     // 指定文件
    }

    let mode: Mode
    @EnvironmentObject var appState: AppState

    private var title: String {
        switch mode {
        case .global:
            return isChineseUI() ? "还没有管理任何文件类型" : "No File Types Managed Yet"
        case .file:
            return isChineseUI() ? "还没有管理任何文件" : "No Files Managed Yet"
        }
    }

    private var detail: String {
        switch mode {
        case .global:
            return isChineseUI()
                ? "添加一个文件类型（按扩展名），锁定其默认打开应用。"
                : "Add a file type (by extension) and lock its default app."
        case .file:
            return isChineseUI()
                ? "添加单个文件，防止它被单独改到其他应用打开。"
                : "Add a single file to keep it from being opened by another app."
        }
    }

    private var systemImage: String {
        switch mode {
        case .global: return "doc.text.magnifyingglass"
        case .file: return "doc"
        }
    }

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(detail)
            } actions: {
                actionButton
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                actionButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch mode {
        case .global:
            Button {
                appState.showAddSheet = true
            } label: {
                Label(
                    isChineseUI() ? "添加文件类型" : "Add File Type",
                    systemImage: "doc.badge.plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .file:
            Button {
                appState.showAddFileSheet = true
            } label: {
                Label(
                    isChineseUI() ? "添加文件" : "Add File",
                    systemImage: "doc"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
