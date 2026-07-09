// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iEnvs",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "iEnvsCore"),
        .executableTarget(name: "iEnvs", dependencies: ["iEnvsCore"]),
        .testTarget(name: "iEnvsCoreTests", dependencies: ["iEnvsCore"]),
    ]
)
