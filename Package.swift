// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Managed by VSXcode — changes will be overwritten

import PackageDescription

let package = Package(
    name: "BookManager",
    defaultLocalization: "de",
    platforms: [
        .iOS(.v17),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "BookManager",
            targets: ["BookManager"]
        )
    ],
    targets: [
        .target(
            name: "BookManager",
            path: "BookManager",
            resources: [
                .copy("AppIcon~ios-marketing.png"),
                .process("Assets.xcassets")
            ]
        )
    ]
)
