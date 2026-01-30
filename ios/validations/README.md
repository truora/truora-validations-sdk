# Truora Validations iOS SDK

A modular iOS SDK for face validation using VIPER architecture, built with Tuist and integrating Kotlin Multiplatform (KMP) modules for API and UI.

## Overview

This SDK provides a complete face validation flow with:
1. **Enrollment creation** - Register user for validation
2. **Base image upload** - Upload reference ID photo
3. **Enrollment verification** - Confirm enrollment status
4. **Validation creation** - Initiate face validation
5. **Passive capture** - Record face video with Compose UI overlay
6. **Result display** - Show validation outcome

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
    └── Sources/
        ├── AppDelegate.swift
        ├── SceneDelegate.swift
        └── MainViewController.swift
```

### Dependencies

- **TruoraValidations.framework** (KMP) - API client from `shared/validations`
- **TruoraUI.framework** (KMP) - Compose UI from `shared/ui`
- **TruoraCamera** - Native AVFoundation camera module

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 13.0+
- Tuist 4.0+
- CocoaPods (if using)

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

3. **Generate the Xcode project**
   ```bash
   tuist generate
   ```

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

1. Generate the project: `tuist generate`
2. Open `validations.xcworkspace`
3. Select the `SampleApp` scheme
4. Choose a simulator or physical device (iOS 13.0+)
5. Build and run (⌘R)

**Note:** The app uses iOS 12 compatibility mode (AppDelegate-managed window) instead of SceneDelegate. This works perfectly on iOS 13+ and avoids Tuist-related scene configuration issues.

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

# CocoaPods Release

1. Define the semantic_version for the release following iOS standard in [SemVer 2.0](https://semver.org/)
2. Build the assets for sharing with CocoaPods
```bash
tuist generate
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
4. Set a repository tag for CocoaPods to track your repository

```bash
git tag SEMANTIC_VERSION
git push origin SEMANTIC_VERSION
```

And in case you need to delete or rewrite a tag:
```bash
git tag -d SEMANTIC_VERSION
git push origin :SEMANTIC_VERSION
```

``Code changes need to be uploaded to the tag with the "push origin" command since CocoaPods retrieves the code from the generated tag``

5. Verify you have a pod session running
```bash
pod trunk me
```

And in case you don't, create a pods session
```bash
pod trunk register truora-apps@truora.com 'TruoraSDK' --description='Release for SDK version SEMANTIC_VERSION'
```

This will send an OTP to the registered email which will allow you to publish the pod version

6. Publish the SDKs with the commands:
```bash
# Push the camera dependency first if changed
pod trunk push TruoraCamera.podspec --allow-warnings

# Wait for around 10/15 minutes for the publish to be successful
# since CocoaPods needs time to update its internal caches for publishing a new version
# And then publish the TruoraValidationsSDK podspec
pod trunk push TruoraValidationsSDK.podspec --allow-warnings
```

7. Wait for 10/15 minutes for publish to be successful and all references updated in CocoaPods. Then test the release in [Pods sample app](../cocoa-pods-sample-apps)

## Troubleshooting

### Build Errors

**Localizable strings are not updated**
- Ensure generated strings are built: `tuist generate`
- Commit them into your generated tag for the release

### Runtime Errors

**Camera not working**
- Check Info.plist permissions
- Test on real device (simulator camera is limited)

## License

Copyright © 2026 Truora. All rights reserved.

## Support

For issues or questions, contact: truora-apps@truora.com

