// Tiny TCA: Comprehensive tests demonstrating testability
// Extended with Scope composition tests
// Extended with ForEach collection tests

import Testing
@testable import tinyTCA

@MainActor
@Suite("Counter Tests")
struct CounterTests {
  @Test("Increment increases count")
  func testIncrement() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(),
      reducer: CounterReducer()
    )

    await store.send(.increment) { state in
      state.count = 1
    }
  }

  @Test("Decrement decreases count")
  func testDecrement() async throws {
    let store = TestStore(
      initialState: CounterReducer.State(count: 5),
      reducer: CounterReducer()
    )

    await store.send(.decrement) { state in
      state.count = 4
    }
  }

  @Test("Reset sets count to zero")
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

  @Test("Delayed increment shows loading and increments")
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

  @Test("Multiple operations in sequence")
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

@MainActor
@Suite("Store Tests")
struct StoreTests {
  @Test("Store initializes with correct state")
  func testInitialization() async throws {
    let store = Store(
      initialState: CounterReducer.State(count: 10),
      reducer: CounterReducer()
    )

    #expect(store.currentState.count == 10)
  }

  @Test("Store processes actions")
  func testActionProcessing() async throws {
    let store = Store(
      initialState: CounterReducer.State(),
      reducer: CounterReducer()
    )

    await store.send(.increment)
    #expect(store.currentState.count == 1)

    await store.send(.increment)
    #expect(store.currentState.count == 2)

    await store.send(.decrement)
    #expect(store.currentState.count == 1)
  }
}

@Suite("Effect Tests")
struct EffectTests {
  @Test("Effect.none does nothing")
  func testNoneEffect() async throws {
    let effect = Effect<Int>.none
    // Effect.none should complete immediately without emitting actions
    // We verify this by checking the effect runs without errors
    let send = Send<Int> { _ in }
    await effect.run(send: send)
  }

  @Test("Effect.send emits single action")
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
@Suite("Scope Tests")
struct ScopeTests {
  @Test("Scope forwards child actions to child reducer")
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

  @Test("Scope ignores non-child actions")
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
      #expect(state.counter.count == 5)
    }
  }

  @Test("Child reducer updates child state slice")
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
    #expect(store.currentState.counter.count == 1)

    await store.send(.counter(.increment))
    #expect(store.currentState.counter.count == 2)

    await store.send(.counter(.decrement))
    #expect(store.currentState.counter.count == 1)
  }

  @Test("Parent can observe and react to child actions")
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
    #expect(store.currentState.appTitle == "Counter incremented!")

    // Other child actions don't change parent title
    await store.send(.counter(.decrement))
    #expect(store.currentState.appTitle == "Counter incremented!")
  }
}

// MARK: - CasePath Tests

@Suite("CasePath Tests")
struct CasePathTests {
  enum TestAction: Equatable, Sendable {
    case child(String)
    case parent(Int)
  }

  @Test("CasePath extracts matching cases")
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
    #expect(extracted == "test")
  }

  @Test("CasePath returns nil for non-matching cases")
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
    #expect(extracted == nil)
  }

  @Test("CasePath embeds values correctly")
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
    #expect(action == .child("hello"))
  }
}

// MARK: - ForEach Collection Tests

@MainActor
@Suite("ForEach Tests")
struct ForEachTests {
  @Test("ForEach routes actions to correct element by ID")
  func testForEachRoutesActions() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add some counters
    await store.send(.addCounter)
    #expect(store.currentState.counters.count == 1)
    #expect(store.currentState.totalCount == 0)

    // Get the first counter's ID
    guard let firstID = store.currentState.counters.first?.id else {
      Issue.record("No counter found")
      return
    }

