// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", from: "0.2.4"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "1.0.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", .exact("0.48.17")),
    ],
    targets: [
        .target(
            name: "SotoCodeGenerator",
            dependencies: [
                .byName(name: "SotoCodeGeneratorLib"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SotoCodeGeneratorLib",
            dependencies: [
                .product(name: "SotoSmithy", package: "soto-smithy"),
                .product(name: "SotoSmithyAWS", package: "soto-smithy"),
                .product(name: "HummingbirdMustache", package: "hummingbird-mustache"),
                .product(name: "SwiftFormat", package: "SwiftFormat")
            ]
        ),
        .testTarget(
            name: "SotoCodeGeneratorTests",
            dependencies: [.byName(name: "SotoCodeGeneratorLib")]
        )
    ]
)
