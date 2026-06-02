// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Kiyomemo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Kiyomemo", targets: ["Kiyomemo"]),
        .executable(name: "KiyomemoHelper", targets: ["KiyomemoHelper"])
    ],
    targets: [
        .executableTarget(
            name: "Kiyomemo",
            path: "Sources/Kiyomemo"
        ),
        .executableTarget(
            name: "KiyomemoHelper",
            path: "Sources/KiyomemoHelper"
        )
    ]
)
