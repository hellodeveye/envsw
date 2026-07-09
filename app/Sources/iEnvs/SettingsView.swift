import ServiceManagement
import SwiftUI
import iEnvsCore

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    private let isBundled = Bundle.main.bundleIdentifier != nil
    @State private var launchAtLogin =
        Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled
    @State private var isSyncingLaunchAtLogin = false
    @State private var hookInstalled = HookInstaller().isInstalled()

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .disabled(!isBundled)
                    .onChange(of: launchAtLogin) { enabled in
                        guard !isSyncingLaunchAtLogin else {
                            isSyncingLaunchAtLogin = false
                            return
                        }
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            Prompt.error(error)
                        }
                        syncLaunchAtLogin()
                    }
            }

            Section("Shell Hook") {
                LabeledContent("Status") {
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: hookInstalled
                                  ? "checkmark.circle.fill"
                                  : "xmark.circle.fill")
                                .foregroundStyle(hookInstalled ? .green : .secondary)
                                .font(.system(size: 12))
                            Text(hookInstalled ? "Installed" : "Not Installed")
                                .foregroundStyle(hookInstalled ? .primary : .secondary)
                        }
                        Button(hookInstalled ? "Re-check" : "Install Hook") {
                            let installer = HookInstaller()
                            if !installer.isInstalled() {
                                do { try installer.install() } catch { Prompt.error(error) }
                            }
                            hookInstalled = installer.isInstalled()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Storage") {
                LabeledContent("Profiles Directory") {
                    Text(ProfileStore.defaultRoot().path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 320)
        .navigationTitle("Settings")
    }

    private func syncLaunchAtLogin() {
        let status = isBundled && SMAppService.mainApp.status == .enabled
        guard launchAtLogin != status else { return }
        isSyncingLaunchAtLogin = true
        launchAtLogin = status
    }
}
