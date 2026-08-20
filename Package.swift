// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Arthur",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Arthur", targets: ["Arthur"])
    ],
    targets: [
        .target(name: "Arthur"),
        .testTarget(name: "ArthurTests", dependencies: ["Arthur"])
    ]
)
