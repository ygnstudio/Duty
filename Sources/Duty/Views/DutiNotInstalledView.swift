import SwiftUI
import AppKit

struct DutiNotInstalledView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // 自动安装状态机
    private enum InstallPhase: Equatable {
        case idle
        case installing
        case success
        case failed
    }

    @StateObject private var installPhase = StateValue<InstallPhase>(.idle)
    @StateObject private var installLog = StateValue("")
    @StateObject private var brewInstallPhase = StateValue<InstallPhase>(.idle)
    @StateObject private var brewInstallLog = StateValue("")

    var body: some View {
        VStack(spacing: 16) {
            header

            // 根据 Homebrew 是否安装显示不同指引
            if appState.homebrewInstalled {
                brewAvailableView
            } else {
                brewNotAvailableView
            }

            manualInstallSection

            // 重新检测
            Button {
                appState.refreshDutiStatus()
            } label: {
                Label(
                    isChineseUI() ? "重新检测" : "Check Again",
                    systemImage: "arrow.clockwise"
                )
                .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isChineseUI() ? "关闭" : "Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text(isChineseUI() ? "安装可选组件 duti" : "Install Optional duti Component")
                .font(.title3)
                .fontWeight(.semibold)

            Text(isChineseUI()
                ? "Duty 无需 duti 即可正常工作。安装后仅获得一项增强：识别系统未知的冷门文件类型。大多数用户无需安装。"
                : "Duty works fully without duti. Installing it adds one enhancement: recognizing rare file types unknown to the system. Most users don't need it."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Homebrew 已安装：一键装 duti

    private var brewAvailableView: some View {
        VStack(spacing: 10) {
            installActionArea(
                phase: installPhase.value,
                log: installLog.value,
                buttonTitle: isChineseUI() ? "一键安装 duti" : "Install duti",
                buttonIcon: "arrow.down.circle.fill",
                installingText: isChineseUI() ? "正在安装 duti，请稍候…" : "Installing duti, please wait…",
                successText: isChineseUI() ? "安装成功，正在检测…" : "Installed, checking…",
                failedText: isChineseUI() ? "安装失败" : "Installation failed"
            ) {
                await runDutiInstall()
            }

            if installPhase.value == .failed, !installLog.value.isEmpty {
                errorLogBlock(installLog.value)
            }

            Text(isChineseUI()
                ? "已检测到 Homebrew。也可在终端自行运行 brew install duti，完成后点「重新检测」。"
                : "Homebrew detected. You can also run brew install duti in Terminal, then click Check Again."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Homebrew 未安装：一键装 brew + duti（需管理员密码）

    private var brewNotAvailableView: some View {
        VStack(spacing: 12) {
            installActionArea(
                phase: brewInstallPhase.value,
                log: brewInstallLog.value,
                buttonTitle: isChineseUI() ? "一键安装 Homebrew 与 duti（需输入密码）" : "Install Homebrew & duti (needs password)",
                buttonIcon: "arrow.down.circle.fill",
                installingText: isChineseUI() ? "正在安装 Homebrew 与 duti，请稍候…" : "Installing Homebrew and duti, please wait…",
                successText: isChineseUI() ? "安装成功，正在检测…" : "Installed, checking…",
                failedText: isChineseUI() ? "安装失败或已取消" : "Installation failed or cancelled"
            ) {
                await runBrewAndDutiInstall()
            }

            if brewInstallPhase.value == .failed, !brewInstallLog.value.isEmpty {
                errorLogBlock(brewInstallLog.value)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChineseUI()
                    ? "或在终端分两步执行："
                    : "Or run these two steps in Terminal:"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                commandBox("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                commandBox("brew install duti")
            }
        }
    }

    // MARK: - 手动编译（折叠备选）

    private var manualInstallSection: some View {
        DisclosureGroup(isChineseUI() ? "备选：手动编译安装" : "Alternative: Build from Source") {
            VStack(alignment: .leading, spacing: 8) {
                Text(isChineseUI()
                    ? "从 GitHub 下载 duti 源码并编译："
                    : "Download duti source from GitHub and build:"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                commandBox("git clone https://github.com/moretension/duti.git\ncd duti && make && sudo make install")
            }
            .padding(.top, 8)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 组件

    /// 命令展示框（可选择）+ 复制按钮
    private func commandBox(_ command: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(command)
                .font(.caption)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(isChineseUI() ? "复制命令" : "Copy")
            .padding(.top, 5)
        }
    }

    /// 自动安装按钮 / 进度展示
    @ViewBuilder
    private func installActionArea(
        phase: InstallPhase,
        log: String,
        buttonTitle: String,
        buttonIcon: String,
        installingText: String,
        successText: String,
        failedText: String,
        run: @escaping () async -> Void
    ) -> some View {
        switch phase {
        case .idle:
            Button {
                Task { await run() }
            } label: {
                Label(buttonTitle, systemImage: buttonIcon)
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(installingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .success:
            Label(successText, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

        case .failed:
            Label(failedText, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    /// 错误日志块（可复制/选择）
    @ViewBuilder
    private func errorLogBlock(_ log: String) -> some View {
        Text(log)
            .font(.caption2)
            .foregroundStyle(.red)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Actions

    /// 通过已检测到的 brew 一键安装 duti
    private func runDutiInstall() async {
        guard let brewPath = DutiDetector.findBrewPath() else {
            installPhase.value = .failed
            installLog.value = isChineseUI()
                ? "找不到 brew 可执行文件，请重新检测。"
                : "brew executable not found. Please refresh."
            return
        }

        installPhase.value = .installing
        installLog.value = ""

        do {
            let result = try await DutiDetector.installDuti(brewPath: brewPath)
            if result.isSuccess {
                installPhase.value = .success
                // 自动重新检测，命中后整个 DutiNotInstalledView 会被父视图自动隐藏
                appState.refreshDutiStatus()
                // 1.5 秒后回到 idle（万一检测仍未命中，保留按钮供重试）
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                installPhase.value = .idle
            } else {
                installPhase.value = .failed
                installLog.value = result.standardError.isEmpty ? result.standardOutput : result.standardError
            }
        } catch {
            installPhase.value = .failed
            installLog.value = error.localizedDescription
        }
    }

    /// 通过 osascript + 管理员权限一键安装 Homebrew 与 duti
    /// 弹出系统原生密码框，用户输入后脚本以 sudo 权限执行
    private func runBrewAndDutiInstall() async {
        brewInstallPhase.value = .installing
        brewInstallLog.value = ""

        let script = """
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && brew install duti
        """

        do {
            let result = try await CommandRunner.runAsync(
                executablePath: "/usr/bin/osascript",
                arguments: [
                    "-e",
                    "do shell script \"\(script.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges with prompt \"Duty 安装可选组件 duti 需要管理员权限\""
                ],
                timeout: 600
            )

            if result.isSuccess {
                brewInstallPhase.value = .success
                appState.refreshDutiStatus()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                brewInstallPhase.value = .idle
            } else {
                brewInstallPhase.value = .failed
                brewInstallLog.value = result.standardError.isEmpty ? result.standardOutput : result.standardError
            }
        } catch {
            brewInstallPhase.value = .failed
            brewInstallLog.value = error.localizedDescription
        }
    }
}
