import SwiftUI
import AppKit

/// 打开设置窗口的统一按钮
/// 设置窗口是普通 Window scene（id "settings"），用 openWindow 打开，
/// 全 macOS 版本有效，且兼容 MenuBarExtra 场景。
struct SettingsButton<Label: View>: View {
    @ViewBuilder var label: Label
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } label: { label }
    }
}
