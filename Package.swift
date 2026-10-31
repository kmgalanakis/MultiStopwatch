// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stopwatches",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Stopwatches", path: "Sources/Stopwatches")
    ]
)
