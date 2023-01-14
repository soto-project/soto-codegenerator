// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
        .library(name: "SotoCodeGeneratorLib", targets: ["SotoCodeGeneratorLib"])
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "1.0.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "SotoCodeGenerator",
            dependencies: [
                .byName(name: "SotoCodeGeneratorLib"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "SotoCodeGeneratorLib",
            dependencies: [
                .product(name: "SotoSmithy", package: "soto-smithy"),
                .product(name: "SotoSmithyAWS", package: "soto-smithy"),
                .product(name: "HummingbirdMustache", package: "hummingbird-mustache"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SotoCodeGeneratorTests",
            dependencies: [.byName(name: "SotoCodeGeneratorLib")]
        )
    ]
)
