import AppKit
import SwiftUI
import iEnvsCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon (works both bundled and via `swift run`)
        NSApp.setActivationPolicy(.accessory)
        HookOnboarding.runIfNeeded()
    }
}

@main
struct iEnvsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(state)
        } label: {
            Image(nsImage: StatusIcon.image(danger: state.hasDangerActive))
        }
        Settings {
            SettingsView()
        }
    }
}
