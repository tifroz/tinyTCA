# tinyTCA

A minimal, Android-compatible implementation of The Composable Architecture pattern.

## Overview

tinyTCA provides the core TCA concepts (composability + testability) using only Swift Concurrency, making it compatible with any platform that supports Swift 6.1+, including Android.

**Key differences from Point-Free's TCA:**

- ❌ No Combine dependency (uses AsyncStream and async/await)
- ❌ No ViewStore (use `@Observable` directly in SwiftUI)
- ❌ No macros (simpler, but more verbose)
- ✅ Full Android compatibility
- ✅ Same mental model and patterns
- ✅ Testable and composable reducers

## Requirements

- Swift 6.1+
- Platforms: iOS 16+, macOS 13+, Android (via Swift SDK)

## Core Components

### 1. Reducer Protocol

Pure functions that handle state mutations:

```swift
struct CounterReducer: Reducer {
  struct State: Equatable {
    var count: Int = 0
  }

  enum Action: Equatable {
    case increment
    case decrement
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .increment:
      state.count += 1
      return .none
    case .decrement:
      state.count -= 1
      return .none
    }
  }
}
```

### 2. Store

Runtime that manages state and effects:

```swift
let store = Store(
  initialState: CounterReducer.State(),
  reducer: CounterReducer()
)

await store.send(.increment)
print(store.currentState.count) // 1
```

### 3. Effect

Async work using Swift Concurrency:

```swift
case .loadData:
  return .run { send in
    let data = try await apiClient.fetch()
    await send(.dataLoaded(data))
  }
```

### 4. TestStore

Deterministic testing:

```swift
let store = TestStore(
  initialState: CounterReducer.State(),
  reducer: CounterReducer()
)

await store.send(.increment) { state in
  state.count = 1
}
```

### 5. Dependencies (Optional)

Simple dependency injection:

```swift
extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClientKey.self] }
    set { self[APIClientKey.self] = newValue }
  }
}
```

## Usage Example

See `CounterExample.swift` for a complete working example.

## Testing

```bash
swift test
```

All 9 tests pass ✓

## Building for Android

```bash
swift build --swift-sdk aarch64-unknown-linux-android28
```

## Limitations

This is a **minimal** implementation focused on core patterns. It does not include:

- ViewStore (use SwiftUI's `@Observable` instead)
- Navigation helpers
- Debounce/throttle operators
- Macro support
- Comprehensive effect testing infrastructure

For a full-featured library, use Point-Free's TCA on Apple platforms.

## License

MIT
