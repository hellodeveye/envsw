import SwiftUI
import iEnvsCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Manage Profiles\u{2026}") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o", modifiers: .command)

        Divider()

        if state.groups.isEmpty {
            Text("No Profiles")
                .foregroundStyle(.secondary)
        }
        ForEach(state.groups, id: \.name) { group in
            Section(group.name) {
                if group.profiles.isEmpty {
                    Text("No Profiles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(group.profiles, id: \.name) { profile in
                        Button {
                            state.use(group: group.name, profile: profile.name)
                        } label: {
                            HStack {
                                Text(profile.name)
                                Spacer()
                                if group.activeProfileName == profile.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
        }
        Divider()
        settingsButton
        Divider()
        Button("Quit iEnvs") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink { Text("Settings\u{2026}") }
        } else {
            Button("Settings\u{2026}") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
