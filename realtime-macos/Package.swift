// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LiveCharacter",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "LiveCharacter", targets: ["PAPAluLive"]),
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
