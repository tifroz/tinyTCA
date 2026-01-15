// Tiny TCA: ReducerBuilder result builder for declarative composition

import Foundation

/// Result builder for composing reducers declaratively
///
/// This enables the following syntax in a reducer's `body`:
/// ```swift
/// var body: some ReducerOf<Self> {
///     Scope(state: \.child, action: \.child) {
///         ChildReducer()
///     }
///     Reduce { state, action in
///         // parent logic
///     }
/// }
/// ```
@resultBuilder
public struct ReducerBuilder<State, Action> where State: Sendable, Action: Sendable {

    // MARK: - Single Reducer

    /// Builds a single reducer expression
    public static func buildBlock<R: Reducer>(_ reducer: R) -> R
    where R.State == State, R.Action == Action {
        reducer
    }

    // MARK: - Two Reducers

    /// Combines two reducers into one
    public static func buildBlock<R0: Reducer, R1: Reducer>(
        _ r0: R0,
        _ r1: R1
    ) -> CombinedReducer<R0, R1>
    where R0.State == State, R0.Action == Action,
          R1.State == State, R1.Action == Action {
        CombinedReducer(r0, r1)
    }

    // MARK: - Three Reducers

    /// Combines three reducers into one
    public static func buildBlock<R0: Reducer, R1: Reducer, R2: Reducer>(
        _ r0: R0,
        _ r1: R1,
        _ r2: R2
    ) -> CombinedReducer<CombinedReducer<R0, R1>, R2>
    where R0.State == State, R0.Action == Action,
          R1.State == State, R1.Action == Action,
          R2.State == State, R2.Action == Action {
        CombinedReducer(CombinedReducer(r0, r1), r2)
    }

    // MARK: - Four Reducers

    /// Combines four reducers into one
    public static func buildBlock<R0: Reducer, R1: Reducer, R2: Reducer, R3: Reducer>(
        _ r0: R0,
        _ r1: R1,
        _ r2: R2,
        _ r3: R3
    ) -> CombinedReducer<CombinedReducer<CombinedReducer<R0, R1>, R2>, R3>
    where R0.State == State, R0.Action == Action,
          R1.State == State, R1.Action == Action,
          R2.State == State, R2.Action == Action,
          R3.State == State, R3.Action == Action {
        CombinedReducer(CombinedReducer(CombinedReducer(r0, r1), r2), r3)
    }

    // MARK: - Five Reducers

    /// Combines five reducers into one
    public static func buildBlock<R0: Reducer, R1: Reducer, R2: Reducer, R3: Reducer, R4: Reducer>(
        _ r0: R0,
        _ r1: R1,
        _ r2: R2,
        _ r3: R3,
        _ r4: R4
    ) -> CombinedReducer<CombinedReducer<CombinedReducer<CombinedReducer<R0, R1>, R2>, R3>, R4>
    where R0.State == State, R0.Action == Action,
          R1.State == State, R1.Action == Action,
          R2.State == State, R2.Action == Action,
          R3.State == State, R3.Action == Action,
          R4.State == State, R4.Action == Action {
        CombinedReducer(CombinedReducer(CombinedReducer(CombinedReducer(r0, r1), r2), r3), r4)
    }

    // MARK: - Optional Support

    /// Builds an optional reducer (for if statements without else)
    public static func buildOptional<R: Reducer>(_ reducer: R?) -> _BuilderOptionalReducer<R>
    where R.State == State, R.Action == Action {
        _BuilderOptionalReducer(reducer)
    }

    // MARK: - Conditional Support

    /// Builds the first branch of an if-else
    public static func buildEither<First: Reducer, Second: Reducer>(
        first: First
    ) -> ConditionalReducer<First, Second>
    where First.State == State, First.Action == Action,
          Second.State == State, Second.Action == Action {
        .first(first)
    }

    /// Builds the second branch of an if-else
    public static func buildEither<First: Reducer, Second: Reducer>(
        second: Second
    ) -> ConditionalReducer<First, Second>
    where First.State == State, First.Action == Action,
          Second.State == State, Second.Action == Action {
        .second(second)
    }
}

// MARK: - Builder Optional Reducer

/// Internal reducer type for ReducerBuilder optional support
public struct _BuilderOptionalReducer<Wrapped: Reducer>: Reducer, Sendable
where Wrapped: Sendable {
    public typealias State = Wrapped.State
    public typealias Action = Wrapped.Action

    @usableFromInline
    let wrapped: Wrapped?

    @inlinable
    init(_ wrapped: Wrapped?) {
        self.wrapped = wrapped
    }

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        wrapped?.reduce(into: &state, action: action) ?? .none
    }
}

// MARK: - ConditionalReducer

/// A reducer that represents one of two possible reducers
public enum ConditionalReducer<First: Reducer, Second: Reducer>: Reducer, Sendable
where First.State == Second.State, First.Action == Second.Action,
      First: Sendable, Second: Sendable {
    public typealias State = First.State
    public typealias Action = First.Action

    case first(First)
    case second(Second)

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch self {
        case .first(let reducer):
            return reducer.reduce(into: &state, action: action)
        case .second(let reducer):
            return reducer.reduce(into: &state, action: action)
        }
    }
}
