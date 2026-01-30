// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TensorFlowLiteSwift",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "TensorFlowLiteSwift",
            targets: ["TensorFlowLiteSwift"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TensorFlowLiteSwift",
            dependencies: ["TensorFlowLiteC"],
            path: "Sources"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            path: "../XCFrameworks/TensorFlowLiteC.xcframework"
        )
    ]
)
