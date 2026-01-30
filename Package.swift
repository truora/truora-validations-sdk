// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TruoraValidationsSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "TruoraValidationsSDK", targets: ["TruoraValidationsSDK"]),
        .library(name: "TruoraCamera", targets: ["TruoraCamera"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TruoraValidationsSDK",
            dependencies: ["TruoraCamera"],
            path: "ios/validations/TruoraValidationsSDK/Sources",
            swiftSettings: [.define("SWIFT_PACKAGE")]
        ),
        .target(
            name: "TruoraCamera",
            dependencies: ["TensorFlowLite"],
            path: "ios/validations/TruoraCamera/Sources",
            exclude: ["Assets.xcassets"]
        ),
        .target(
            name: "TensorFlowLite",
            dependencies: ["TensorFlowLiteC"],
            path: "ios/validations/TensorFlowLite/Sources"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            url: "https://github.com/truora/truora-validations-sdk/releases/download/0.0.1/TensorFlowLiteC.xcframework.zip",
            checksum: "422958bff515cc2d08ce853cb29691e718d798cf6f97c25c708ac2a2fa2cda69"
        )
    ]
)
