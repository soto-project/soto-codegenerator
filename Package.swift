// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
        .plugin(name: "SotoCodeGeneratorPlugin", targets: ["SotoCodeGeneratorPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "1.0.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.48.17"),
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
                .product(name: "SwiftFormat", package: "SwiftFormat"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .plugin(
            name: "SotoCodeGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["SotoCodeGenerator"]
        ),
        .testTarget(
            name: "SotoCodeGeneratorTests",
            dependencies: ["SotoCodeGeneratorLib"]
        )
    ]
)
