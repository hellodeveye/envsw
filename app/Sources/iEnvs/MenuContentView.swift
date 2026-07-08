import SwiftUI
import iEnvsCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.groups.isEmpty {
            Text("No profiles yet — create a group to start")
        }
        ForEach(state.groups, id: \.name) { group in
            Section(group.name) {
                ForEach(group.profiles, id: \.name) { profile in
                    Button {
                        state.use(group: group.name, profile: profile.name)
                    } label: {
                        let mark = group.activeProfileName == profile.name ? "●" : "○"
                        let warn = profile.isDangerous ? "  ⚠" : ""
                        Text("\(mark) \(profile.name)\(warn)")
                    }
                }
                manageMenu(for: group)
            }
        }
        Divider()
        Button("New Group…") { state.promptNewGroup() }
        settingsButton
        Divider()
        Button("Quit iEnvs") { NSApp.terminate(nil) }
    }

    @ViewBuilder
    private func manageMenu(for group: ProfileGroup) -> some View {
        Menu("Manage \(group.name)") {
            Button("New Profile…") { state.promptNewProfile(group: group.name) }
            if !group.profiles.isEmpty {
                Menu("Edit") {
                    ForEach(group.profiles, id: \.name) { p in
                        Button("\(p.name)…") {
                            EditorWindowController.open(
                                ProfileRef(group: group.name, profile: p.name), state: state)
                        }
                    }
                }
                Menu("Delete") {
                    ForEach(group.profiles, id: \.name) { p in
                        Button("\(p.name)…") {
                            state.deleteProfile(group: group.name, profile: p.name)
                        }
                    }
                }
            }
            Divider()
            Button("Deactivate (off)") { state.off(group: group.name) }
                .disabled(group.activeProfileName == nil)
            Button("Delete Group…") { state.deleteGroup(group.name) }
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink { Text("Settings…") }
        } else {
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
