Pod::Spec.new do |s|
  s.name             = "TruoraCamera"
  s.version          = "0.0.4-alpha.2"
  s.summary          = "Truora camera module to capture input for biometric validations"
  s.description      = <<-DESC
TruoraCamera is a camera module based on AVFoundation, with facial detection (Vision/CoreML)
used by TruoraValidationsSDK for passive capture and biometric flows.
DESC
  s.homepage         = "https://bitbucket.org/truora/truora-sdks"
  s.license          = { :type => "Proprietary", :text => "Copyright Truora. All rights reserved." }
  s.author           = { "Truora" => "truora-apps@truora.com" }
  s.platform         = :ios, "13.0"
  s.swift_version    = "5.9"
  s.static_framework = true
  s.source           = { :git => "https://bitbucket.org/truora/truora-sdks.git", :tag => s.version.to_s }

  s.source_files       = [ 
    "ios/validations/TruoraCamera/Sources/**/*.{swift}",
    "ios/validations/TensorFlowLite/Sources/**/*.{swift}",
    "ios/validations/Derived/Sources/TuistAssets+TruoraCamera.swift",
    "ios/validations/Derived/Sources/TuistBundle+TruoraCamera.swift"
  ]
  s.resource_bundles = { 
    "TruoraCameraResources" => [
      "ios/validations/TruoraCamera/Sources/Assets.xcassets",
      "ios/validations/TruoraCamera/Resources/**/*.tflite"
    ] 
  }
  
  # Bundle TensorFlowLiteC XCFramework
  s.vendored_frameworks = ["ios/validations/XCFrameworks/TensorFlowLiteC.xcframework"]
  s.frameworks          = ["AVFoundation", "UIKit", "CoreGraphics", "Vision", "CoreML"]
  s.pod_target_xcconfig = {
    "PRODUCT_MODULE_NAME" => "TruoraCamera",
    "DEFINES_MODULE"      => "YES",
    "SWIFT_VERSION"       => "5.9",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "COCOAPODS"
  }
end

