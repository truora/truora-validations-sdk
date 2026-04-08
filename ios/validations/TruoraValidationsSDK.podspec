Pod::Spec.new do |s|
  s.name             = "TruoraValidationsSDK"
  s.version          = "1.2.6-beta.1"
  s.summary          = "SDK of biometric validations"
  s.description      = <<-DESC
TruoraValidationsSDK provides a complete biometric validation flow,
including base image upload, status check, passive capture in face, and get input from ID document.
DESC
  s.homepage         = "https://bitbucket.org/truora/truora-sdks"
  s.license          = { :type => "Proprietary", :text => "Copyright Truora. All rights reserved." }
  s.author           = { "Truora" => "truora-apps@truora.com" }
  s.platform         = :ios, "13.0"
  s.swift_version    = "5.9"

  s.source           = { :git => "https://bitbucket.org/truora/truora-sdks.git", :tag => s.version.to_s }
  s.source_files       = [
    "ios/validations/TruoraValidationsSDK/Sources/**/*.{swift}",
    "ios/validations/Derived/Sources/TuistAssets+TruoraValidationsSDK.swift",
    "ios/validations/Derived/Sources/TuistBundle+TruoraValidationsSDK.swift",
    "ios/validations/Derived/Sources/TuistStrings+TruoraValidationsSDK.swift"
  ]
  s.resource_bundles = {
    "validations_TruoraValidationsSDK" => [
      "ios/validations/TruoraValidationsSDK/Resources/**/*.strings",
      "ios/validations/TruoraValidationsSDK/Resources/Assets.xcassets",
      "ios/validations/TruoraValidationsSDK/Resources/Audio/*.mp3",
      "ios/validations/TruoraValidationsSDK/Resources/*.gif"
    ]
  }
  s.frameworks         = ["UIKit", "Foundation", "SwiftUI"]
  s.dependency         "TruoraCamera", "1.2.6-beta.1"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_VERSION"  => "5.9",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Debug]"   => "COCOAPODS DEBUG",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Release]" => "COCOAPODS"
    }
end
