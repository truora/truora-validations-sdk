# TruoraValidationsSDK Architecture

## Overview

The TruoraValidationsSDK uses a **modified VIPER architecture** adapted for SwiftUI while maintaining UIKit navigation. This architecture provides clear separation of concerns, testability, and maintainability.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        UIHostingController                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      SwiftUI View                            │   │
│  │  • Declarative UI using @ObservedObject                      │   │
│  │  • Receives state from ViewModel                             │   │
│  │  • Sends user events to ViewModel                            │   │
│  │  • Uses @EnvironmentObject for TruoraTheme                   │   │
│  └───────────────────────────┬─────────────────────────────────┘   │
│                              │                                       │
│  ┌───────────────────────────▼─────────────────────────────────┐   │
│  │                     ViewModel                                │   │
│  │  • @MainActor ObservableObject                               │   │
│  │  • @Published state properties                               │   │
│  │  • Implements PresenterToView protocol                       │   │
│  │  • Forwards user events to Presenter                         │   │
│  └───────────────────────────┬─────────────────────────────────┘   │
│                              │                                       │
│  ┌───────────────────────────▼─────────────────────────────────┐   │
│  │                      Presenter                               │   │
│  │  • Business logic coordinator                                │   │
│  │  • Handles events from ViewModel                             │   │
│  │  • Communicates with Interactor for data operations          │   │
│  │  • Updates ViewModel via PresenterToView protocol            │   │
│  │  • Uses Router for navigation                                │   │
│  └───────────────────────────┬─────────────────────────────────┘   │
│                              │                                       │
│  ┌───────────────────────────▼─────────────────────────────────┐   │
│  │                     Interactor                               │   │
│  │  • Data and network operations                               │   │
│  │  • Async tasks (API calls, file uploads)                     │   │
│  │  • Reports results to Presenter via protocol                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          Router                                      │
│  • Manages UINavigationController stack                              │
│  • Creates screens via Configurators                                 │
│  • Handles flow transitions and dismissals                           │
│  • Stored as associated object to prevent deallocation               │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                       Configurator                                   │
│  • Factory for creating module components                            │
│  • Dependency injection                                              │
│  • Wires View, ViewModel, Presenter, Interactor together             │
│  • Returns UIHostingController wrapping SwiftUI View                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### View (SwiftUI)

- **Role**: Declarative UI presentation
- **Responsibilities**:
  - Render UI based on ViewModel state
  - Forward user interactions to ViewModel
  - Use `@ObservedObject` for ViewModel
  - Use `@EnvironmentObject` for theme
- **No business logic** - views are purely presentational

### ViewModel

- **Role**: UI state container and event router
- **Responsibilities**:
  - Hold `@Published` state properties
  - Implement `PresenterToView` protocol
  - Forward user events to Presenter
  - Convert Presenter updates to UI state
- **Marked `@MainActor`** for thread safety
- **Marked `final`** to prevent subclassing

### Presenter

- **Role**: Business logic coordinator
- **Responsibilities**:
  - Handle user events from ViewModel
  - Coordinate with Interactor for data operations
  - Apply business rules and validation
  - Update ViewModel via protocol methods
  - Request navigation via Router
- **No UI knowledge** - uses protocols for communication

### Interactor

- **Role**: Data operations
- **Responsibilities**:
  - Make API calls via `TruoraAPIClient`
  - Upload files to presigned URLs
  - Poll for validation results
  - Handle async operations with Task
- **Uses async/await** for modern concurrency

### Router

- **Role**: Navigation management
- **Responsibilities**:
  - Hold weak reference to UINavigationController
  - Create and push new screens
  - Handle flow dismissal
  - Show error alerts
- **Single instance per flow** stored via associated object

### Configurator

- **Role**: Dependency injection factory
- **Responsibilities**:
  - Create all module components
  - Wire components together
  - Return configured UIHostingController
- **Static buildModule method** for consistency

## Protocol Naming Convention

```
{Module}ViewToPresenter      - Events from View/ViewModel to Presenter
{Module}PresenterToView      - Updates from Presenter to View/ViewModel (marked @MainActor)
{Module}PresenterToInteractor - Commands from Presenter to Interactor
{Module}InteractorToPresenter - Results from Interactor to Presenter
```

## Data Flow

### User Interaction Flow

```
User Tap → View → ViewModel.method() → presenter?.eventMethod()
                                              ↓
                                         Presenter
                                              ↓
                               (business logic / validation)
                                              ↓
                              interactor?.performOperation()
                                              ↓
                                         Interactor
                                              ↓
                                     async API call
                                              ↓
                              presenter?.operationCompleted()
                                              ↓
                                         Presenter
                                              ↓
                              view?.updateUI(state: newState)
                                              ↓
                         ViewModel (via @MainActor protocol)
                                              ↓
                              @Published property update
                                              ↓
                            SwiftUI View re-renders
```

