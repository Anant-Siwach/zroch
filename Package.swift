// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zroch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Zroch", path: "Sources/Zroch")
    ]
)
