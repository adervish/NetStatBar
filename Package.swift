// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetStatBar",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "NetStatBar",
            path: "Sources/NetStatBar"
        )
    ]
)
