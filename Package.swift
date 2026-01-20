// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TruoraValidationsSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "TruoraValidationsSDK",
            targets: ["TruoraValidationsSDK"]
        ),
        .library(
            name: "TruoraCamera",
            targets: ["TruoraCamera"]
        )
    ],
    dependencies: [],
    targets: [
        // Main SDK target
        .target(
            name: "TruoraValidationsSDK",
            dependencies: [
                "TruoraCamera",
                "TruoraShared"
            ],
            path: "ios/validations/TruoraValidationsSDK/Sources",
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        // Camera module
        .target(
            name: "TruoraCamera",
            dependencies: [
                "TensorFlowLite"
            ],
            path: "ios/validations/TruoraCamera/Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        // TensorFlowLite Swift wrapper
        .target(
            name: "TensorFlowLite",
            dependencies: [
                "TensorFlowLiteC"
            ],
            path: "ios/validations/TensorFlowLite/Sources"
        ),
        // Binary targets
        .binaryTarget(
            name: "TruoraShared",
            url: "https://github.com/bescobar-truora/TruoraValidationsSDK/releases/download/0.0.4/TruoraShared.xcframework.zip",
            checksum: "b3f5b4a4be7c2144db8cc3a4daf22a531ad171b7d11bf49f4fbe6f3e6189b5ee"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            url: "https://github.com/bescobar-truora/TruoraValidationsSDK/releases/download/0.0.4/TensorFlowLiteC.xcframework.zip",
            checksum: "c456f45a143f26d56a45311da8750022951fcb14934cde08de20c3d3d465be7e"
        )
    ]
)
