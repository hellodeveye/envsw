import SwiftUI

struct ProfileTextEditor: View {
    @Binding var text: String
    let isSaved: Bool
    let onSave: () -> Void

    private var lineCount: Int {
        max(1, text.components(separatedBy: "\n").count)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))

            Divider()

            HStack(spacing: 12) {
                Label("\(lineCount) lines", systemImage: "text.alignleft")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("KEY=VALUE per line")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    onSave()
                } label: {
                    Label(isSaved ? "Saved" : "Save",
                          systemImage: isSaved ? "checkmark" : "square.and.arrow.down")
                        .frame(minWidth: 72)
                }
                .controlSize(.small)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isSaved)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.bar)
        }
    }
}
