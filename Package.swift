// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DockDivider",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DockDivider", targets: ["DockDividerApp"])],
    targets: [
        .executableTarget(name: "DockDividerApp", path: "DockDividerApp", resources: [.process("Resources")]),
        .executableTarget(name: "DividerLauncher", path: "DividerLauncher"),
        .testTarget(name: "DockDividerTests", dependencies: ["DockDividerApp"], path: "Tests/DockDividerTests")
    ]
)
