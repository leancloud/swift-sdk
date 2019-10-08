// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LeanCloud",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "LeanCloud", targets: ["LeanCloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .exact("5.0.0-rc.2")),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "3.1.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "4.4.0"))
    ],
    targets: [
        .target(
            name: "LeanCloud",
            dependencies: [
                "Alamofire",
                "SwiftProtobuf",
                "Starscream",
                "GRDB"
            ],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
