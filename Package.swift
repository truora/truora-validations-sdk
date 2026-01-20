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
            url: "https://github.com/truora/truora-validations-sdk/releases/download/0.0.1/TruoraShared.xcframework.zip",
            checksum: "cf5010bca90438e7837a71a04d0c915e1ff219748fdd352a5a92ce03dcd5addb"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            url: "https://github.com/truora/truora-validations-sdk/releases/download/0.0.1/TensorFlowLiteC.xcframework.zip",
            checksum: "422958bff515cc2d08ce853cb29691e718d798cf6f97c25c708ac2a2fa2cda69"
        )
    ]
)
