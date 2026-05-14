# Truora Validations iOS SDK

A modular iOS SDK for face, document, and invoice (proof of address) validation using VIPER architecture, built with Tuist and integrating Kotlin Multiplatform (KMP) modules for API and UI.

## Overview

This SDK provides three validation flows:

- **Face validation** — Enrollment, base image upload, passive face capture, and result display
- **Document validation** — Capture document photos with country/document-type selection
- **Invoice validation** — Upload a utility bill (proof of address) via file picker or camera (currently available for Mexico and Colombia)

## Architecture

### Module Structure

```
ios/validations/
├── TruoraCamera/              # Native camera module
│   └── Sources/
│       ├── CameraManager.swift
│       ├── CameraView.swift
│       ├── CameraProtocols.swift
│       ├── CameraError.swift
│       └── Extensions.swift
│
├── TruoraValidationsSDK/      # Main SDK module
│   └── Sources/
│       ├── TruoraValidationsSDK.swift    # Public entry point
│       ├── ValidationConfig.swift
│       ├── ValidationProtocols.swift
│       ├── ValidationModels.swift
│       ├── ValidationError.swift
│       ├── ValidationRouter.swift
│       ├── Enrollment/           # Step 1: Create enrollment
│       ├── UploadBaseImage/      # Step 2: Upload ID photo
│       ├── EnrollmentStatus/     # Step 3: Check enrollment
│       ├── CreateValidation/     # Step 4: Start validation
│       ├── PassiveCapture/       # Step 5: Face capture (FULL IMPL)
│       │   ├── PassiveCaptureViewController.swift
│       │   ├── PassiveCapturePresenter.swift
│       │   ├── PassiveCaptureInteractor.swift
│       │   └── PassiveCaptureConfigurator.swift
│       └── Result/               # Step 6: Show result
│
└── SampleApp/                 # Demo application
    ├── Sources/
    │   ├── AppDelegate.swift
    │   ├── SceneDelegate.swift
    │   ├── Config.swift
    │   └── WebViewHostViewController.swift
    ├── Resources/
    │   └── webview/           # Built from sample-apps/validations-sdk-sample-app (see Scripts/copy-webview.sh)
    └── Scripts/
        └── copy-webview.sh    # Builds Vue app and copies dist to Resources/webview
```

### Dependencies

- **TruoraValidations.framework** (KMP) - API client from `shared/validations`
- **TruoraUI.framework** (KMP) - Compose UI from `shared/ui`
- **TruoraCamera** - Native AVFoundation camera module

## Getting Started

### Prerequisites

#### Required for any build

