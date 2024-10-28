// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "rss-debrider",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(name: "rss-debrider",
                          dependencies: [
                            .product(name: "ArgumentParser", package: "swift-argument-parser"),
                            .product(name: "Logging", package: "swift-log"),
                          ],
                          resources: [.process("Resources")])
    ],
    swiftLanguageModes: [.v6]
)


