import SwiftUI

struct EditorView: View {
    let ref: ProfileRef
    @EnvironmentObject var state: AppState
    @State private var text = ""
    @State private var loaded = false
    @State private var savedText = ""

    var body: some View {
        ProfileTextEditor(text: $text, isSaved: text == savedText) {
            state.writeProfile(group: ref.group, profile: ref.profile, contents: text)
            savedText = text
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let contents = state.readProfile(group: ref.group, profile: ref.profile) ?? ""
            text = contents
            savedText = contents
        }
    }
}
