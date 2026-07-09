import AppKit
import SwiftUI
import iEnvsCore

@MainActor
enum HookOnboarding {
    private static var window: NSWindow?

    static func runIfNeeded(installer: HookInstaller = HookInstaller()) {
        guard !installer.isInstalled() else { return }
        NSApp.activate(ignoringOtherApps: true)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Welcome to iEnvs"
        win.titlebarAppearsTransparent = false
        win.titleVisibility = .visible
        win.isReleasedWhenClosed = false

        let view = OnboardingView(
            installer: installer,
            onInstall: {
                do { try installer.install() } catch { Prompt.error(error) }
                win.close()
                window = nil
            },
            onSkip: {
                win.close()
                window = nil
            }
        )
        win.contentViewController = NSHostingController(rootView: view)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}
