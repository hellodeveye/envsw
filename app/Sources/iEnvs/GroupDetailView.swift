import SwiftUI
import iEnvsCore

struct GroupDetailView: View {
    let group: ProfileGroup?
    @Binding var selectedProfileName: String?
    let creationRequest: Int
    @EnvironmentObject private var state: AppState
    @State private var isCreatingProfile = false
    @State private var handledCreationRequest = 0
    @State private var draftProfileName = ""
    @State private var draftProfileError: String?
    @FocusState private var draftProfileFocused: Bool

    var body: some View {
        Group {
            if let group {
                groupContent(group)
            } else {
                noGroupSelected
            }
        }
        .navigationTitle(group?.name ?? "Profiles")
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: group?.name) { _ in
            cancelProfileCreation()
            handleCreationRequest()
        }
        .onChange(of: draftProfileFocused) { focused in
            if isCreatingProfile && !focused {
                finishProfileCreation(openEditor: false)
            }
        }
        .onChange(of: draftProfileName) { _ in
            draftProfileError = nil
        }
        .onChange(of: creationRequest) { _ in
            handleCreationRequest()
        }
        .onAppear {
            handleCreationRequest()
        }
    }

    private func groupContent(_ group: ProfileGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if group.profiles.isEmpty {
                    emptyProfiles(group)
                } else {
                    profileSection(group)
                    if !isCreatingProfile {
                        addProfileAction(group)
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func profileSection(_ group: ProfileGroup) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Profiles")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)

            VStack(spacing: 0) {
                ForEach(Array(group.profiles.enumerated()), id: \.element.name) { index, profile in
                    ProfileSettingsRow(
                        profile: profile,
                        isActive: group.activeProfileName == profile.name,
                        isSelected: selectedProfileName == profile.name
                    ) {
                        selectedProfileName = profile.name
                        EditorWindowController.open(
                            ProfileRef(group: group.name, profile: profile.name),
                            state: state
                        )
                    }
                    .contextMenu {
                        Button("Activate") {
                            state.use(group: group.name, profile: profile.name)
                        }
                        .disabled(group.activeProfileName == profile.name)

                        Button("Edit") {
                            selectedProfileName = profile.name
                            EditorWindowController.open(
                                ProfileRef(group: group.name, profile: profile.name),
                                state: state
                            )
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            state.deleteProfile(group: group.name, profile: profile.name)
                        }
                    }

                    if index < group.profiles.count - 1 {
                        Divider()
                            .padding(.leading, 76)
                    }
                }

                if isCreatingProfile {
                    if !group.profiles.isEmpty {
                        Divider()
                            .padding(.leading, 76)
                    }
                    DraftProfileRow(
                        name: $draftProfileName,
                        error: draftProfileError,
                        focus: $draftProfileFocused
                    ) {
                        finishProfileCreation(openEditor: true)
                    } cancel: {
                        cancelProfileCreation()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func addProfileAction(_ group: ProfileGroup) -> some View {
        HStack(spacing: 12) {
            Spacer()

            Button {
                beginProfileCreation()
            } label: {
                Text("Add Profile...")
                    .frame(minWidth: 112)
            }
        }
        .controlSize(.large)
        .padding(.top, -10)
        .padding(.trailing, 20)
    }

    private func emptyProfiles(_ group: ProfileGroup) -> some View {
        Group {
            if isCreatingProfile {
                profileSection(group)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 18) {
                        ProfileLargeIcon(systemName: "doc.badge.plus", tint: .accentColor)

                        VStack(spacing: 5) {
                            Text("No Profiles")
                                .font(.title3.weight(.semibold))
                            Text("Create a profile to define environment variables for \(group.name).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(28)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    addProfileAction(group)
                }
            }
        }
    }

    private var noGroupSelected: some View {
        VStack(spacing: 14) {
            ProfileLargeIcon(systemName: "sidebar.left", tint: .secondary)
            Text("Select a Group")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func beginProfileCreation() {
        guard group != nil else { return }
        if isCreatingProfile {
            draftProfileFocused = true
            return
        }
        draftProfileName = ""
        draftProfileError = nil
        isCreatingProfile = true
        selectedProfileName = nil
        DispatchQueue.main.async {
            draftProfileFocused = true
        }
    }

    private func handleCreationRequest() {
        guard creationRequest != handledCreationRequest, group != nil else { return }
        handledCreationRequest = creationRequest
        beginProfileCreation()
    }

    private func finishProfileCreation(openEditor: Bool) {
        guard let group else {
            cancelProfileCreation()
            return
        }
        let name = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelProfileCreation()
            return
        }

        switch state.createProfileInline(group: group.name, profile: name) {
        case .success:
            isCreatingProfile = false
            draftProfileName = ""
            draftProfileError = nil
            selectedProfileName = name
            if openEditor {
                EditorWindowController.open(ProfileRef(group: group.name, profile: name), state: state)
            }
        case .failure(let error):
            draftProfileError = error.localizedDescription
            DispatchQueue.main.async {
                draftProfileFocused = true
            }
        }
    }

    private func cancelProfileCreation() {
        isCreatingProfile = false
        draftProfileName = ""
        draftProfileError = nil
        draftProfileFocused = false
    }
}

private struct DraftProfileRow: View {
    @Binding var name: String
    let error: String?
    let focus: FocusState<Bool>.Binding
    let submit: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ProfileLargeIcon(systemName: "terminal.fill", tint: .secondary)

            VStack(alignment: .leading, spacing: 3) {
                TextField("New Profile", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .focused(focus)
                    .onSubmit {
                        submit()
                    }
                    .onExitCommand {
                        cancel()
                    }

                HStack(spacing: 6) {
                    Circle()
                        .fill(error == nil ? Color.secondary : Color.red)
                        .frame(width: 8, height: 8)

                    Text(error ?? "Inactive")
                        .font(.callout)
                        .foregroundStyle(error == nil ? Color.secondary : Color.red)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct ProfileSettingsRow: View {
    let profile: Profile
    let isActive: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ProfileLargeIcon(
                    systemName: iconName,
                    tint: iconTint
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        return isActive ? "checkmark" : "terminal.fill"
    }

    private var iconTint: Color {
        return isActive ? .accentColor : .secondary
    }

    private var statusTint: Color {
        isActive ? .green : .secondary
    }

    private var statusText: String {
        if isActive { return "Active" }
        return "Inactive"
    }
}

private struct ProfileLargeIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.gradient)
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 52, height: 52)
    }
}