- Xcode 16+. We recommend always using the latest Xcode version.
- iOS 13.0+
- Tuist 4.0+
- CocoaPods (if using)
- **mise** — task runner used by `mise run generate`. Install with `brew install mise` and follow the activation step in the [mise install guide](https://mise.jdx.dev/installing-mise.html).

#### Optional — only needed to sync models from the registry (release prep, latest model fetch)

If unavailable, `mise run generate` warns and falls through to `tuist generate` using whatever `.tflite` is currently tracked in git, so dev builds still work without the credentials below.

- **AWS CLI v2 + AWS SSO access with S3 read on `truora-model-registry`** — used to download the model binary. Configure once with `aws configure sso`, then verify before release prep:
  ```bash
  aws sso login --profile <your-profile>
  export AWS_PROFILE=<your-profile>
  aws sts get-caller-identity                                                                  # should print your role/account
  ```
- **SSH access to `bitbucket.org/truora/model-registry`** — used to fetch the `.dvc` pointer for the model.

### Installation

1. **Clone the repository**
   ```bash
   cd ios/validations
   ```

2. **Install Tuist** (if not already installed)
   ```bash
   brew tap tuist/tuist
   brew install --formula tuist
   ```

3. **Generate the Xcode project (fetches ML models, then runs tuist generate)**
   ```bash
   mise run generate
   ```
   > Use `mise run generate` instead of bare `tuist generate`. The wrapper fetches the latest models from the model registry before generating, so your local SDK stays in sync with what ML team has approved into master. Subsequent runs are instantaneous (md5 cache hit) and only re-download when the registry has changed.
   >
   > **Releasing a new SDK version?** Run `FETCH_MODELS_STRICT=1 mise run generate` immediately before producing the release artifact, then smoke test the sample app. The strict flag turns AWS or SSH failures into hard errors so a release never ships a stale `.tflite` from git when the registry has moved on (without it, a credential failure silently falls back to whatever model is committed). This is the QA gate that catches regressions in the latest model from master before they ship to integrators.

4. **Open the workspace**
   ```bash
   open validations.xcworkspace
   ```

## Usage

### Basic Integration

```swift
import UIKit
import TruoraValidationsSDK

class YourViewController: UIViewController {

    func startValidation() {
        Task {
            try await TruoraValidationsSDK.shared.startFaceValidation(
                from: self,
                accountId: "your-account-id",
                apiKey: "your-api-key",
                delegate: self
            )
        }
    }
}

extension YourViewController: ValidationDelegate {
    func validationCompleted(result: ValidationResult) {
        print("✅ Validation succeeded!")
        print("ID: \(result.validationId)")
        print("Status: \(result.status)")
        print("Confidence: \(result.confidence ?? 0)")
    }

    func validationFailed(error: ValidationError) {
        print("❌ Validation failed: \(error.localizedDescription)")
    }

    func validationCancelled() {
        print("User cancelled validation")
    }
}
```

### Running the Sample App

The Sample App hosts the shared Vue sample app (`sample-apps/validations-sdk-sample-app`) inside a `WKWebView` and bridges to native TruoraValidationsSDK flows (face, document, document+face).

#### Prerequisites

1. Configure `VITE_TRUORA_API_KEY` in `sample-apps/validations-sdk-sample-app/.env.local` (copy from `.env.example` if needed).
2. Ensure **Node.js** and **npm** are installed — the build script needs them to compile the Vue app.

#### Steps

1. Generate the project: `mise run generate`
2. Open `validations.xcworkspace`
3. Select the **SampleApp** scheme
4. Choose a simulator or physical device (iOS 13.0+)
5. Build and run (⌘R)

Xcode builds the Vue app automatically via the post-build script `Scripts/copy-webview.sh`. Configure `VITE_TRUORA_API_KEY` in `sample-apps/validations-sdk-sample-app/.env.local` before building; the script rebuilds when `.env.local` changes.

## Key Features

### PassiveCapture Integration

The PassiveCapture module demonstrates full integration of:

**Native Camera Layer**
- Uses `TruoraCamera` module with AVFoundation
- Supports front/back camera
- Video recording with configurable duration

**Compose UI Overlay**
- Integrates `TruoraUI.framework` Compose views
- Transparent overlay on camera feed
- Real-time feedback display
- Countdown timer
- Help dialog

**State Management**
```swift
enum PassiveCaptureState {
    case countdown  // 3-2-1 countdown
    case recording  // Active recording
    case manual     // Manual trigger option
}

enum FeedbackType {
    case none
    case showFace
    case removeGlasses
    case multiplePeople
    case hiddenFace
    case recording
}
```

**Event Handling**
```swift
func handleCaptureEvent(_ event: PassiveCaptureEvent) {
    switch event {
    case .CountdownFinished:
        startRecording()
    case .RecordingCompleted:
        uploadVideo()
    case .HelpRequested:
        showHelpDialog()
    case .ManualRecordingRequested:
        startManualRecording()
    }
}
```

## VIPER Architecture

Each module follows VIPER pattern:

```
Module/
├── ModuleViewController.swift     # View
├── ModulePresenter.swift          # Presenter
├── ModuleInteractor.swift         # Interactor (Business Logic)
└── ModuleConfigurator.swift       # Builder/Factory
```

**View ↔ Presenter ↔ Interactor**
- View communicates with Presenter via protocols
- Presenter coordinates between View and Interactor
- Interactor handles business logic and API calls
- Router manages navigation flow

## Project Configuration (Tuist)

The project uses Tuist for modular project generation:

```swift
// Project.swift
let project = Project(
    name: "validations",
    targets: [
        .target(name: "TruoraCamera", ...),
        .target(name: "TruoraValidationsSDK", ...),
        .target(name: "SampleApp", ...)
    ]
)
```

## Camera Permissions

Required Info.plist entries (already configured):

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access required for face validation</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for ID upload</string>
```

## API Integration

The SDK integrates with `TruoraValidations` KMP module:

```swift
// Example API usage (in Interactor)
guard let apiClient = ValidationConfig.shared.apiClient else {
    throw ValidationError.invalidConfiguration("API client not configured")
}

// Upload video
let response = try await apiClient.api.uploadFile(
    uploadUrl: uploadUrl,
    fileData: videoData,
    contentType: "video/mp4"
)

// Get validation result
let result = try await apiClient.api.getValidation(validationId: validationId)
```

## Development

### Adding a New Step

1. Create new directory under `TruoraValidationsSDK/Sources/`
2. Implement VIPER components (ViewController, Presenter, Interactor, Configurator)
3. Add navigation method to `ValidationRouter`
4. Connect in the flow

### Modifying Compose UI

The Compose UI is in `shared/ui/composeApp/`. Changes there automatically propagate to iOS via the framework.

### Testing

```bash
# Run unit tests
tuist test

# Run specific test target
tuist test TruoraValidationsSDKTests
```

# Release

1. Define the semantic_version for the release following iOS standard in [SemVer 2.0](https://semver.org/)
2. Build the assets for sharing with CocoaPods
```bash
mise run generate
```

3. Change the version in the respective podspec files of the SDK. For example:
```ruby
Pod::Spec.new do |s|
  s.name             = "TruoraValidationsSDK"
  s.version          = "SEMANTIC_VERSION" # Set your version here
  s.summary          = "SDK of biometric validations"
  s.description      = <<-DESC
...
```

In the case of [Truora Validations podspec](TruoraValidationsSDK.podspec) remember to adjust the version of the TruoraCamera dependency to match your published version

```ruby
  s.dependency         "TruoraCamera", "SEMANTIC_VERSION" # Set the desired TruoraCamera version here
```

4. Generate the iOS SDK log version source file (This is not automated in the PodSpec):

```bash
bash ../../scripts/generate_ios_sdk_version.sh --version SEMANTIC_VERSION
```

This ensures `sdk_version` in create-log requests matches the release version.

5. Set a repository tag for release in CocoaPods and SPM to track your repository

```bash
git tag SEMANTIC_VERSION
git push origin SEMANTIC_VERSION
```

And in case you need to delete or rewrite a tag:
```bash
git tag -d SEMANTIC_VERSION
git push origin :SEMANTIC_VERSION
```

``Code changes need to be uploaded to the tag with the "push origin" command since CocoaPods retrieves the code from the generated tag and our pipeline automatically releases SPM with that tag``

## CocoaPods release

1. Verify you have a pod session running
```bash
pod trunk me
```

And in case you don't, create a pods session
```bash
pod trunk register truora-apps@truora.com 'TruoraSDK' --description='Release for SDK version SEMANTIC_VERSION'
```

This will send an OTP to the registered email which will allow you to publish the pod version

2. Publish the SDKs with the commands:
```bash
# Push the camera dependency first if changed
pod trunk push TruoraCamera.podspec --allow-warnings

# Wait for around 10/15 minutes for the publish to be successful
# since CocoaPods needs time to update its internal caches for publishing a new version
# And then publish the TruoraValidationsSDK podspec
pod trunk push TruoraValidationsSDK.podspec --allow-warnings
```

3. Wait for 10/15 minutes for publish to be successful and all references updated in CocoaPods. Then test the release in [Pods sample app](../cocoa-pods-sample-apps)

### Troubleshooting publish
1. Q/ When doing a push with pods I get the error 
```
[!] An internal server error occurred. Please check for any known status issues at https://twitter.com/CocoaPods and try again later.
```
A/ Either CocoaPods is temporarily down (check twitter as suggested) or the podspec content is crashing the trunk server. A known culprit is the `prepare_command` field — the CocoaPods trunk server can fail to process it, returning a 500 even though `pod spec lint` passes locally. If you encounter this, remove `prepare_command` from the podspec and run the script manually before pushing (see step 4 above). Compare to previously published versions of the same podspec via `pod trunk info <PodName>` to narrow down which field is causing the issue.

2. Q/ The publish was incomplete, I need to replace the version

A/ Luckily in CocoaPods contrary to Android Maven releases you can delete a release with the `delete` command. For example if you wanted to delete a specific version of the TruoraValidationsSDK do: 

```
pod trunk delete TruoraValidationsSDK SEMANTIC_VERSION
```

However it's worth noting that after removing this version you can **NEVER AGAIN** push a spec with the same version number.

## SPM release
Our pipeline automatically syncs the bitbucket repo with github in ``https://github.com/truora/truora-validations-sdk``

Test with the official sample app by:

1. Uncomment the sdk dependency in [Package](Tuist/Package.swift)
2. Set `useExternalSDK` to `true`in the [tuist project](Project.swift)
3. Run tuist commands to install and generate project:
```bash
tuist install

tuist clean
mise run generate
```

## Troubleshooting

### Build Errors

**Localizable strings are not updated**
- Ensure generated strings are built: `mise run generate` (bare `tuist generate` is also fine here — strings regeneration does not depend on the model fetch)
- Commit them into your generated tag for the release

### Runtime Errors

**Camera not working**
- Check Info.plist permissions
- Test on real device (simulator camera is limited)

## License

Copyright © 2026 Truora. All rights reserved.

## Support

For issues or questions, contact: truora-apps@truora.com
