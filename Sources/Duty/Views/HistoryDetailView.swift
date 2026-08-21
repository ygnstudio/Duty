import SwiftUI
import AppKit

struct HistoryDetailView: View {
    let record: AssociationHistory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Label(record.result.displayName, systemImage: resultIcon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(resultColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isChineseUI() ? "关闭" : "Close")
                .keyboardShortcut(.escape)
            }

            Divider()

            // 详情字段（系统 Form + LabeledContent 渲染）
            Form {
                LabeledContent(
                    isChineseUI() ? "时间" : "Time",
                    value: formattedDate
                )

                LabeledContent(
                    isChineseUI() ? "文件类型" : "File Type",
                    value: ".\(record.fileExtension)"
                )

                if let filePath = record.filePath {
                    LabeledContent(
                        isChineseUI() ? "文件路径" : "File Path",
                        value: filePath
                    )
                }

                LabeledContent(
                    isChineseUI() ? "目标应用" : "Target App",
                    value: record.expectedApplicationName
                )

                if let detected = record.detectedApplicationName {
                    LabeledContent(
                        isChineseUI() ? "检测到的应用" : "Detected App",
                        value: detected
                    )
                }

                LabeledContent(
                    isChineseUI() ? "处理结果" : "Result",
                    value: record.result.displayName
                )

                if let duration = record.duration {
                    LabeledContent(
                        isChineseUI() ? "耗时" : "Duration",
                        value: String(format: "%.2f %@",
                            duration,
                            isChineseUI() ? "秒" : "s"
                        )
                    )
                }

                if let error = record.errorMessage {
                    Section(isChineseUI() ? "错误信息" : "Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .frame(width: 420, height: 380)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: record.createdAt)
    }

    private var resultIcon: String {
        switch record.result {
        case .restored: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "slash.circle.fill"
        }
    }

    private var resultColor: Color {
        switch record.result {
        case .restored: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }
}
