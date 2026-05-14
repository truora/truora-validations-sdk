Pod::Spec.new do |s|
  s.name             = "TruoraValidationsSDK"
  s.version          = "1.3.0-alpha.1"
  s.summary          = "Truora's iOS SDK for identity verification and biometric validations"
  s.description      = <<-DESC
TruoraValidationsSDK lets you embed Truora's identity verification flows into your iOS app.
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
    "ios/validations/TruoraValidationsSDK/Sources/**/*.{swift}",
    "ios/validations/Derived/Sources/TuistAssets+TruoraValidationsSDK.swift",
    "ios/validations/Derived/Sources/TuistBundle+TruoraValidationsSDK.swift",
    "ios/validations/Derived/Sources/TuistStrings+TruoraValidationsSDK.swift",
    "TruoraValidationsSDK/Sources/**/*.{swift}",
    "Derived/Sources/TuistAssets+TruoraValidationsSDK.swift",
    "Derived/Sources/TuistBundle+TruoraValidationsSDK.swift",
    "Derived/Sources/TuistStrings+TruoraValidationsSDK.swift"
  ]
  s.resource_bundles = {
    "validations_TruoraValidationsSDK" => [
      "ios/validations/TruoraValidationsSDK/Resources/**/*.strings",
      "ios/validations/TruoraValidationsSDK/Resources/Assets.xcassets",
      "ios/validations/TruoraValidationsSDK/Resources/Audio/*.mp3",
      "ios/validations/TruoraValidationsSDK/Resources/*.gif",
      "TruoraValidationsSDK/Resources/**/*.strings",
      "TruoraValidationsSDK/Resources/Assets.xcassets",
      "TruoraValidationsSDK/Resources/Audio/*.mp3",
      "TruoraValidationsSDK/Resources/*.gif"
    ]
  }
  s.frameworks         = ["UIKit", "Foundation", "SwiftUI"]
  s.dependency         "TruoraCamera", "1.3.0-alpha.1"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_VERSION"  => "5.9",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Debug]"   => "COCOAPODS DEBUG",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Release]" => "COCOAPODS"
    }
end
