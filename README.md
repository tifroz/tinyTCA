# tinyTCA

A minimal, Android-compatible implementation of The Composable Architecture pattern.

## Overview

tinyTCA provides the core TCA concepts (composability + testability) using only Swift Concurrency, making it compatible with any platform that supports Swift 6.1+, including Android.

**Key differences from Point-Free's TCA:**

- ❌ No Combine dependency (uses AsyncStream and async/await)
- ❌ No ViewStore (use `@Observable` directly in SwiftUI)
- ✅ **Macro support** (`@Reducer`, `@CasePathable`)
- ✅ Full Android compatibility
- ✅ Same mental model and patterns
- ✅ Testable and composable reducers

## Requirements

- Swift 6.1+
- Platforms: iOS 17+, macOS 14+, Android (via Swift SDK)

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

## Macro Support

tinyTCA includes macros to reduce boilerplate when composing reducers.

### @CasePathable

Generates case key paths for enum cases, enabling ergonomic action routing:

```swift
@CasePathable
enum Action {
    case increment
    case child(ChildAction)
}

// Generated: Action.allCasePaths.child -> CaseKeyPath<Action, ChildAction>
```

### @Reducer

Simplifies reducer definitions by:
- Auto-applying `@CasePathable` to the `Action` enum
- Generating `Reducer` protocol conformance
- Supporting body-based composition with ergonomic `Action.allCasePaths` syntax

```swift
@Reducer
struct ParentFeature {
    struct State: Equatable {
        var counter: CounterReducer.State
        var title: String
    }

    enum Action {
        case counter(CounterReducer.Action)
        case updateTitle(String)
    }

    var body: some Reducer<State, Action> {
        CombinedReducer(
            // Ergonomic syntax using Action.allCasePaths
            Scope<State, Action, CounterReducer>(
                state: \State.counter,
                action: Action.allCasePaths.counter
            ) {
                CounterReducer()
            },
            Reduce<State, Action> { state, action in
                switch action {
                case .counter(.increment):
                    state.title = "Counter incremented!"
                    return .none
                case .counter:
                    return .none
                case let .updateTitle(title):
                    state.title = title
                    return .none
                }
            }
        )
    }
}
```

The `Action.allCasePaths.counter` syntax replaces verbose `CasePath(extract:embed:)` construction, reducing boilerplate significantly.

## Usage Example

See `CounterExample.swift` for complete working examples, including:
- Basic counter reducer
- Parent/child composition (manual and macro-based)
- Collection management with `ForEach`

## Testing

```bash
swift test
```

All 28 tests pass ✓

## Building for Android

```bash
swift build --swift-sdk aarch64-unknown-linux-android28
```

## Limitations

This is a **minimal** implementation focused on core patterns. It does not include:

- ViewStore (use SwiftUI's `@Observable` instead)
- Navigation helpers
- Debounce/throttle operators
- Comprehensive effect testing infrastructure

For a full-featured library, use Point-Free's TCA on Apple platforms.

## License

MIT
