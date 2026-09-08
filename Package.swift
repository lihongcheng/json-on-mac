// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "JSONLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "JSONLens", targets: ["JSONLens"])
    ],
    targets: [
        .executableTarget(
            name: "JSONLens",
            path: "Sources/JSONLens"
        )
    ]
)
