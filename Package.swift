// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Lumink",
    defaultLocalization: "pt",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Lumink",
            path: "Sources/Lumink"
        )
    ]
)
