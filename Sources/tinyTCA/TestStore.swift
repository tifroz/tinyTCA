// Tiny TCA: TestStore for deterministic testing (Android-compatible, no Combine)

import Foundation

/// A testable version of Store that provides assertions for state changes and actions
///
/// TestStore allows you to write deterministic tests by stepping through actions
/// one at a time and asserting on state changes.
@MainActor
public final class TestStore<State, Action> {
  private let reducer: any Reducer<State, Action>
  private var state: State
  private var receivedActions: [Action] = []

  /// Creates a test store
  ///
  /// - Parameters:
  ///   - initialState: The initial state
  ///   - reducer: The reducer to test
  public init<R: Reducer>(
    initialState: State,
    reducer: R
  ) where R.State == State, R.Action == Action {
    self.state = initialState
    self.reducer = reducer
  }

  /// The current state for inspection
  public var currentState: State {
    state
  }

  /// Sends an action and asserts the resulting state change
  ///
  /// - Parameters:
  ///   - action: The action to send
  ///   - updateExpectedState: A closure to mutate the expected state
  ///   - file: The file where the assertion occurs (for better error messages)
  ///   - line: The line where the assertion occurs
  public func send(
    _ action: Action,
    assert updateExpectedState: ((inout State) -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async where Action: Sendable {
    receivedActions.append(action)

    var expectedState = state
    updateExpectedState?(&expectedState)

    _ = reducer.reduce(into: &state, action: action)

    // Check state matches expected
    if !areEqual(state, expectedState) {
      assertionFailure(
        """
        State change doesn't match expectation.
        Expected: \(expectedState)
        Received: \(state)
        """,
        file: file,
        line: line
      )
    }

    // Note: In a full implementation, you'd want to await and verify effects
    // For this minimal version, we skip effect verification
  }

  /// Finishes the test, asserting no effects are still running
  public func finish(file: StaticString = #file, line: UInt = #line) {
    // In a more sophisticated version, you'd track running effects
    // For now, this is a placeholder for test hygiene
  }

  private func areEqual(_ lhs: State, _ rhs: State) -> Bool {
    // For testing, we do a simple dump comparison
    // A production version might use a proper equality check or custom dump
    return String(reflecting: lhs) == String(reflecting: rhs)
  }

  private func assertionFailure(
    _ message: String,
    file: StaticString,
    line: UInt
  ) {
    #if DEBUG
    Swift.assertionFailure(message, file: file, line: line)
    #else
    print("Assertion failure at \(file):\(line) - \(message)")
    #endif
  }
}

// MARK: - Convenience Methods

extension TestStore {
  /// Sends an action without asserting state changes
  ///
  /// Useful when you only care about effects or later state
  public func send(_ action: Action) async where Action: Sendable {
    await send(action, assert: nil)
  }
}

// MARK: - Helper Extensions

extension TestStore where State: Equatable {
  /// Assert that the state equals an expected value
  public func assertState(
    _ expectedState: State,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    if state != expectedState {
      assertionFailure(
        """
        State doesn't match expectation.
        Expected: \(expectedState)
        Received: \(state)
        """,
        file: file,
        line: line
      )
    }
  }

  private func assertionFailure(_ message: String, file: StaticString, line: UInt) {
    #if DEBUG
    Swift.assertionFailure(message, file: file, line: line)
    #else
    print("Assertion failure at \(file):\(line) - \(message)")
    #endif
  }
}
