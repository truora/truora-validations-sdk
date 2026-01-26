# Truora Validations SDK for iOS

## Requirements

- iOS 13.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the SDK to your project using Swift Package Manager:

#### Option 1: Xcode UI

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/truora/truora-validations-sdk.git
   ```
3. Select version: `0.0.1` or higher
4. Select the `TruoraValidationsSDK` product

#### Option 2: Package.swift

Add the dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/truora/truora-validations-sdk.git", from: "0.0.1")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TruoraValidationsSDK", package: "truora-validations-sdk")
        ]
    )
]
```

## Configuration

### Required Permissions

Add the following permissions to your app's `Info.plist` or in the target's **Info** tab:

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Camera Usage Description` | String | "We need camera access to capture documents and validate your identity" |
| `Privacy - Photo Library Usage Description` | String | "We need photo library access to select document images" |
| `CADisableMinimumFrameDurationOnPhone` | Boolean | `YES` |

**Note:** `CADisableMinimumFrameDurationOnPhone` is required by the Compose Multiplatform library used internally.

## Basic Usage

### Import the SDK

```swift
import SwiftUI
import TruoraValidationsSDK
```

## Features

The SDK includes the following modules:

- **Document Capture**: Smart capture of front and back of identity documents
- **Facial Recognition**: Biometric validation through facial capture with liveness detection
- **Passive Validation**: Identity analysis without user interaction
- **Camera Integration**: Optimized camera module with automatic document detection using TensorFlow Lite

## Support

For technical support or inquiries:

- Email: support@truora.com
- Documentation: https://docs.truora.com

## License

Copyright © 2026 Truora. All rights reserved.
