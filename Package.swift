// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "0.3.0")),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "0.5.2"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", .upToNextMinor(from: "0.47.4")),
    ],
    targets: [
        .target(
            name: "SotoCodeGenerator",
            dependencies: [
                .product(name: "SotoSmithy", package: "soto-smithy"),
                .product(name: "SotoSmithyAWS", package: "soto-smithy"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "HummingbirdMustache", package: "hummingbird-mustache"),
                .product(name: "SwiftFormat", package: "SwiftFormat")
            ],
            resources: [.process("Templates")]
        ),
    ]
)
