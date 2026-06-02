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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "Kiyomemo",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Kiyomemo"
        ),
        .executableTarget(
            name: "KiyomemoHelper",
            path: "Sources/KiyomemoHelper"
        )
    ]
)
