import AppKit
import Foundation
import iEnvsCore

@MainActor
final class AppState: ObservableObject {
    @Published var groups: [ProfileGroup] = []
    @Published var groupCreationRequest = 0
    @Published var profileCreationRequest = 0
    let store: ProfileStore
    private var watcher: DirectoryWatcher?

    init(store: ProfileStore = ProfileStore()) {
        self.store = store
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

    func requestNewGroupCreation() {
        groupCreationRequest += 1
    }

    func requestNewProfileCreation() {
        profileCreationRequest += 1
    }

    func promptNewGroup() {
        guard let name = Prompt.text(title: "New Group", message: "Group name (e.g. myapp):") else { return }
        createGroup(name)
    }

    @discardableResult
    func createGroup(_ name: String) -> Bool {
        run { try store.createGroup(name) }
    }

    func createGroupInline(_ name: String) -> Result<Void, Error> {
        attempt { try store.createGroup(name) }
    }

    @discardableResult
    func run(_ body: () throws -> Void) -> Bool {
        switch attempt(body) {
        case .success:
            return true
        case .failure(let error):
            Prompt.error(error)
            return false
        }
    }

    private func attempt(_ body: () throws -> Void) -> Result<Void, Error> {
        do {
            try body()
            reload()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func promptNewProfile(group: String) {
        guard let name = Prompt.text(title: "New Profile in \u{201C}\(group)\u{201D}",
                                      message: "Profile name (e.g. dev, staging, prod):") else { return }
        if createProfile(group: group, profile: name) {
            EditorWindowController.open(ProfileRef(group: group, profile: name), state: self)
        }
    }

    @discardableResult
    func createProfile(group: String, profile: String) -> Bool {
        run { try store.createProfile(group: group, profile: profile) }
    }

    func createProfileInline(group: String, profile: String) -> Result<Void, Error> {
        attempt { try store.createProfile(group: group, profile: profile) }
    }

    func deleteProfile(group: String, profile: String) {
        guard Prompt.confirm(
            title: "Delete profile \u{201C}\(profile)\u{201D} from \u{201C}\(group)\u{201D}?",
            message: "This removes \(profile).env. If it is active, the group is deactivated."
        ) else { return }
        if run({ try store.deleteProfile(group: group, profile: profile) }) {
            EditorWindowController.close(ProfileRef(group: group, profile: profile))
        }
    }

    func deleteGroup(_ name: String) {
        let groupPath = store.root.appendingPathComponent(name, isDirectory: true).path
        guard Prompt.confirm(
            title: "Delete group \u{201C}\(name)\u{201D}?",
            message: "This removes the whole \(groupPath) directory and all its profiles."
        ) else { return }
        if run({ try store.deleteGroup(name) }) {
            EditorWindowController.closeGroup(name)
        }
    }

    func renameGroupInline(_ oldName: String, to newName: String) -> Result<Void, Error> {
        attempt {
            try store.renameGroup(oldName, to: newName)
            EditorWindowController.closeGroup(oldName)
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
