import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var selectedRecord = OptionalStateValue<AssociationHistory>()
    @StateObject private var showClearAlert = StateValue(false)

    private var sortedHistory: [AssociationHistory] {
        appState.history.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.history.isEmpty {
                    emptyStateView
                } else {
                    tableView
                }
            }
            .navigationTitle(isChineseUI() ? "最近修改" : "Recent Changes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChineseUI() ? "关闭" : "Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showClearAlert.value = true
                    } label: {
                        Label(
                            isChineseUI() ? "清空" : "Clear",
                            systemImage: "trash"
                        )
                    }
                    .disabled(appState.history.isEmpty)
                    .help(isChineseUI() ? "清空历史记录" : "Clear History")
                }
            }
        }
        .frame(minWidth: 720, minHeight: 400)
        .alert(
            isChineseUI() ? "清空历史记录？" : "Clear History?",
            isPresented: $showClearAlert.value
        ) {
            Button(isChineseUI() ? "取消" : "Cancel", role: .cancel) {}
            Button(isChineseUI() ? "清空" : "Clear", role: .destructive) {
                appState.persistence.clearHistory()
                appState.history = []
            }
        } message: {
            Text(isChineseUI()
                ? "将删除所有历史记录，该操作不可撤销。"
                : "All history records will be deleted. This cannot be undone."
            )
        }
        .sheet(item: $selectedRecord.value) { record in
            HistoryDetailView(record: record)
        }
    }

    // MARK: - Native Table

    private var tableView: some View {
        Table(sortedHistory) {
            TableColumn(isChineseUI() ? "时间" : "Time") { record in
                Text(timeFormatter.string(from: record.createdAt))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 56, ideal: 70, max: 90)

            TableColumn(isChineseUI() ? "对象" : "Target") { record in
                HStack(spacing: 6) {
                    typeIcon(for: record)
                    locationText(for: record)
                }
            }
            .width(min: 110, ideal: 170)

            TableColumn(isChineseUI() ? "检测到" : "Detected") { record in
                Text(record.detectedApplicationName ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 90, ideal: 140)

            TableColumn(isChineseUI() ? "目标" : "Expected") { record in
                HStack(spacing: 4) {
                    if record.expectedBundleIdentifier.isEmpty {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(record.expectedApplicationName)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .width(min: 90, ideal: 140)

            TableColumn(isChineseUI() ? "结果" : "Result") { record in
                resultBadge(record.result)
            }
            .width(min: 70, ideal: 90, max: 120)

            TableColumn("") { record in
                Button {
                    selectedRecord.value = record
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help(isChineseUI() ? "查看详情" : "Show Details")
            }
            .width(32)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Row Components

    @ViewBuilder
    private func typeIcon(for record: AssociationHistory) -> some View {
        if record.filePath != nil {
            Image(systemName: "doc")
                .font(.caption)
                .foregroundStyle(.blue)
                .help(isChineseUI() ? "文件级" : "File-level")
        } else {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.green)
                .help(isChineseUI() ? "文件类型级" : "Type-level")
        }
    }

    private func locationText(for record: AssociationHistory) -> some View {
        Group {
            if let filePath = record.filePath {
                Text((filePath as NSString).lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(filePath)
            } else {
                Text(".\(record.fileExtension)")
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Result Badge

    @ViewBuilder
    private func resultBadge(_ result: RestoreResult) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName(for: result))
                .font(.system(size: 10))
                .foregroundStyle(color(for: result))
            Text(result.displayName)
                .font(.caption)
                .foregroundStyle(color(for: result))
        }
    }

    private func iconName(for result: RestoreResult) -> String {
        switch result {
        case .restored: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "slash.circle.fill"
        }
    }

    private func color(for result: RestoreResult) -> Color {
        switch result {
        case .restored: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label(
                    isChineseUI() ? "暂无修改记录" : "No Change Records",
                    systemImage: "clock.arrow.circlepath"
                )
            } description: {
                Text(isChineseUI()
                    ? "当默认应用被自动恢复时，这里会留下记录"
                    : "Records will appear here when default apps are auto-restored"
                )
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(isChineseUI() ? "暂无修改记录" : "No Change Records")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }
}
