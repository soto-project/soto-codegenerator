// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "soto-codegenerator",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "SotoCodeGenerator", targets: ["SotoCodeGenerator"]),
        .plugin(name: "SotoCodeGeneratorPlugin", targets: ["SotoCodeGeneratorPlugin"]),
        .plugin(name: "SotoCodeModelDownloaderPlugin",targets: ["SotoCodeModelDownloaderPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-smithy.git", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "1.0.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0")
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
        .executableTarget(
            name: "SotoModelDownloader",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
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
        .plugin(
            name: "SotoCodeGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["SotoCodeGenerator"]
        ),
        .plugin(
            name: "SotoCodeModelDownloaderPlugin",
            capability: .command(
             intent: .custom(
              verb: "get-soto-models",
              description: "Download the required Model file schema required for soto code genrator to work"),
             permissions: [
                .writeToPackageDirectory(reason: "Write the Model files into target project"),
                .allowNetworkConnections(
                    scope: .all(ports: []),
                    reason: "The plugin needs to download resource's from remote server"
                )
             ]),
            dependencies: ["SotoModelDownloader"]
          ),
        .testTarget(
            name: "SotoCodeGeneratorTests",
            dependencies: ["SotoCodeGeneratorLib"]
        )
    ]
)
