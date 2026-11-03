// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snappy",
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(name: "Snappy", path: "Sources/Snappy")
    ]
)
