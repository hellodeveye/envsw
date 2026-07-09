import SwiftUI
import iEnvsCore

struct OnboardingView: View {
    let installer: HookInstaller
    let onInstall: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "terminal")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                VStack(spacing: 8) {
                    Text("Welcome to iEnvs")
                        .font(.title2.weight(.semibold))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    Text("Environment profile manager for your shell")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                OnboardingStep(
                    icon: "folder.fill",
                    title: "Create Groups",
                    description: "Organize profiles by project (e.g. myapp, api)."
                )
                OnboardingStep(
                    icon: "doc.text.fill",
                    title: "Add Profiles",
                    description: "Each profile is a set of KEY=VALUE environment variables."
                )
                OnboardingStep(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Switch Instantly",
                    description: "Activate a profile from the menu bar. New shells pick it up automatically."
                )
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer()

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Shell Hook Required", systemImage: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)

                    Text("The hook in \(installer.targetFile.lastPathComponent) lets new shells auto-load the active profile and refreshes open interactive shells before the next command.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Skip") { onSkip() }
                        .controlSize(.large)

                    Spacer()

                    Button("Install Hook") { onInstall() }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .padding(.top, 40)
        .frame(width: 480, height: 520)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

private struct OnboardingStep: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
