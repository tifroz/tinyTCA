// Tiny TCA: Reduce struct for inline reducer logic

import Foundation

/// A reducer that executes a closure to handle actions
///
/// Use `Reduce` within a reducer's `body` property to define inline logic:
/// ```swift
/// var body: some ReducerOf<Self> {
///     Reduce { state, action in
///         switch action {
///         case .increment:
///             state.count += 1
///             return .none
///         case .decrement:
///             state.count -= 1
///             return .none
///         }
///     }
/// }
/// ```
public struct Reduce<State, Action>: Reducer, Sendable
where State: Sendable, Action: Sendable {
    @usableFromInline
    let reducer: @Sendable (inout State, Action) -> Effect<Action>

    /// Creates a reducer with a closure that handles state mutations
    ///
    /// - Parameter reduce: A closure that takes the current state and an action,
    ///   mutates the state, and returns any effects to execute.
    @inlinable
    public init(_ reduce: @escaping @Sendable (inout State, Action) -> Effect<Action>) {
        self.reducer = reduce
    }

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        reducer(&state, action)
    }
}

// MARK: - ReducerOf Type Alias

/// A type alias for a reducer with matching State and Action types
///
/// Use this for more ergonomic type annotations:
/// ```swift
/// var body: some ReducerOf<Self> { ... }
/// ```
public typealias ReducerOf<R: Reducer> = Reducer<R.State, R.Action>
