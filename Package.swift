// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "soto-codegen",
    products: [
        .executable(name: "SotoCodeGen", targets: ["SotoCodegen"]),
        .library(name: "SotoSmithy", targets: ["SotoSmithy"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "0.0.1")),
//        .package(url: "https://github.com/swift-aws/Stencil.git", .upToNextMajor(from: "0.13.2")),
    ],
    targets: [
        .target(name: "SotoCodegen", dependencies: ["ArgumentParser", "SotoSmithy"]),
        .target(name: "SotoSmithy", dependencies: []),
        .testTarget(name: "SotoSmithyTests", dependencies: ["SotoSmithy"]),
    ]
)
