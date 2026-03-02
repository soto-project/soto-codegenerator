// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
        .plugin(name: "SotoCodeGeneratorPlugin", targets: ["SotoCodeGeneratorPlugin"]),
        .plugin(name: "SotoModelDownloaderPlugin", targets: ["SotoModelDownloaderPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", from: "0.4.7"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "SotoCodeGenerator",
            dependencies: [
                .byName(name: "SotoCodeGeneratorLib"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .executableTarget(
            name: "SotoModelDownloader",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "SotoCodeGeneratorLib",
            dependencies: [
                .product(name: "SotoSmithy", package: "soto-smithy"),
                .product(name: "SotoSmithyAWS", package: "soto-smithy"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .plugin(
            name: "SotoCodeGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["SotoCodeGenerator"]
        ),
        .plugin(
            name: "SotoModelDownloaderPlugin",
            capability: .command(
                intent: .custom(
                    verb: "download-aws-models",
                    description: "Download AWS Smithy API model files for the Soto Code Generator"
                ),
                permissions: [
                    .allowNetworkConnections(scope: .all(ports: [443]), reason: "Download AWS Smithy API model files from GitHub"),
                    .writeToPackageDirectory(reason: "Save AWS Smithy API models to target"),
                ]
            ),
            dependencies: ["SotoModelDownloader"]
        ),
        .testTarget(
            name: "SotoCodeGeneratorTests",
            dependencies: ["SotoCodeGeneratorLib"]
        ),
    ]
)
