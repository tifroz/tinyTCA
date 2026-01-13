// Tiny TCA: AsyncStream-based Effect system (Android-compatible, no Combine)

import Foundation

/// Represents an asynchronous unit of work that can emit actions
///
/// Effects are returned from reducers to perform side effects like network requests,
/// timers, or other async operations. Unlike Combine-based TCA, this uses AsyncStream
/// and Swift Concurrency, making it Android-compatible.
public struct Effect<Action>: Sendable {
  @usableFromInline
  internal enum Operation: Sendable {
    case none
    case run(
      priority: TaskPriority?,
      operation: @Sendable (Send<Action>) async -> Void
    )
  }

  @usableFromInline
  internal let operation: Operation

  @usableFromInline
  internal init(operation: Operation) {
    self.operation = operation
  }
}

// MARK: - Creating Effects

extension Effect {
  /// An effect that does nothing and completes immediately
  @inlinable
  public static var none: Self {
    Self(operation: .none)
  }

  /// Wraps an asynchronous unit of work in an effect
  ///
  /// Example:
  /// ```swift
  /// return .run { send in
  ///   let data = try await apiClient.fetch()
  ///   await send(.dataLoaded(data))
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - priority: Priority of the task
  ///   - operation: Async work to perform, with a send function to emit actions
  /// - Returns: An effect
  public static func run(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable (Send<Action>) async -> Void
  ) -> Self {
    Self(operation: .run(priority: priority, operation: operation))
  }

  /// Creates an effect that immediately sends a single action
  ///
  /// - Parameter action: The action to send
  /// - Returns: An effect
  public static func send(_ action: Action) -> Self where Action: Sendable {
    .run { send in
      send(action)
    }
  }

  /// Creates an effect from an async sequence
  ///
  /// - Parameter sequence: The async sequence to consume
  /// - Returns: An effect that emits each value as an action
  public static func run<S: AsyncSequence>(
    _ sequence: S
  ) -> Self where S.Element == Action, S: Sendable, Action: Sendable {
    .run { send in
      do {
        for try await action in sequence {
          await send(action)
        }
      } catch {
        // Silently ignore errors
      }
    }
  }
}

// MARK: - Transforming Effects

extension Effect {
  /// Transforms the actions emitted by this effect
  ///
  /// - Parameter transform: A function to transform actions
  /// - Returns: A new effect with transformed actions
  public func map<NewAction>(_ transform: @escaping @Sendable (Action) -> NewAction) -> Effect<NewAction> where NewAction: Sendable {
    switch operation {
    case .none:
      return .none

    case let .run(priority, operation):
      return .run(priority: priority) { send in
        await operation(Send { action in
          send(transform(action))
        })
      }
    }
  }
}

// MARK: - Combining Effects

extension Effect {
  /// Merges multiple effects into one
  ///
  /// All effects run concurrently
  public static func merge(_ effects: Effect...) -> Self {
    .merge(effects)
  }

  /// Merges an array of effects into one
  public static func merge(_ effects: [Effect]) -> Self {
    .run { send in
      await withTaskGroup(of: Void.self) { group in
        for effect in effects {
          group.addTask {
            await effect.run(send: send)
          }
        }
      }
    }
  }

  /// Concatenates multiple effects to run sequentially
  public static func concatenate(_ effects: Effect...) -> Self {
    .concatenate(effects)
  }

  /// Concatenates an array of effects to run sequentially
  public static func concatenate(_ effects: [Effect]) -> Self {
    .run { send in
      for effect in effects {
        await effect.run(send: send)
      }
    }
  }
}

// MARK: - Effect Execution

extension Effect {
  /// Runs the effect
  @usableFromInline
  internal func run(send: Send<Action>) async {
    switch operation {
    case .none:
      break
    case let .run(priority, operation):
      if let priority {
        await Task(priority: priority) {
          await operation(send)
        }.value
      } else {
        await operation(send)
      }
    }
  }
}

/// A type-erased way to send actions from effects
public struct Send<Action>: Sendable {
  private let _send: @Sendable (Action) -> Void

  internal init(send: @escaping @Sendable (Action) -> Void) {
    self._send = send
  }

  /// Sends an action back to the store
  public func callAsFunction(_ action: Action) async {
    self._send(action)
  }

  /// Sends an action back to the store (non-async version)
  public func callAsFunction(_ action: Action) {
    self._send(action)
  }
}