### Navigation Flow

```
Presenter determines navigation needed
        ↓
router?.navigateToNextScreen()
        ↓
Router.navigateTo*() 
        ↓
Configurator.buildModule() → UIHostingController
        ↓
navController.pushViewController(vc, animated: true)
```

## Concurrency Model

### Swift 6 Ready

The codebase uses modern Swift concurrency patterns:

1. **@MainActor ViewModels**: All ViewModels are marked `@MainActor` to ensure UI updates happen on the main thread without manual `DispatchQueue.main.async` calls.

2. **@MainActor Protocols**: `PresenterToView` protocols are marked `@MainActor` to enforce main thread updates at compile time.

3. **async/await Networking**: The `TruoraAPIClient` uses async/await for all API calls.

4. **Task-based Operations**: Long-running operations use `Task` with proper cancellation support.

### Thread Safety

- ViewModels: `@MainActor` ensures thread safety
- Presenters: Called from main thread via ViewModels
- Interactors: Use async/await, report results via `await MainActor.run`
- Camera: Uses dedicated serial queues for buffer access

## Module Structure

```
TruoraValidationsSDK/
├── Sources/
│   ├── TruoraValidationsSDK.swift    # Main entry point, Builder pattern
│   ├── ValidationConfig.swift        # Global configuration singleton
│   ├── ValidationRouter.swift        # Navigation coordinator
│   ├── ValidationModels.swift        # Public result types
│   ├── ValidationError.swift         # Public error types
│   │
│   ├── ApiKey/                       # API key management
│   ├── Components/                   # Reusable SwiftUI components
│   ├── Models/                       # Data models
│   ├── Networking/                   # API client and downloader
│   ├── Theme/                        # Theming system
│   ├── Validations/                  # Validation type configs
│   │
│   ├── PassiveIntro/                 # Face capture intro module
│   ├── PassiveCapture/               # Face capture module
│   ├── DocumentSelection/            # Document type selection
│   ├── DocumentIntro/                # Document capture intro
│   ├── DocumentCapture/              # Document capture module
│   ├── DocumentFeedback/             # Document feedback overlay
│   └── Result/                       # Validation result module
│
└── Resources/
    └── Base.lproj/Localizable.strings
```

## iOS Version Compatibility

The SDK supports **iOS 13+** with the following strategies:

| Feature | iOS 13-14 | iOS 15+ |
|---------|-----------|---------|
| Async Image | Custom Combine-based | Native `AsyncImage` |
| Progress | UIActivityIndicatorView | `ProgressView` (via wrapper) |
| Alerts | Deprecated `Alert` struct | Modern `alert(title:isPresented:)` |
| State Ownership | `@ObservedObject` | Would use `@StateObject` |
| Concurrency | async/await via backport | Native async/await |

## Testing Strategy

### Unit Testing

- **ViewModels**: Test state transitions by calling PresenterToView methods
- **Presenters**: Mock ViewModel, Interactor, Router protocols
- **Interactors**: Mock TruoraAPIClient, test async operations

### Protocol-Based Testing

```swift
// Mock example
class MockPresenterToView: PassiveCapturePresenterToView {
    var updateUICalled = false
    var lastState: PassiveCaptureState?
    
    func updateUI(state: PassiveCaptureState, ...) {
        updateUICalled = true
        lastState = state
    }
}
```

### Test Helpers

- `#if DEBUG` test helpers in Router and Config
- Protocol-based dependency injection
- `ValidationConfig.makeForTesting()` factory

## Best Practices

### Do

✅ Mark ViewModels with `@MainActor`
✅ Use protocols for all component communication
✅ Keep Views purely presentational
✅ Use Configurators for dependency injection
✅ Handle errors via Router
✅ Use async/await for all network operations

### Don't

❌ Put business logic in Views
❌ Access ViewModel from background threads
❌ Use singletons except ValidationConfig
❌ Create retain cycles (use `weak` for delegates)
❌ Skip error handling in async operations

## Adding a New Module

1. Create folder: `{ModuleName}/`
2. Create files:
   - `{ModuleName}View.swift` (SwiftUI View + ViewModel)
   - `{ModuleName}Presenter.swift`
   - `{ModuleName}Interactor.swift` (if needed)
   - `{ModuleName}Protocols.swift`
   - `{ModuleName}Configurator.swift`
3. Add navigation method to `ValidationRouter`
4. Wire up in appropriate flow
