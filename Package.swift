// swift-tools-version:5.7
import PackageDescription
let package = Package(
    name: "hyperesc",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "hyperesc",
            path: "Sources/hyperesc"
        )
    ]
)
