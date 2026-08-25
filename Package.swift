// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "APIPanel",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "APIPanel", targets: ["APIPanel"])
    ],
    targets: [
        .executableTarget(
            name: "APIPanel",
            path: "Sources/APIPanel"
        ),
        .testTarget(
            name: "APIPanelTests",
            dependencies: ["APIPanel"],
            path: "Tests/APIPanelTests"
        )
    ]
)

