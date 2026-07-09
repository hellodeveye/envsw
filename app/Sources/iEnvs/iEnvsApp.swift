import AppKit
import SwiftUI
import iEnvsCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HookOnboarding.runIfNeeded()
    }
}

@main
struct iEnvsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()
    @FocusedValue(\.selectedProfile) private var selectedProfile
    @FocusedValue(\.appState) private var focusedAppState
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(state)
        } label: {
            Image(nsImage: StatusIcon.image(danger: state.hasDangerActive))
        }

        Settings {
            SettingsView().environmentObject(state)
        }

        Window("iEnvs", id: "main") {
            MainView().environmentObject(state)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 580)
        .windowResizability(.contentMinSize)

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Group\u{2026}") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    state.requestNewGroupCreation()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Profile\u{2026}") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    state.requestNewProfileCreation()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(state.groups.isEmpty)
            }

            CommandGroup(after: .newItem) {
                Button("Manage Profiles\u{2026}") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .pasteboard) {
                Button("Delete Profile") {
                    if let ref = selectedProfile {
                        state.deleteProfile(group: ref.group, profile: ref.profile)
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selectedProfile == nil)
            }
        }
    }
}
