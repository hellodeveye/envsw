import XCTest
@testable import iEnvsCore

final class ProfileStoreTests: XCTestCase {
    var root: URL!
    var store: ProfileStore!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent("ienvs-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        store = ProfileStore(root: root)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    /// Fixture: create <group>/<profile>.env files, optionally a current symlink.
    func makeGroup(_ group: String, profiles: [String], active: String? = nil) throws {
        let dir = root.appendingPathComponent(group, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for p in profiles {
            try "KEY=\(p)\n".write(to: dir.appendingPathComponent("\(p).env"),
                                   atomically: true, encoding: .utf8)
        }
        if let active {
            try fm.createSymbolicLink(atPath: dir.appendingPathComponent("current").path,
                                      withDestinationPath: "\(active).env")
        }
    }

    // MARK: scan

    func testScanMissingRootReturnsEmpty() {
        let ghost = ProfileStore(root: root.appendingPathComponent("nope"))
        XCTAssertEqual(ghost.scan(), [])
    }

    func testScanFindsGroupsProfilesAndActiveSorted() throws {
        try makeGroup("zoo", profiles: ["dev"], active: nil)
        try makeGroup("myapp", profiles: ["prod", "dev"], active: "dev")

        let groups = store.scan()
        XCTAssertEqual(groups.map(\.name), ["myapp", "zoo"])          // groups sorted
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev", "prod"]) // profiles sorted
        XCTAssertEqual(groups[0].activeProfileName, "dev")
        XCTAssertNil(groups[1].activeProfileName)
    }

    func testScanIgnoresBrokenSymlinkAndNonEnvFiles() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        let dir = root.appendingPathComponent("myapp")
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("current").path,
                                  withDestinationPath: "gone.env") // broken link
        try "junk".write(to: dir.appendingPathComponent("notes.txt"),
                         atomically: true, encoding: .utf8)

        let groups = store.scan()
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].activeProfileName)                 // broken → not active
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev"])   // .txt ignored
    }

    func testScanIgnoresEnvDirectoriesAndHiddenEnvFiles() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        let dir = root.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: dir.appendingPathComponent("prod.env", isDirectory: true),
                               withIntermediateDirectories: false)
        try "SECRET=1\n".write(to: dir.appendingPathComponent(".hidden.env"),
                               atomically: true, encoding: .utf8)

        let groups = store.scan()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev"])
    }

    // MARK: use / off

    func testUseRepointsSymlinkWithRelativeDestination() throws {
        try makeGroup("myapp", profiles: ["dev", "prod"], active: "dev")

        try store.use(group: "myapp", profile: "prod")

        let link = root.appendingPathComponent("myapp/current")
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: link.path), "prod.env")
        XCTAssertEqual(store.scan()[0].activeProfileName, "prod")
    }

    func testUseMissingProfileThrows() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        XCTAssertThrowsError(try store.use(group: "myapp", profile: "ghost")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "ghost"))
        }
    }

    func testUseRejectsEnvDirectory() throws {
        let dir = root.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.createDirectory(at: dir.appendingPathComponent("prod.env", isDirectory: true),
                               withIntermediateDirectories: false)

        XCTAssertThrowsError(try store.use(group: "myapp", profile: "prod")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "prod"))
        }
    }

    func testOffRemovesCurrentAndIsIdempotent() throws {
        try makeGroup("myapp", profiles: ["dev"], active: "dev")

        store.off(group: "myapp")
        XCTAssertNil(store.scan()[0].activeProfileName)
        store.off(group: "myapp") // second call must not crash
    }

    // MARK: create / delete / read / write

    private func perms(_ url: URL) throws -> Int {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        return (attrs[.posixPermissions] as! NSNumber).intValue
    }

    func testCreateProfileWritesTemplateWithPermissions() throws {
        let file = try store.createProfile(group: "myapp", profile: "dev")

        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(text, "# myapp / dev — KEY=VALUE per line, no \"export\"\n")
        XCTAssertEqual(try perms(file), 0o600)
        XCTAssertEqual(try perms(root.appendingPathComponent("myapp")), 0o700)
        XCTAssertEqual(try perms(root), 0o700)
    }

    func testCreateProfileDoesNotOverwriteExisting() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        let file = try store.createProfile(group: "myapp", profile: "dev")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "KEY=dev\n")
    }

    func testCreateProfileRejectsEnvDirectoryAndDoesNotChmodIt() throws {
        let dir = root.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let profileDir = dir.appendingPathComponent("prod.env", isDirectory: true)
        try fm.createDirectory(at: profileDir, withIntermediateDirectories: false)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: profileDir.path)

        XCTAssertThrowsError(try store.createProfile(group: "myapp", profile: "prod")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "prod"))
        }
        XCTAssertEqual(try perms(profileDir), 0o700)
    }

    func testWriteAndReadProfileKeepsPermissions() throws {
        try store.createProfile(group: "myapp", profile: "dev")

        try store.writeProfile(group: "myapp", profile: "dev", contents: "A=1\nB=2\n")

        XCTAssertEqual(try store.readProfile(group: "myapp", profile: "dev"), "A=1\nB=2\n")
        XCTAssertEqual(try perms(root.appendingPathComponent("myapp/dev.env")), 0o600)
    }

    func testWriteMissingProfileThrowsAndDoesNotCreateFile() throws {
        try store.createGroup("myapp")
        let file = root.appendingPathComponent("myapp/ghost.env")

        XCTAssertThrowsError(
            try store.writeProfile(group: "myapp", profile: "ghost", contents: "A=1\n")
        ) { error in
            XCTAssertEqual(
                error as? ProfileStoreError,
                .profileNotFound(group: "myapp", profile: "ghost")
            )
        }
        XCTAssertFalse(fm.fileExists(atPath: file.path))
    }

    func testReadWriteDeleteRejectEnvDirectory() throws {
        let dir = root.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.createDirectory(at: dir.appendingPathComponent("prod.env", isDirectory: true),
                               withIntermediateDirectories: false)

        XCTAssertThrowsError(try store.readProfile(group: "myapp", profile: "prod"))
        XCTAssertThrowsError(try store.writeProfile(group: "myapp", profile: "prod", contents: "A=1\n")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "prod"))
        }
        XCTAssertThrowsError(try store.deleteProfile(group: "myapp", profile: "prod")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "prod"))
        }
    }

    func testScanIgnoresActiveSymlinkPointingToEnvDirectory() throws {
        let dir = root.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "KEY=dev\n".write(to: dir.appendingPathComponent("dev.env"),
                              atomically: true, encoding: .utf8)
        try fm.createDirectory(at: dir.appendingPathComponent("prod.env", isDirectory: true),
                               withIntermediateDirectories: false)
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("current").path,
                                  withDestinationPath: "prod.env")

        let groups = store.scan()

        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev"])
        XCTAssertNil(groups[0].activeProfileName)
    }

    func testDeleteActiveProfileClearsCurrent() throws {
        try makeGroup("myapp", profiles: ["dev", "prod"], active: "dev")

        try store.deleteProfile(group: "myapp", profile: "dev")

        let group = store.scan()[0]
        XCTAssertEqual(group.profiles.map(\.name), ["prod"])
        XCTAssertNil(group.activeProfileName)
    }

    func testDeleteGroupRemovesDirectory() throws {
        try makeGroup("myapp", profiles: ["dev"], active: "dev")
        try store.deleteGroup("myapp")
        XCTAssertEqual(store.scan(), [])
    }

    func testInvalidNamesThrow() {
        for bad in ["", "a/b", ".hidden", "current"] {
            XCTAssertThrowsError(try store.createGroup(bad), "group “\(bad)”")
            XCTAssertThrowsError(try store.createProfile(group: "ok", profile: bad), "profile “\(bad)”")
            XCTAssertThrowsError(try store.use(group: bad, profile: "dev"), "use group “\(bad)”")
        }
    }
}
