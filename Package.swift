// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CurlmanNative",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CurlmanNative", targets: ["CurlmanNative"])
    ],
    targets: [
        .executableTarget(
            name: "CurlmanNative",
            path: "Sources/CurlmanNative"
        ),
        .testTarget(
            name: "CurlmanNativeTests",
            dependencies: ["CurlmanNative"],
            path: "Tests/CurlmanNativeTests"
        )
    ]
)

