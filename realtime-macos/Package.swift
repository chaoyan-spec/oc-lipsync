// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PAPAluLive",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "PAPAluLive", targets: ["PAPAluLive"]),
    ],
    targets: [
        .executableTarget(name: "PAPAluLive"),
        .testTarget(
            name: "PAPAluLiveTests",
            dependencies: ["PAPAluLive"],
            exclude: ["main.swift"]
        ),
    ]
)
