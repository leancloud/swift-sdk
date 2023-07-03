// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LeanCloud",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "LeanCloud", targets: ["LeanCloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.7.0")),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMajor(from: "1.22.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "5.26.0"))
    ],
    targets: [
        .target(
            name: "LeanCloud",
            dependencies: [
                "Alamofire",
                "SwiftProtobuf",
                "GRDB"
            ],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
