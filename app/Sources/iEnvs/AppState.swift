import Foundation
import iEnvsCore

@MainActor
final class AppState: ObservableObject {
    @Published var groups: [ProfileGroup] = []
    let store: ProfileStore
    private var watcher: DirectoryWatcher?

    init(store: ProfileStore = ProfileStore()) {
        self.store = store
        // Ensure the root exists so the watcher has something to watch.
        try? FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: store.root.path)
        reload()
        watcher = DirectoryWatcher(url: store.root) { [weak self] in self?.reload() }
    }

    var hasDangerActive: Bool { groups.contains { $0.hasDangerActive } }

    func reload() { groups = store.scan() }

    func use(group: String, profile: String) {
        if run({ try store.use(group: group, profile: profile) }), Danger.isDangerous(profile) {
            Notifier.dangerActivated(group: group, profile: profile)
        }
    }

    func off(group: String) {
        store.off(group: group)
        reload()
    }

    func promptNewGroup() {
        guard let name = Prompt.text(title: "New Group", message: "Group name (e.g. myapp):") else { return }
        run { try store.createGroup(name) }
    }

    /// Runs a mutation, reloads on success, shows an alert on failure.
    @discardableResult
    func run(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            reload()
            return true
        } catch {
            Prompt.error(error)
            return false
        }
    }

    func promptNewProfile(group: String) {
        guard let name = Prompt.text(title: "New Profile in “\(group)”",
                                     message: "Profile name (e.g. dev, staging, prod):") else { return }
        if run({ try store.createProfile(group: group, profile: name) }) {
            EditorWindowController.open(ProfileRef(group: group, profile: name), state: self)
        }
    }

    func deleteProfile(group: String, profile: String) {
        guard Prompt.confirm(
            title: "Delete profile “\(profile)” from “\(group)”?",
            message: "This removes \(profile).env. If it is active, the group is deactivated."
        ) else { return }
        if run({ try store.deleteProfile(group: group, profile: profile) }) {
            EditorWindowController.close(ProfileRef(group: group, profile: profile))
        }
    }

    func deleteGroup(_ name: String) {
        let groupPath = store.root.appendingPathComponent(name, isDirectory: true).path
        guard Prompt.confirm(
            title: "Delete group “\(name)”?",
            message: "This removes the whole \(groupPath) directory and all its profiles."
        ) else { return }
        if run({ try store.deleteGroup(name) }) {
            EditorWindowController.closeGroup(name)
        }
    }

    func readProfile(group: String, profile: String) -> String? {
        do { return try store.readProfile(group: group, profile: profile) }
        catch { Prompt.error(error); return nil }
    }

    func writeProfile(group: String, profile: String, contents: String) {
        run { try store.writeProfile(group: group, profile: profile, contents: contents) }
    }
}
