// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VKLogging",
    platforms: [.macOS(.v15), .iOS(.v15)],
    products: [
        .library(name: "VKLogging", targets: ["VKLogging"]),
        .executable(name: "VKLoggingCLI", targets: ["CLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "VKLogging",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: ["VKLogging"]
          ),
    ]
)
