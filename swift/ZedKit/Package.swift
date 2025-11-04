// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZedKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ZedKit",
            targets: ["ZedKit"]),
    ],
    targets: [
        .target(
            name: "ZedKit",
            dependencies: [],
            path: "Sources/ZedKit"
        ),
        .testTarget(
            name: "ZedKitTests",
            dependencies: ["ZedKit"],
            path: "Tests/ZedKitTests"
        ),
    ]
)
