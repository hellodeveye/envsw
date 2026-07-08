import AppKit
import SwiftUI

struct ProfileRef: Hashable {
    let group: String
    let profile: String
}

/// Manages plain NSWindows for profile editors (reliable for menu-bar-only
/// apps, where WindowGroup scenes can open stray windows at launch).
@MainActor
enum EditorWindowController {
    private static var windows: [ProfileRef: NSWindow] = [:]

    static func open(_ ref: ProfileRef, state: AppState) {
        if let window = windows[ref] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = EditorView(ref: ref).environmentObject(state)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "\(ref.group) / \(ref.profile)"
        window.setContentSize(NSSize(width: 520, height: 380))
        window.isReleasedWhenClosed = false
        windows[ref] = window

        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                windows.removeValue(forKey: ref)
                if let token { NotificationCenter.default.removeObserver(token) }
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close(_ ref: ProfileRef) {
        windows[ref]?.close()
    }

    static func closeGroup(_ group: String) {
        let refs = windows.keys.filter { $0.group == group }
        for ref in refs {
            windows[ref]?.close()
        }
    }
}
