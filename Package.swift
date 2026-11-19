// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TruoraValidationsSDK",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v15)
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
        .target(
            name: "TruoraValidationsSDK",
            dependencies: ["TruoraCamera"],
            path: "ios/validations/TruoraValidationsSDK",
            sources: ["Sources"],
            resources: [.process("Resources")],
            swiftSettings: [.define("SWIFT_PACKAGE")]
        ),
        .target(
            name: "TruoraCamera",
            dependencies: ["TensorFlowLite"],
            path: "ios/validations/TruoraCamera",
            exclude: ["Sources/Assets.xcassets"],
            sources: ["Sources"],
            resources: [
                .process("Sources/Assets.xcassets"),
                .process("Resources")
            ],
            swiftSettings: [.define("SWIFT_PACKAGE")]
        ),
        .target(
            name: "TensorFlowLite",
            dependencies: ["TensorFlowLiteC"],
            path: "ios/validations/TensorFlowLite/Sources"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            path: "ios/validations/XCFrameworks/TensorFlowLiteC.xcframework"
        )
    ]
)
