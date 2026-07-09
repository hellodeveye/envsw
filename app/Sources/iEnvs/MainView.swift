import SwiftUI
import iEnvsCore

struct MainView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedGroupName: String?
    @State private var selectedProfileName: String?

    private var selectedGroup: ProfileGroup? {
        guard let name = selectedGroupName else { return nil }
        return state.groups.first { $0.name == name }
    }

    var body: some View {
        NavigationSplitView {
            GroupSidebar(
                groups: state.groups,
                selection: $selectedGroupName,
                creationRequest: state.groupCreationRequest
            )
        } detail: {
            GroupDetailView(
                group: selectedGroup,
                selectedProfileName: $selectedProfileName,
                creationRequest: state.profileCreationRequest
            )
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let group = selectedGroupName {
                        state.off(group: group)
                    }
                } label: {
                    Label("Deactivate Group", systemImage: "power")
                }
                .disabled(selectedGroup?.activeProfileName == nil)
                .help("Deactivate Group")
            }
        }
        .onChange(of: state.groups) { groups in
            if let name = selectedGroupName,
               !groups.contains(where: { $0.name == name }) {
                selectedGroupName = groups.first?.name
                selectedProfileName = nil
            }
            if let name = selectedProfileName,
               let group = selectedGroup,
               !group.profiles.contains(where: { $0.name == name }) {
                selectedProfileName = nil
            }
        }
        .onChange(of: selectedGroupName) { _ in
            selectedProfileName = nil
        }
        .onAppear {
            if selectedGroupName == nil {
                selectedGroupName = state.groups.first?.name
            }
        }
        .focusedSceneValue(\.selectedProfile, selectedProfileRef)
        .focusedSceneValue(\.appState, state)
        .focusedSceneValue(\.selectedGroup, selectedGroupName)
    }

    private var selectedProfileRef: ProfileRef? {
        guard let group = selectedGroupName, let profile = selectedProfileName else { return nil }
        return ProfileRef(group: group, profile: profile)
    }
}
