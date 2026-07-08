import Foundation

public enum ProfileStoreError: Error, Equatable, LocalizedError {
    case invalidName(String)
    case profileNotFound(group: String, profile: String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let n):
            return "Invalid name “\(n)” — must be non-empty, without “/”, not start with “.”, and not be “current”."
        case .profileNotFound(let g, let p):
            return "Profile “\(p)” not found in group “\(g)”."
        }
    }
}

/// All state lives under `root` (default ~/.envsw), shared with the envsw CLI.
public final class ProfileStore {
    public let root: URL
    private let fm = FileManager.default

    public init(root: URL = ProfileStore.defaultRoot()) {
        self.root = root
    }

    public static func defaultRoot() -> URL {
        if let custom = ProcessInfo.processInfo.environment["ENVSW_ROOT"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".envsw", isDirectory: true)
    }

    // MARK: - Scan

    public func scan() -> [ProfileGroup] {
        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var groups: [ProfileGroup] = []
        for dir in entries {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            let profiles = files
                .filter { $0.pathExtension == "env" }
                .map { Profile(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
                .sorted { $0.name < $1.name }
            groups.append(ProfileGroup(name: dir.lastPathComponent,
                                       profiles: profiles,
                                       activeProfileName: activeProfile(inGroupDir: dir)))
        }
        return groups.sorted { $0.name < $1.name }
    }

    // MARK: - Switch

    public func use(group: String, profile: String) throws {
        try validate(group)
        try validate(profile)
        let dir = root.appendingPathComponent(group, isDirectory: true)
        let file = dir.appendingPathComponent("\(profile).env")
        guard fm.fileExists(atPath: file.path) else {
            throw ProfileStoreError.profileNotFound(group: group, profile: profile)
        }
        let link = dir.appendingPathComponent("current")
        try? fm.removeItem(at: link) // ln -sfn semantics
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "\(profile).env")
    }

    public func off(group: String) {
        try? fm.removeItem(at: root.appendingPathComponent(group).appendingPathComponent("current"))
    }

    private func activeProfile(inGroupDir dir: URL) -> String? {
        let link = dir.appendingPathComponent("current")
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: link.path) else { return nil }
        let destURL = URL(fileURLWithPath: dest, relativeTo: dir)
        guard fm.fileExists(atPath: destURL.path) else { return nil } // broken link
        return destURL.deletingPathExtension().lastPathComponent
    }

    // MARK: - Create / delete / read / write

    public func createGroup(_ name: String) throws {
        try validate(name)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    @discardableResult
    public func createProfile(group: String, profile: String) throws -> URL {
        try validate(group)
        try validate(profile)
        try createGroup(group)
        let file = root.appendingPathComponent(group).appendingPathComponent("\(profile).env")
        if !fm.fileExists(atPath: file.path) {
            // Same template as the CLI's `envsw edit` (note the em-dash)
            let template = "# \(group) / \(profile) — KEY=VALUE per line, no \"export\"\n"
            try template.write(to: file, atomically: true, encoding: .utf8)
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    public func deleteProfile(group: String, profile: String) throws {
        let dir = root.appendingPathComponent(group, isDirectory: true)
        let file = dir.appendingPathComponent("\(profile).env")
        guard fm.fileExists(atPath: file.path) else {
            throw ProfileStoreError.profileNotFound(group: group, profile: profile)
        }
        if activeProfile(inGroupDir: dir) == profile { off(group: group) }
        try fm.removeItem(at: file)
    }

    public func deleteGroup(_ name: String) throws {
        try fm.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
    }

    public func readProfile(group: String, profile: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(group).appendingPathComponent("\(profile).env"),
                   encoding: .utf8)
    }

    public func writeProfile(group: String, profile: String, contents: String) throws {
        let file = root.appendingPathComponent(group).appendingPathComponent("\(profile).env")
        guard fm.fileExists(atPath: file.path) else {
            throw ProfileStoreError.profileNotFound(group: group, profile: profile)
        }
        try contents.write(to: file, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func validate(_ name: String) throws {
        let bad = name.isEmpty || name.contains("/") || name.hasPrefix(".") || name == "current"
        if bad { throw ProfileStoreError.invalidName(name) }
    }
}
