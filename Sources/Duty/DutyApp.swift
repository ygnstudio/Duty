import SwiftUI
import AppKit
import OSLog

let logger = Logger(subsystem: "com.ygnstudio.Duty", category: "app")

extension Notification.Name {
    /// 首次启动时由 AppDelegate 发出，DutyApp 监听后打开引导窗口
    static let dutyShowOnboarding = Notification.Name("com.ygnstudio.Duty.showOnboarding")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Duty launched — setting activation policy")

        // 隐藏 Dock 图标（用代码而非 Info.plist LSUIElement）
        NSApp.setActivationPolicy(.accessory)

        // 首次启动显示引导（引导完成时会打开主窗口）；
        // 之后不论开机自启还是手动开启，一律静默驻留菜单栏，不弹出任何窗口。
        // 通知权限请求已挪到引导页（用户点击「允许通知」时）。
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            // 延迟确保 MenuBarExtra 已初始化（监听方已就位）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .dutyShowOnboarding, object: nil)
            }
        } else {
            // 静默启动兜底：若系统行为（如 Window scene 启动时自动恢复窗口）
            // 导致任何窗口被自动显示，立即隐藏，保证只驻留菜单栏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for window in NSApp.windows where window.isVisible {
                    window.orderOut(nil)
                }
            }
        }
    }
}

@main
struct DutyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            Group {
                Button {
                    openMainWindow()
                } label: {
                    Label(
                        isChineseUI() ? "打开 Duty" : "Open Duty",
                        systemImage: "rectangle.inset.filled"
                    )
                }
                .keyboardShortcut("o")

                SettingsButton {
                    Label(
                        isChineseUI() ? "设置…" : "Settings…",
                        systemImage: "gearshape"
                    )
                }
                .keyboardShortcut(",")

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(
                        isChineseUI() ? "退出 Duty" : "Quit Duty",
                        systemImage: "power"
                    )
                }
                .keyboardShortcut("q")
            }
            .onReceive(NotificationCenter.default.publisher(for: .dutyShowOnboarding)) { _ in
                openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            menuBarIcon
        }

        Window("Duty", id: "main") {
            MainWindow()
                .environmentObject(appState)
                // 宽度可调（表格列可拖拽），高度最小 560
                .frame(minWidth: 780, idealWidth: 880, minHeight: 560, idealHeight: 680)
                .windowAutosave("com.ygnstudio.Duty.main")
                .onAppear {
                    logger.info("MainWindow appeared")
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 880, height: 680)

        // 设置窗口：用普通 Window scene（而非 Settings scene），
        // 因 Settings scene 在这台 macOS 26 上 openWindow/sendAction/SettingsLink 均打不开
        Window("Duty Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .windowAutosave("com.ygnstudio.Duty.settings")
        }
        .windowResizability(.contentSize)

        // 首次启动引导窗口（固定内容尺寸，不可调整）
        Window(isChineseUI() ? "欢迎使用 Duty" : "Welcome to Duty", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
    }

    // MARK: - Menu Bar Icon

    /// 菜单栏图标：固定盾牌图标（不随保护状态变化）
    private var menuBarIcon: some View {
        Image(systemName: "shield.fill")
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
