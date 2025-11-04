// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZedMobile",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ZedMobile",
            targets: ["ZedMobile"]),
    ],
    targets: [
        .target(
            name: "ZedMobile",
            dependencies: [],
            path: "Sources/ZedMobile"
        ),
        .testTarget(
            name: "ZedMobileTests",
            dependencies: ["ZedMobile"],
            path: "Tests/ZedMobileTests"
        ),
    ]
)
