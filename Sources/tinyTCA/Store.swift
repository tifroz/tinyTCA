// Tiny TCA: Main Store implementation with state management (Android-compatible, no Combine)

import Foundation

/// A runtime that powers a feature's logic and handles its effects
///
/// The store manages state, processes actions through the reducer, and runs effects.
/// It's the central coordinator of your feature.
@MainActor
public final class Store<State, Action>: Sendable {
  private let reducer: any Reducer<State, Action>
  private var state: State
  private var effectTasks: [UUID: Task<Void, Never>] = [:]

  /// Creates a store with an initial state and a reducer
  ///
  /// - Parameters:
  ///   - initialState: The initial state
  ///   - reducer: The reducer that handles actions
  public init<R: Reducer>(
    initialState: State,
    reducer: R
  ) where R.State == State, R.Action == Action {
    self.state = initialState
    self.reducer = reducer
  }

  /// The current state
  public var currentState: State {
    state
  }

  /// Sends an action to the store
  ///
  /// The action is processed by the reducer, which updates the state and returns
  /// any effects to run. Effects are automatically managed and cancelled when appropriate.
  ///
  /// - Parameter action: The action to send
  public func send(_ action: Action) async where Action: Sendable {
    let effect = reducer.reduce(into: &state, action: action)
    await runEffect(effect)
  }

  /// Sends an action synchronously (fire-and-forget)
  ///
  /// Use this when you don't need to wait for effects to complete
  public func send(_ action: Action) where Action: Sendable {
    Task { await send(action) }
  }

  private func runEffect(_ effect: Effect<Action>) async where Action: Sendable {
    let id = UUID()
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      let send = Send<Action> { action in
        Task { @MainActor [weak self] in
          await self?.send(action)
        }
      }
      await effect.run(send: send)
      self.effectTasks.removeValue(forKey: id)
    }
    effectTasks[id] = task
    await task.value
  }

  /// Cancels all running effects
  public func cancelEffects() {
    for (_, task) in effectTasks {
      task.cancel()
    }
    effectTasks.removeAll()
  }

  deinit {
    for (_, task) in effectTasks {
      task.cancel()
    }
  }
}

// MARK: - Observable State (for SwiftUI)

#if canImport(Observation)
import Observation

extension Store: Observable {}
#endif
