// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "windowmanager",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "windowmanager", targets: ["windowmanager"]),
        .library(name: "WindowManagerDomain", targets: ["WindowManagerDomain"]),
        .library(name: "WindowManagerAdapters", targets: ["WindowManagerAdapters"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.0"),
    ],
    targets: [
        .target(
            name: "WindowManagerDomain",
            path: "Sources/WindowManagerDomain"
        ),
        .target(
            name: "WindowManagerAdapters",
            dependencies: [
                "WindowManagerDomain",
                "TOMLKit",
            ],
            path: "Sources/WindowManagerAdapters"
        ),
        .executableTarget(
            name: "windowmanager",
            dependencies: [
                "WindowManagerDomain",
                "WindowManagerAdapters",
            ],
            path: "Sources/windowmanager"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: [
                "WindowManagerDomain",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "WindowManagerAdapters",
                "WindowManagerDomain",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/IntegrationTests"
        ),
    ]
)
