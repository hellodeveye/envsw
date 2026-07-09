import XCTest
@testable import iEnvsCore

final class DirectoryWatcherTests: XCTestCase {
    func testFiresOnFileCreationInSubdirectory() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("ienvs-watch-\(UUID().uuidString)", isDirectory: true)
        let sub = dir.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let exp = expectation(description: "change detected")
        exp.assertForOverFulfill = false
        let watcher = DirectoryWatcher(url: dir, latency: 0.1) { exp.fulfill() }
        XCTAssertNotNil(watcher)

        // FSEvents needs a beat to start delivering; then touch a file.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            try? "X=1\n".write(to: sub.appendingPathComponent("dev.env"),
                               atomically: true, encoding: .utf8)
        }

        wait(for: [exp], timeout: 10)
        watcher?.stop()
        watcher?.stop() // idempotent
    }
}
