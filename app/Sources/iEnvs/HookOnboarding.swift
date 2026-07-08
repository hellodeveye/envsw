import AppKit
import iEnvsCore

@MainActor
enum HookOnboarding {
    /// On launch: if the shell hook is missing, explain and offer to install.
    static func runIfNeeded(installer: HookInstaller = HookInstaller()) {
        guard !installer.isInstalled() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Shell hook not installed"
        alert.informativeText = """
        Without the hook in \(installer.targetFile.lastPathComponent), switching profiles \
        has no effect: new shells won't auto-load the active profile.

        iEnvs can append the envsw hook to \(installer.targetFile.path) now.
        """
        alert.addButton(withTitle: "Install Hook")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try installer.install() } catch { Prompt.error(error) }
    }
}
