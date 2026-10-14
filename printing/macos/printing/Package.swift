// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "printing",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(name: "printing", targets: ["printing"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "printing",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ]
        ),
    ]
)
