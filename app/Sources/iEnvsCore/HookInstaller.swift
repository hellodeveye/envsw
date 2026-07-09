import Foundation

/// Detects/installs the envsw shell-startup hook, byte-compatible with install.sh.
public struct HookInstaller {
    /// Must match install.sh's MARKER exactly (grep -qF).
    public static let marker = "# envsw: auto-load the active env profile"

    public let targetFile: URL
    public let snippet: String

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh") {
        // NOTE: the "\(Self.marker) of each group" line below (both branches) is
        // reproduced verbatim from install.sh, including the slightly awkward
        // "of each group" phrasing, for byte-compatible cross-tool marker
        // detection. Do not "fix" the wording here without also updating install.sh.
        if (shell as NSString).lastPathComponent == "bash" {
            targetFile = home.appendingPathComponent(".bashrc")
            snippet = """
            \(Self.marker) of each group
            for _envsw_f in "$HOME"/.envsw/*/current; do
              [ -f "$_envsw_f" ] && { set -a; . "$_envsw_f"; set +a; }
            done
            unset _envsw_f
            """
        } else {
            targetFile = home.appendingPathComponent(".zshenv")
            snippet = """
            \(Self.marker) of each group
            for _envsw_f in "$HOME"/.envsw/*/current(N); do
              set -a; source "$_envsw_f"; set +a
            done
            unset _envsw_f
            """
        }
    }

    public func isInstalled() -> Bool {
        guard let text = try? String(contentsOf: targetFile, encoding: .utf8) else { return false }
        return text.contains(Self.marker)
    }

    public func install() throws {
        guard !isInstalled() else { return }
        let existing: String
        if FileManager.default.fileExists(atPath: targetFile.path) {
            // File exists: read it for real. A genuine read/decode failure must
            // propagate (not be swallowed into ""), or we'd clobber the user's
            // existing dotfile content below.
            existing = try String(contentsOf: targetFile, encoding: .utf8)
        } else {
            existing = ""
        }
        try (existing + "\n" + snippet + "\n")
            .write(to: targetFile, atomically: true, encoding: .utf8)
    }
}
