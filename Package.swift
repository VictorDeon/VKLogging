// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VKLoggingPublicLibrary",
    platforms: [.macOS(.v15), .iOS(.v15)],
    products: [
        .library(
            name: "VKLoggingPublicLibrary",
            targets: ["VKLoggingPublicLibrary"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "VKLoggingPublicLibrary",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
    ]
)
