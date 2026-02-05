// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftUIRender",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftUIRender",
            targets: ["SwiftUIRender"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.4"),
    ],
    targets: [
        .target(
            name: "SwiftUIRender"
        ),
        .testTarget(
            name: "SwiftUIRenderTests",
            dependencies: ["SwiftUIRender"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "SwiftUIRenderSnapshotTests",
            dependencies: [
                "SwiftUIRender",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
