// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tassel",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure model code: no AppKit, so it can be exercised without a screen.
        .target(name: "TasselCore"),
        .executableTarget(name: "Tassel", dependencies: ["TasselCore"]),
        // Checks live in an executable rather than a .testTarget on purpose:
        // XCTest and swift-testing ship with Xcode, not the Command Line Tools,
        // so `swift test` fails on a machine that only has CLT installed.
        // `make check` works everywhere. See TESTING in README.md.
        .executableTarget(name: "TasselChecks", dependencies: ["TasselCore"]),
    ]
)
