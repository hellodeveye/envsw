import Foundation

public enum Danger {
    /// Must match the CLI's is_danger(): prod|production|online|live
    public static let names: Set<String> = ["prod", "production", "online", "live"]
    public static func isDangerous(_ profileName: String) -> Bool { names.contains(profileName) }
}

public struct Profile: Hashable {
    public let name: String
    public let url: URL
    public var isDangerous: Bool { Danger.isDangerous(name) }

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct ProfileGroup: Hashable {
    public let name: String
    public let profiles: [Profile]
    public let activeProfileName: String?

    public init(name: String, profiles: [Profile], activeProfileName: String?) {
        self.name = name
        self.profiles = profiles
        self.activeProfileName = activeProfileName
    }

    public var hasDangerActive: Bool {
        guard let active = activeProfileName else { return false }
        return Danger.isDangerous(active)
    }
}
