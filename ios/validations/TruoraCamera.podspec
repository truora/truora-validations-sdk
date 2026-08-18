Pod::Spec.new do |s|
  s.name             = "TruoraCamera"
  s.version          = "1.3.2"
  s.summary          = "Truora's camera and face detection module for identity verification"
  s.description      = <<-DESC
TruoraCamera is an AVFoundation-based camera with on-device face detection (Vision/CoreML),
used by TruoraValidationsSDK to power biometric validation flows.
DESC
  s.homepage         = "https://bitbucket.org/truora/truora-sdks"
  s.documentation_url = "https://bitbucket.org/truora/truora-sdks/src/master/ios/validations/README.md"
  s.license          = { :type => "Proprietary", :text => "Copyright Truora. All rights reserved." }
  s.author           = { "Truora" => "truora-apps@truora.com" }
  s.platform         = :ios, "13.0"
  s.swift_version    = "5.9"
  s.cocoapods_version = ">= 1.10.0"

  s.source           = { :git => "https://bitbucket.org/truora/truora-sdks.git", :tag => s.version.to_s }

  # Patterns are listed twice so this podspec works in both source-resolution modes:
  #   - `:git` / trunk: source root is the repo root, paths use the
  #     `ios/validations/...` prefix.
  #   - `:path` pointing at `ios/validations/`: source root is that directory,
  #     paths are relative to it (no prefix).
  # Non-matching patterns are silently ignored by CocoaPods, so both coexist safely.
  s.source_files       = [
    "ios/validations/TruoraCamera/Sources/**/*.{swift}",
    "ios/validations/TensorFlowLite/Sources/**/*.{swift}",
    "ios/validations/Derived/Sources/TuistAssets+TruoraCamera.swift",
    "ios/validations/Derived/Sources/TuistBundle+TruoraCamera.swift",
    "TruoraCamera/Sources/**/*.{swift}",
    "TensorFlowLite/Sources/**/*.{swift}",
    "Derived/Sources/TuistAssets+TruoraCamera.swift",
    "Derived/Sources/TuistBundle+TruoraCamera.swift"
  ]
  s.resource_bundles = {
    "TruoraCameraResources" => [
      "ios/validations/TruoraCamera/Sources/Assets.xcassets",
      "ios/validations/TruoraCamera/Resources/**/*.tflite",
      "TruoraCamera/Sources/Assets.xcassets",
      "TruoraCamera/Resources/**/*.tflite"
    ]
  }

  # Bundle TensorFlowLiteC XCFramework — two paths for the same reason as source_files above.
  s.vendored_frameworks = [
    "ios/validations/XCFrameworks/TensorFlowLiteC.xcframework",
    "XCFrameworks/TensorFlowLiteC.xcframework"
  ]
  s.frameworks          = ["AVFoundation", "UIKit", "CoreGraphics", "Vision", "CoreML"]
  s.pod_target_xcconfig = {
    "PRODUCT_MODULE_NAME" => "TruoraCamera",
    "DEFINES_MODULE"      => "YES",
    "SWIFT_VERSION"       => "5.9",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Debug]"   => "COCOAPODS DEBUG",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Release]" => "COCOAPODS"
    }
end
