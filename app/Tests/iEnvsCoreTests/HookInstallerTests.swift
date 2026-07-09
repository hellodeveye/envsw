import XCTest
@testable import iEnvsCore

final class HookInstallerTests: XCTestCase {
    var home: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        home = fm.temporaryDirectory
            .appendingPathComponent("ienvs-home-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: home)
    }

    func testTargetFilePerShell() {
        XCTAssertEqual(HookInstaller(home: home, shell: "/bin/zsh").targetFile.lastPathComponent, ".zshenv")
        XCTAssertEqual(HookInstaller(home: home, shell: "/opt/homebrew/bin/bash").targetFile.lastPathComponent, ".bashrc")
    }

    func testInstallCreatesFileAndIsDetected() throws {
        let installer = HookInstaller(home: home, shell: "/bin/zsh")
        XCTAssertFalse(installer.isInstalled())

        try installer.install()

        XCTAssertTrue(installer.isInstalled())
        let text = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertTrue(text.contains(HookInstaller.marker))
        XCTAssertTrue(text.contains(#"/.envsw/*/current(N)"#)) // zsh variant
    }

    func testInstallAppendsToExistingFileAndIsIdempotent() throws {
        let installer = HookInstaller(home: home, shell: "/bin/bash")
        try "export FOO=bar\n".write(to: installer.targetFile, atomically: true, encoding: .utf8)

        try installer.install()
        let once = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertTrue(once.hasPrefix("export FOO=bar\n")) // existing content preserved
        XCTAssertTrue(once.contains(#"[ -f "$_envsw_f" ]"#)) // bash variant

        try installer.install() // second install must not duplicate
        let twice = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertEqual(once, twice)
    }

    func testInstallDoesNotClobberUnreadableFile() throws {
        let installer = HookInstaller(home: home, shell: "/bin/zsh")
        let originalBytes = Data([0xFF, 0xFE, 0xFD])
        try originalBytes.write(to: installer.targetFile)

        XCTAssertThrowsError(try installer.install())

        XCTAssertEqual(try Data(contentsOf: installer.targetFile), originalBytes)
    }
}
