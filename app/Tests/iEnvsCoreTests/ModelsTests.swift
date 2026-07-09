import XCTest
@testable import iEnvsCore

final class ModelsTests: XCTestCase {
    func testProductionLikeNamesArePlainProfiles() {
        let dev = Profile(name: "dev", url: URL(fileURLWithPath: "/tmp/g/dev.env"))
        let prod = Profile(name: "prod", url: URL(fileURLWithPath: "/tmp/g/prod.env"))

        let group = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: "prod")
        XCTAssertEqual(group.profiles.map(\.name), ["dev", "prod"])
        XCTAssertEqual(group.activeProfileName, "prod")
    }

    func testDangerNamesMatchCLI() {
        for name in ["prod", "production", "online", "live"] {
            XCTAssertTrue(Danger.isDangerous(name), "\(name) should be dangerous")
        }
        for name in ["dev", "staging", "prd", "Prod"] {
            XCTAssertFalse(Danger.isDangerous(name), "\(name) should not be dangerous")
        }
    }

    func testProfileAndGroupDanger() {
        let dev = Profile(name: "dev", url: URL(fileURLWithPath: "/tmp/g/dev.env"))
        let prod = Profile(name: "prod", url: URL(fileURLWithPath: "/tmp/g/prod.env"))
        XCTAssertFalse(dev.isDangerous)
        XCTAssertTrue(prod.isDangerous)

        let idle = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: nil)
        let safe = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: "dev")
        let hot = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: "prod")
        XCTAssertFalse(idle.hasDangerActive)
        XCTAssertFalse(safe.hasDangerActive)
        XCTAssertTrue(hot.hasDangerActive)
    }
}
