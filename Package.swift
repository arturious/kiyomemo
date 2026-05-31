// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MemoryBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MemoryBar", targets: ["MemoryBar"]),
        .executable(name: "MemoryBarHelper", targets: ["MemoryBarHelper"])
    ],
    targets: [
        .executableTarget(
            name: "MemoryBar",
            path: "Sources/MemoryBar"
        ),
        .executableTarget(
            name: "MemoryBarHelper",
            path: "Sources/MemoryBarHelper"
        )
    ]
)
