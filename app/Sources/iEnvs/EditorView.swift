import SwiftUI

struct EditorView: View {
    let ref: ProfileRef
    @EnvironmentObject var state: AppState
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
            Divider()
            HStack {
                Text("KEY=VALUE per line, no “export” — new shells only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    state.writeProfile(group: ref.group, profile: ref.profile, contents: text)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(10)
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = state.readProfile(group: ref.group, profile: ref.profile) ?? ""
        }
    }
}
