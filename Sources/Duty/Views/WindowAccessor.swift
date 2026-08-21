import SwiftUI
import AppKit

/// 桥接 NSView → NSWindow，给窗口设置 frameAutosaveName，
/// 让 AppKit 自动把用户拖动调整后的大小/位置保存到 UserDefaults，
/// 下次启动自动恢复。
struct WindowAccessor: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 延迟到 window 已就绪后设 autosave
        DispatchQueue.main.async {
            applyAutosave(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyAutosave(to: nsView)
    }

    private func applyAutosave(to view: NSView) {
        guard let window = view.window else { return }
        if window.frameAutosaveName != autosaveName {
            window.setFrameAutosaveName(autosaveName)
        }
    }
}

extension View {
    /// 让当前窗口记住大小/位置（用户拖动后下次启动自动恢复）
    /// 不同窗口用不同 name（推荐 "BundleID.WindowName"）
    func windowAutosave(_ name: String) -> some View {
        background(WindowAccessor(autosaveName: name))
    }
}
