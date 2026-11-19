// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToggleTask",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ToggleTask", targets: ["ToggleTask"])],
    targets: [
        .executableTarget(name: "ToggleTask"),
        .testTarget(name: "ToggleTaskTests", dependencies: ["ToggleTask"])
    ]
)
