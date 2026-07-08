import ServiceManagement
import SwiftUI
import iEnvsCore

struct SettingsView: View {
    private let isBundled = Bundle.main.bundleIdentifier != nil
    @State private var launchAtLogin =
        Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled
    @State private var isSyncingLaunchAtLogin = false
    @State private var hookInstalled = HookInstaller().isInstalled()

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
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
            if !isBundled {
                Text("Only available when running as iEnvs.app (see app/scripts/make-app.sh).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Shell hook", value: hookInstalled ? "Installed ✓" : "Not installed")
            Button(hookInstalled ? "Re-check" : "Install Hook") {
                let installer = HookInstaller()
                if !installer.isInstalled() {
                    do { try installer.install() } catch { Prompt.error(error) }
                }
                hookInstalled = installer.isInstalled()
            }

            Divider()

            LabeledContent("Profiles directory", value: ProfileStore.defaultRoot().path)
            Text("Switching only affects NEW shells/processes — that's Unix, not a bug.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func syncLaunchAtLogin() {
        let status = isBundled && SMAppService.mainApp.status == .enabled
        guard launchAtLogin != status else { return }
        isSyncingLaunchAtLogin = true
        launchAtLogin = status
    }
}
