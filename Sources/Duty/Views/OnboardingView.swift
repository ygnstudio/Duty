import SwiftUI
import AppKit
import UserNotifications

/// 首次启动引导页（4 页分页）
/// 仅当 hasCompletedOnboarding = false 时由 DutyApp 打开；
/// 完成或跳过后写入标记并打开主窗口，之后启动一律静默驻留菜单栏。
struct OnboardingView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @StateObject private var pageIndex = StateValue(0)
    @StateObject private var notificationStatus = StateValue(UNAuthorizationStatus.notDetermined)

    private let pageCount = 4
    private var isLastPage: Bool { pageIndex.value == pageCount - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // 页面内容
            Group {
                switch pageIndex.value {
                case 0: welcomePage
                case 1: featuresPage
                case 2: howItWorksPage
                default: getStartedPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(pageIndex.value)
            .transition(.opacity)

            Divider()

            // 底部栏：跳过（左）+ 分页点（中）+ 继续（右）
            ZStack {
                pageIndicator

                HStack {
                    Button(isChineseUI() ? "跳过" : "Skip") {
                        finish()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                    // 最后一页隐藏但占位，保持分页点居中
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)

                    Spacer()

                    Button(isChineseUI()
                        ? (isLastPage ? "开始使用" : "继续")
                        : (isLastPage ? "Get Started" : "Continue")
                    ) {
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 460, height: 400)
        .onAppear {
            // Window scene 实例会被系统复用（关闭再打开不会重建视图），
            // 每次出现时重置回第一页并刷新通知状态，
            // 否则「重新显示引导」会停留在上次翻到的页面
            pageIndex.value = 0
            Task { await refreshNotificationStatus() }
        }
    }

    // MARK: - Page 1 欢迎

    private var welcomePage: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(isChineseUI() ? "欢迎使用 Duty" : "Welcome to Duty")
                .font(.title2)
                .fontWeight(.semibold)

            Text(isChineseUI()
                ? "锁定文件的默认打开方式，防止被其他软件悄悄改掉。"
                : "Lock the default apps for your files so other software can't silently change them."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Page 2 它能做什么

    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(isChineseUI() ? "它能做什么" : "What It Does")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 18) {
                featureRow(
                    icon: "doc.text.magnifyingglass",
                    title: isChineseUI() ? "按文件类型锁定" : "Lock by File Type",
                    detail: isChineseUI()
                        ? "例如让 .csv 永远用你指定的应用打开"
                        : "e.g. always open .csv with your chosen app"
                )
                featureRow(
                    icon: "doc",
                    title: isChineseUI() ? "指定单个文件" : "Protect a Single File",
                    detail: isChineseUI()
                        ? "让它保持跟随全局默认打开方式"
                        : "Keep it following the system-wide default"
                )
                featureRow(
                    icon: "clock.arrow.circlepath",
                    title: isChineseUI() ? "篡改自动恢复" : "Auto-restore Tampering",
                    detail: isChineseUI()
                        ? "改动被检测、恢复，并留下历史记录"
                        : "Changes are detected, restored, and recorded"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 3 它是怎么工作的

    private var howItWorksPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(isChineseUI() ? "它是怎么工作的" : "How It Works")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 14) {
                stepRow(
                    number: 1,
                    title: isChineseUI() ? "后台静默监控" : "Silent Monitoring",
                    detail: isChineseUI() ? "常驻菜单栏，不占用 Dock" : "Lives in the menu bar, no Dock icon"
                )
                stepRow(
                    number: 2,
                    title: isChineseUI() ? "发现默认应用被改" : "Change Detected",
                    detail: isChineseUI() ? "弹系统通知提醒你" : "You get a system notification"
                )
                stepRow(
                    number: 3,
                    title: isChineseUI() ? "锁定项自动恢复" : "Auto Restore",
                    detail: isChineseUI() ? "全程可在历史记录中查证" : "Fully traceable in the history log"
                )
            }

            // 通知授权（从启动即请求改为用户点击时请求）
            notificationSection

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 4 开始使用

    private var getStartedPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(isChineseUI() ? "开始使用" : "Get Started")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 18) {
                featureRow(
                    icon: "menubar.rectangle",
                    title: isChineseUI() ? "入口在菜单栏" : "It Lives in the Menu Bar",
                    detail: isChineseUI()
                        ? "之后每次启动（包括开机自启）都静默驻留菜单栏，不弹出窗口；点盾牌图标随时打开主窗口。"
                        : "From now on, Duty starts silently in the menu bar (including at login) without popping up windows. Click the shield icon anytime to open it."
                )
                featureRow(
                    icon: "puzzlepiece.extension",
                    title: isChineseUI() ? "duti 是可选组件" : "duti Is Optional",
                    detail: isChineseUI()
                        ? "不安装也能正常使用，之后可在设置中安装"
                        : "Duty works fully without it; install later in Settings if needed"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 组件

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 340)
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(width: 22, height: 22)
                    .background(.quaternary)
                    .clipShape(Circle())

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 340)
    }

    @ViewBuilder
    private var notificationSection: some View {
        switch notificationStatus.value {
        case .authorized:
            Label(
                isChineseUI() ? "通知已开启" : "Notifications Enabled",
                systemImage: "checkmark.circle.fill"
            )
            .font(.callout)
            .foregroundStyle(.green)

        case .denied:
            Text(isChineseUI()
                ? "通知已被拒绝，可稍后在 系统设置 → 通知 中开启。"
                : "Notifications are off. You can enable them later in System Settings → Notifications."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

        default:
            VStack(spacing: 6) {
                Button(isChineseUI() ? "允许通知" : "Allow Notifications") {
                    Task { await requestNotifications() }
                }
                .buttonStyle(.bordered)

                Text(isChineseUI() ? "用于默认应用被改时的提醒" : "Used for tamper alerts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex.value ? Color.accentColor : Color.secondary)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - 行为

    private func advance() {
        if isLastPage {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            pageIndex.value += 1
        }
    }

    /// 完成或跳过：写标记 → 关引导窗 → 打开主窗口
    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        requestNotificationIfUndetermined()
        dismissWindow(id: "onboarding")
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 通知授权

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus.value = settings.authorizationStatus
    }

    private func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        await refreshNotificationStatus()
    }

    /// 用户未点「允许通知」就直接完成/跳过时兜底请求一次，
    /// 保证核心的篡改提醒能力可用
    private func requestNotificationIfUndetermined() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
