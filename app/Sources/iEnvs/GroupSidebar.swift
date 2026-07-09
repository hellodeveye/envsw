import SwiftUI
import iEnvsCore

struct GroupSidebar: View {
    let groups: [ProfileGroup]
    @Binding var selection: String?
    let creationRequest: Int
    @EnvironmentObject private var state: AppState
    @State private var searchText = ""
    @State private var isCreatingGroup = false
    @State private var handledCreationRequest = 0
    @State private var draftGroupName = ""
    @State private var draftGroupError: String?
    @State private var renamingGroupName: String?
    @State private var draftRenameGroupName = ""
    @State private var draftRenameGroupError: String?
    @FocusState private var draftGroupFocused: Bool
    @FocusState private var renameGroupFocused: Bool

    private var filteredGroups: [ProfileGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredGroups, id: \.name) { group in
                groupRow(group)
                    .tag(group.name)
                    .contextMenu {
                        Button("Rename") {
                            beginGroupRename(group.name)
                        }
                        .disabled(isCreatingGroup || renamingGroupName != nil)

                        Button("New Profile...") {
                            state.promptNewProfile(group: group.name)
                        }

                        Divider()

                        Button("Delete Group", role: .destructive) {
                            state.deleteGroup(group.name)
                        }
                    }
            }

            if isCreatingGroup {
                draftGroupRow
            } else if filteredGroups.isEmpty {
                Text("No Groups")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 340)
        .navigationTitle("iEnvs")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarActions
        }
        .onChange(of: draftGroupFocused) { focused in
            if isCreatingGroup && !focused {
                finishGroupCreation()
            }
        }
        .onChange(of: renameGroupFocused) { focused in
            if renamingGroupName != nil && !focused {
                finishGroupRename()
            }
        }
        .onChange(of: creationRequest) { _ in
            handleCreationRequest()
        }
        .onAppear {
            handleCreationRequest()
        }
    }

    private var sidebarActions: some View {
        let canRemove = selection != nil && !isCreatingGroup && renamingGroupName == nil

        return HStack(spacing: 22) {
            Button(action: beginGroupCreation) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .help("Add Group")
            .accessibilityLabel("Add Group")

            Button {
                guard let name = selection else { return }
                state.deleteGroup(name)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
            }
            .disabled(!canRemove)
            .opacity(canRemove ? 1 : 0.35)
            .help("Remove Group")
            .accessibilityLabel("Remove Group")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var draftGroupRow: some View {
        HStack(spacing: 12) {
            SidebarIcon(name: draftGroupName.isEmpty ? "New" : draftGroupName)

            VStack(alignment: .leading, spacing: 2) {
                TextField("New Group", text: $draftGroupName)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .focused($draftGroupFocused)
                    .onChange(of: draftGroupName) { _ in
                        draftGroupError = nil
                    }
                    .onSubmit {
                        finishGroupCreation()
                    }
                    .onExitCommand {
                        cancelGroupCreation()
                    }

                Text(draftGroupError ?? "Off")
                    .font(.callout)
                    .foregroundStyle(draftGroupError == nil ? Color.secondary : Color.red)
            }

            Spacer()
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func groupRow(_ group: ProfileGroup) -> some View {
        if renamingGroupName == group.name {
            renameGroupRow(group)
        } else {
            GroupRow(group: group)
        }
    }

    private func renameGroupRow(_ group: ProfileGroup) -> some View {
        HStack(spacing: 12) {
            SidebarIcon(name: draftRenameGroupName.isEmpty ? group.name : draftRenameGroupName)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Group Name", text: $draftRenameGroupName)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .focused($renameGroupFocused)
                    .onChange(of: draftRenameGroupName) { _ in
                        draftRenameGroupError = nil
                    }
                    .onSubmit {
                        finishGroupRename()
                    }
                    .onExitCommand {
                        cancelGroupRename()
                    }

                Text(draftRenameGroupError ?? group.activeProfileName ?? "Off")
                    .font(.callout)
                    .foregroundStyle(draftRenameGroupError == nil ? Color.secondary : Color.red)
            }

            Spacer()
        }
        .padding(.vertical, 7)
    }

    private func beginGroupCreation() {
        if isCreatingGroup {
            draftGroupFocused = true
            return
        }
        cancelGroupRename()
        searchText = ""
        draftGroupName = ""
        draftGroupError = nil
        isCreatingGroup = true
        selection = nil
        DispatchQueue.main.async {
            draftGroupFocused = true
        }
    }

    private func handleCreationRequest() {
        guard creationRequest != handledCreationRequest else { return }
        handledCreationRequest = creationRequest
        beginGroupCreation()
    }

    private func finishGroupCreation() {
        let name = draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelGroupCreation()
            return
        }
        switch state.createGroupInline(name) {
        case .success:
            isCreatingGroup = false
            draftGroupName = ""
            draftGroupError = nil
            selection = name
        case .failure(let error):
            draftGroupError = error.localizedDescription
            DispatchQueue.main.async {
                draftGroupFocused = true
            }
        }
    }

    private func cancelGroupCreation() {
        isCreatingGroup = false
        draftGroupName = ""
        draftGroupError = nil
        draftGroupFocused = false
    }

    private func beginGroupRename(_ name: String) {
        cancelGroupCreation()
        renamingGroupName = name
        draftRenameGroupName = name
        draftRenameGroupError = nil
        selection = name
        DispatchQueue.main.async {
            renameGroupFocused = true
        }
    }

    private func finishGroupRename() {
        guard let originalName = renamingGroupName else { return }
        let newName = draftRenameGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            cancelGroupRename()
            return
        }
        guard newName != originalName else {
            cancelGroupRename()
            return
        }

        switch state.renameGroupInline(originalName, to: newName) {
        case .success:
            renamingGroupName = nil
            draftRenameGroupName = ""
            draftRenameGroupError = nil
            selection = newName
        case .failure(let error):
            draftRenameGroupError = error.localizedDescription
            DispatchQueue.main.async {
                renameGroupFocused = true
            }
        }
    }

    private func cancelGroupRename() {
        renamingGroupName = nil
        draftRenameGroupName = ""
        draftRenameGroupError = nil
        renameGroupFocused = false
    }

}

private struct GroupRow: View {
    let group: ProfileGroup

    var body: some View {
        HStack(spacing: 12) {
            SidebarIcon(name: group.name)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.title3.weight(.semibold))
                Text(group.activeProfileName ?? "Off")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 7)
    }
}

private struct SidebarIcon: View {
    let name: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor.gradient)

            Text(initial)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 24)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
