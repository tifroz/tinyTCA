// 470 Lines by Claude Sonnet
// Minimal TCA: Comprehensive XCTest suite for Skip compatibility
// Ported from Swift Testing to XCTest for iOS/Android parity
//
// ⚠️ COMMENTED OUT - NOT CURRENTLY USABLE ⚠️
//
// This XCTest suite was created to enable iOS/Android test parity via Skip transpilation.
// However, it cannot be used because:
//
// 1. Skip's XCTest transpilation requires all tested code to use bridged packages
// 2. MinimalTCA cannot be bridged due to its use of Swift generics
// 3. Skip's Kotlin transpiler has limitations with generic constraints that prevent bridging
//
// This file is preserved for reference in case:
// - Skip adds better generics support in the future
// - An alternative transpilation approach becomes available
// - XCTest is needed for pure iOS testing (though Swift Testing is preferred)
//
// For now, use MinimalTCATests.swift (Swift Testing) for iOS-only testing.

/*

import XCTest
@testable import MinimalTCA

// MARK: - Counter Tests

@MainActor
final class CounterTests: XCTestCase {
  func testIncrement() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(),
      reducer: CounterReducer()
    )

    await store.send(.increment) { state in
      state.count = 1
    }
  }

  func testDecrement() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(count: 5),
      reducer: CounterReducer()
    )

    await store.send(.decrement) { state in
      state.count = 4
    }
  }

  func testReset() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(count: 42, isLoading: true),
      reducer: CounterReducer()
    )

    await store.send(.reset) { state in
      state.count = 0
      state.isLoading = false
    }
  }

  func testDelayedIncrement() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(count: 0),
      reducer: CounterReducer()
    )

    await store.send(.incrementDelayed) { state in
      state.isLoading = true
    }

    // The effect will send .setLoading(false) then .increment
    // TestStore automatically processes these
  }

  func testMultipleOperations() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(),
      reducer: CounterReducer()
    )

    await store.send(.increment) { state in
      state.count = 1
    }

    await store.send(.increment) { state in
      state.count = 2
    }

    await store.send(.decrement) { state in
      state.count = 1
    }

    await store.send(.reset) { state in
      state.count = 0
    }
  }
}

// MARK: - Store Tests

@MainActor
final class StoreTests: XCTestCase {
  func testInitialization() async throws {
    let store = Store(
      initialState: CounterReducer.State(count: 10),
      reducer: CounterReducer()
    )

    XCTAssertEqual(store.currentState.count, 10)
  }

  func testActionProcessing() async throws {
    let store = Store(
      initialState: CounterReducer.State(),
      reducer: CounterReducer()
    )

    await store.send(.increment)
    XCTAssertEqual(store.currentState.count, 1)

    await store.send(.increment)
    XCTAssertEqual(store.currentState.count, 2)

    await store.send(.decrement)
    XCTAssertEqual(store.currentState.count, 1)
  }
}

// MARK: - Effect Tests

final class EffectTests: XCTestCase {
  func testNoneEffect() async throws {
    let effect = Effect<Int>.none
    // Effect.none should complete immediately without emitting actions
    // We verify this by checking the effect runs without errors
    let send = Send<Int> { _ in }
    await effect.run(send: send)
  }

  func testSendEffect() async throws {
    // For this minimal implementation, we test that Effect.send compiles
    // A full implementation would verify the action is actually sent
    let effect = Effect<Int>.send(42)
    let send = Send<Int> { _ in }
    await effect.run(send: send)
  }
}

// MARK: - Scope Composition Tests

@MainActor
final class ScopeTests: XCTestCase {
  func testScopeForwardsChildActions() async throws {
    let store = TestStore(
      initialState: AppReducer.State(
        counter: CounterReducer.State(count: 0),
        appTitle: "Initial"
      ),
      reducer: AppReducer()
    )

    // Send child action through parent
    await store.send(.counter(.increment)) { state in
      state.counter.count = 1
      state.appTitle = "Counter incremented!" // Parent reacts to child action
    }
  }

  func testScopeIgnoresNonChildActions() async throws {
    let store = TestStore(
      initialState: AppReducer.State(
        counter: CounterReducer.State(count: 5),
        appTitle: "Initial"
      ),
      reducer: AppReducer()
    )

    // Send parent-only action
    await store.send(.updateTitle("New Title")) { state in
      state.appTitle = "New Title"
      // Counter state unchanged
      XCTAssertEqual(state.counter.count, 5)
    }
  }

  func testChildReducerUpdatesChildState() async throws {
    let store = Store(
      initialState: AppReducer.State(
        counter: CounterReducer.State(count: 0),
        appTitle: "App"
      ),
      reducer: AppReducer()
    )

    // Child actions update child state
    await store.send(.counter(.increment))
    XCTAssertEqual(store.currentState.counter.count, 1)

    await store.send(.counter(.increment))
    XCTAssertEqual(store.currentState.counter.count, 2)

    await store.send(.counter(.decrement))
    XCTAssertEqual(store.currentState.counter.count, 1)
  }

  func testParentReactsToChildActions() async throws {
    let store = Store(
      initialState: AppReducer.State(
        counter: CounterReducer.State(count: 0),
        appTitle: "Initial"
      ),
      reducer: AppReducer()
    )

    // Parent reacts to child increment
    await store.send(.counter(.increment))
    XCTAssertEqual(store.currentState.appTitle, "Counter incremented!")

    // Other child actions don't change parent title
    await store.send(.counter(.decrement))
    XCTAssertEqual(store.currentState.appTitle, "Counter incremented!")
  }
}

// MARK: - CasePath Tests

final class CasePathTests: XCTestCase {
  enum TestAction: Equatable, Sendable {
    case child(String)
    case parent(Int)
  }

  func testExtractMatchingCase() {
    let casePath = CasePath<TestAction, String>(
      extract: { action in
        if case .child(let value) = action {
          return value
        }
        return nil
      },
      embed: { .child($0) }
    )

    let childAction: TestAction = .child("test")
    let extracted = casePath.extract(from: childAction)
    XCTAssertEqual(extracted, "test")
  }

  func testExtractNonMatchingCase() {
    let casePath = CasePath<TestAction, String>(
      extract: { action in
        if case .child(let value) = action {
          return value
        }
        return nil
      },
      embed: { .child($0) }
    )

    let parentAction: TestAction = .parent(42)
    let extracted = casePath.extract(from: parentAction)
    XCTAssertNil(extracted)
  }

  func testEmbedValue() {
    let casePath = CasePath<TestAction, String>(
      extract: { action in
        if case .child(let value) = action {
          return value
        }
        return nil
      },
      embed: { .child($0) }
    )

    let action = casePath.embed("hello")
    XCTAssertEqual(action, .child("hello"))
  }
}

// MARK: - ForEach Collection Tests

@MainActor
final class ForEachTests: XCTestCase {
  func testForEachRoutesActions() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add some counters
    await store.send(.addCounter)
    XCTAssertEqual(store.currentState.counters.count, 1)
    XCTAssertEqual(store.currentState.totalCount, 0)

    // Get the first counter's ID
    guard let firstID = store.currentState.counters.first?.id else {
      XCTFail("No counter found")
      return
    }

    // Increment specific counter
    await store.send(.counters(.element(id: firstID, action: .increment)))
    XCTAssertEqual(store.currentState.counters[id: firstID]?.count, 1)
    XCTAssertEqual(store.currentState.totalCount, 1)
  }

  func testMultipleElementsIndependently() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add three counters
    await store.send(.addCounter)
    await store.send(.addCounter)
    await store.send(.addCounter)

    XCTAssertEqual(store.currentState.counters.count, 3)

    // Get IDs
    let ids = store.currentState.counters.ids
    XCTAssertEqual(ids.count, 3)

    // Increment first counter twice
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    await store.send(.counters(.element(id: ids[0], action: .increment)))

    // Increment second counter once
    await store.send(.counters(.element(id: ids[1], action: .increment)))

    // Third counter remains at 0
    XCTAssertEqual(store.currentState.counters[id: ids[0]]?.count, 2)
    XCTAssertEqual(store.currentState.counters[id: ids[1]]?.count, 1)
    XCTAssertEqual(store.currentState.counters[id: ids[2]]?.count, 0)
    XCTAssertEqual(store.currentState.totalCount, 3)
  }

  func testElementRemoval() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add counters
    await store.send(.addCounter)
    await store.send(.addCounter)

    let ids = store.currentState.counters.ids
    XCTAssertEqual(ids.count, 2)

    // Increment first counter
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    XCTAssertEqual(store.currentState.counters[id: ids[0]]?.count, 1)

    // Remove first counter
    await store.send(.removeCounter(id: ids[0]))
    XCTAssertEqual(store.currentState.counters.count, 1)
    XCTAssertNil(store.currentState.counters[id: ids[0]])
    XCTAssertNotNil(store.currentState.counters[id: ids[1]])
  }

  func testTotalCalculation() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add three counters
    await store.send(.addCounter)
    await store.send(.addCounter)
    await store.send(.addCounter)

    let ids = store.currentState.counters.ids

    // Increment counters to different values
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    await store.send(.counters(.element(id: ids[1], action: .increment)))
    await store.send(.counters(.element(id: ids[1], action: .increment)))
    await store.send(.counters(.element(id: ids[1], action: .increment)))

    // Total should be 2 + 3 + 0 = 5
    XCTAssertEqual(store.currentState.totalCount, 5)

    // Remove one counter
    await store.send(.removeCounter(id: ids[1]))
    XCTAssertEqual(store.currentState.totalCount, 2)
  }
}

// MARK: - IdentifiedArray Tests

final class IdentifiedArrayTests: XCTestCase {
  struct Item: Equatable, Identifiable {
    let id: Int
    var name: String
  }

  func testInitEmpty() {
    let array = IdentifiedArray<Int, Item>(id: \.id)
    XCTAssertTrue(array.isEmpty)
    XCTAssertEqual(array.count, 0)
  }

  func testAppend() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))

    XCTAssertEqual(array.count, 2)
    XCTAssertEqual(array[id: 1]?.name, "One")
    XCTAssertEqual(array[id: 2]?.name, "Two")
  }

  func testPreventsDuplicates() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "First"))
    array.append(Item(id: 1, name: "Duplicate"))

    XCTAssertEqual(array.count, 1)
    XCTAssertEqual(array[id: 1]?.name, "First")
  }

  func testRemoveByID() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))
    array.append(Item(id: 3, name: "Three"))

    let removed = array.remove(id: 2)
    XCTAssertEqual(removed?.name, "Two")
    XCTAssertEqual(array.count, 2)
    XCTAssertNil(array[id: 2])
    XCTAssertEqual(array[id: 1]?.name, "One")
    XCTAssertEqual(array[id: 3]?.name, "Three")
  }

  func testSubscriptUpdate() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))

    array[id: 1] = Item(id: 1, name: "Updated")
    XCTAssertEqual(array[id: 1]?.name, "Updated")
  }

  func testSubscriptRemoveWithNil() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))

    array[id: 1] = nil
    XCTAssertEqual(array.count, 1)
    XCTAssertNil(array[id: 1])
    XCTAssertEqual(array[id: 2]?.name, "Two")
  }
}

*/
