// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "soto-codegen",
    products: [
        .executable(name: "SotoCodeGen", targets: ["SotoCodegen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/adam-fowler/soto-smithy.git", .upToNextMajor(from: "0.2.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "0.3.0")),
        .package(url: "https://github.com/soto-project/Stencil.git", .upToNextMajor(from: "0.13.2")),
    ],
    targets: [
        .target(
            name: "SotoCodegen",
            dependencies: [
                .product(name: "SotoSmithy", package: "soto-smithy"),
                .product(name: "SotoSmithyAWS", package: "soto-smithy"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Stencil", package: "Stencil")]
            , resources: [.process("Templates")]
        ),
    ]
)