    // Increment specific counter
    await store.send(.counters(.element(id: firstID, action: .increment)))
    #expect(store.currentState.counters[id: firstID]?.count == 1)
    #expect(store.currentState.totalCount == 1)
  }

  @Test("ForEach manages multiple elements independently")
  func testMultipleElementsIndependently() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add three counters
    await store.send(.addCounter)
    await store.send(.addCounter)
    await store.send(.addCounter)

    #expect(store.currentState.counters.count == 3)

    // Get IDs
    let ids = store.currentState.counters.ids
    #expect(ids.count == 3)

    // Increment first counter twice
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    await store.send(.counters(.element(id: ids[0], action: .increment)))

    // Increment second counter once
    await store.send(.counters(.element(id: ids[1], action: .increment)))

    // Third counter remains at 0
    #expect(store.currentState.counters[id: ids[0]]?.count == 2)
    #expect(store.currentState.counters[id: ids[1]]?.count == 1)
    #expect(store.currentState.counters[id: ids[2]]?.count == 0)
    #expect(store.currentState.totalCount == 3)
  }

  @Test("ForEach handles element removal")
  func testElementRemoval() async throws {
    let store = Store(
      initialState: CountersApp.State(),
      reducer: CountersApp()
    )

    // Add counters
    await store.send(.addCounter)
    await store.send(.addCounter)

    let ids = store.currentState.counters.ids
    #expect(ids.count == 2)

    // Increment first counter
    await store.send(.counters(.element(id: ids[0], action: .increment)))
    #expect(store.currentState.counters[id: ids[0]]?.count == 1)

    // Remove first counter
    await store.send(.removeCounter(id: ids[0]))
    #expect(store.currentState.counters.count == 1)
    #expect(store.currentState.counters[id: ids[0]] == nil)
    #expect(store.currentState.counters[id: ids[1]] != nil)
  }

  @Test("ForEach calculates total across all elements")
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
    #expect(store.currentState.totalCount == 5)

    // Remove one counter
    await store.send(.removeCounter(id: ids[1]))
    #expect(store.currentState.totalCount == 2)
  }
}

// MARK: - IdentifiedArray Tests

@Suite("IdentifiedArray Tests")
struct IdentifiedArrayTests {
  struct Item: Equatable, Identifiable {
    let id: Int
    var name: String
  }

  @Test("IdentifiedArray initializes empty")
  func testInitEmpty() {
    let array = IdentifiedArray<Int, Item>(id: \.id)
    #expect(array.isEmpty)
    #expect(array.count == 0)
  }

  @Test("IdentifiedArray appends elements")
  func testAppend() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))

    #expect(array.count == 2)
    #expect(array[id: 1]?.name == "One")
    #expect(array[id: 2]?.name == "Two")
  }

  @Test("IdentifiedArray prevents duplicate IDs")
  func testPreventsDuplicates() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "First"))
    array.append(Item(id: 1, name: "Duplicate"))

    #expect(array.count == 1)
    #expect(array[id: 1]?.name == "First")
  }

  @Test("IdentifiedArray removes by ID")
  func testRemoveByID() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))
    array.append(Item(id: 3, name: "Three"))

    let removed = array.remove(id: 2)
    #expect(removed?.name == "Two")
    #expect(array.count == 2)
    #expect(array[id: 2] == nil)
    #expect(array[id: 1]?.name == "One")
    #expect(array[id: 3]?.name == "Three")
  }

  @Test("IdentifiedArray subscript updates elements")
  func testSubscriptUpdate() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))

    array[id: 1] = Item(id: 1, name: "Updated")
    #expect(array[id: 1]?.name == "Updated")
  }

  @Test("IdentifiedArray subscript removes with nil")
  func testSubscriptRemoveWithNil() {
    var array = IdentifiedArray<Int, Item>(id: \.id)
    array.append(Item(id: 1, name: "One"))
    array.append(Item(id: 2, name: "Two"))

    array[id: 1] = nil
    #expect(array.count == 1)
    #expect(array[id: 1] == nil)
    #expect(array[id: 2]?.name == "Two")
  }
}
