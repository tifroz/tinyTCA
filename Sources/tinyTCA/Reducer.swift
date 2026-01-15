// Tiny TCA: Core Reducer protocol with composition support (Android-compatible, no Combine)
// Extended with Scope operator for parent/child composition
// Extended with ForEach operator for collection-based composition

import Foundation

/// A protocol that defines the core logic of a feature.
///
/// Reducers are pure functions that take the current state and an action,
/// and return a new state along with any effects to run.
public protocol Reducer<State, Action> {
  /// The state type managed by this reducer
  associatedtype State

  /// The action type handled by this reducer
  associatedtype Action

  /// Reduces the current state with an action to produce a new state and effects
  ///
  /// - Parameters:
  ///   - state: A mutable reference to the current state
  ///   - action: The action to process
  /// - Returns: An effect representing asynchronous work
  func reduce(into state: inout State, action: Action) -> Effect<Action>
}

// MARK: - Reducer Composition

extension Reducer {
  /// Combines this reducer with another reducer
  ///
  /// Both reducers run sequentially, allowing you to compose features together
  public func combined<Other: Reducer>(
    with other: Other
  ) -> CombinedReducer<Self, Other> where Other.State == State, Other.Action == Action {
    CombinedReducer(first: self, second: other)
  }

  /// Transforms this reducer to work on optional state
  ///
  /// Useful for parent features that contain optional child features
  public func optional() -> OptionalReducer<Self> {
    OptionalReducer(base: self)
  }
}

// MARK: - Internal Reducer Combinators

public struct CombinedReducer<R1: Reducer, R2: Reducer>: Reducer, Sendable
where R1.State == R2.State, R1.Action == R2.Action, R1: Sendable, R2: Sendable {
  @usableFromInline
  let first: R1
  @usableFromInline
  let second: R2

  // Internal initializer for .combined(with:)
  init(first: R1, second: R2) {
    self.first = first
    self.second = second
  }

  // Public initializer for ReducerBuilder
  @inlinable
  public init(_ first: R1, _ second: R2) {
    self.first = first
    self.second = second
  }

  @inlinable
  public func reduce(into state: inout R1.State, action: R1.Action) -> Effect<R1.Action> {
    let effect1 = first.reduce(into: &state, action: action)
    let effect2 = second.reduce(into: &state, action: action)
    return .merge(effect1, effect2)
  }
}

public struct OptionalReducer<Base: Reducer>: Reducer {
  let base: Base

  public func reduce(into state: inout Base.State?, action: Base.Action) -> Effect<Base.Action> {
    guard state != nil else { return .none }
    return base.reduce(into: &state!, action: action)
  }
}

// MARK: - Scope Reducer

/// Embeds a child reducer in a parent domain
///
/// `Scope` allows you to transform a parent domain into a child domain, and then run a child
/// reducer on that subset domain. This is crucial for breaking down large features into
/// smaller units.
///
/// Example:
/// ```swift
/// struct ParentReducer: Reducer {
///   struct State {
///     var child: ChildReducer.State
///   }
///
///   enum Action {
///     case child(ChildReducer.Action)
///   }
///
///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     Scope(
///       state: \.child,
///       action: CasePath(
///         extract: { if case .child(let a) = $0 { return a } else { return nil } },
///         embed: { .child($0) }
///       ),
///       child: ChildReducer()
///     )
///     .reduce(into: &state, action: action)
///   }
/// }
/// ```
public struct Scope<ParentState, ParentAction: Sendable, Child: Reducer>: Reducer, @unchecked Sendable
where Child.State: Sendable, Child.Action: Sendable, Child: Sendable, ParentState: Sendable {
  @usableFromInline
  let toChildState: WritableKeyPath<ParentState, Child.State>
  @usableFromInline
  let toChildAction: CasePath<ParentAction, Child.Action>
  @usableFromInline
  let child: Child

  /// Creates a scope reducer that embeds a child reducer in a parent domain
  ///
  /// - Parameters:
  ///   - toChildState: A writable key path from parent state to child state
  ///   - toChildAction: A case path from parent action to child action
  ///   - child: The child reducer to run on the child domain
  public init(
    state toChildState: WritableKeyPath<ParentState, Child.State>,
    action toChildAction: CasePath<ParentAction, Child.Action>,
    child: Child
  ) {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.child = child
  }

  public func reduce(
    into state: inout ParentState,
    action: ParentAction
  ) -> Effect<ParentAction> {
    // Only run child reducer if the action matches the child's domain
    guard let childAction = toChildAction.extract(from: action) else {
      return .none
    }

    // Run child reducer on the child slice of state
    let childEffect = child.reduce(into: &state[keyPath: toChildState], action: childAction)

    // Transform child effects back to parent effects
    return transformEffect(childEffect)
  }

  private func transformEffect(_ childEffect: Effect<Child.Action>) -> Effect<ParentAction> {
    switch childEffect.operation {
    case .none:
      return .none

    case let .run(priority, operation):
      return .run(priority: priority) { [toChildAction] send in
        // Create a child send that transforms actions to parent domain
        let childSend = Send<Child.Action> { childAction in
          Task {
            await send(toChildAction.embed(childAction))
          }
        }
        await operation(childSend)
      }
    }
  }
}

// MARK: - Scope Convenience Extension

extension Reducer {
  /// Embeds a child reducer that operates on a slice of this reducer's state
  ///
  /// Use this to compose child features into a parent feature.
  ///
  /// Example:
  /// ```swift
  /// struct ParentReducer: Reducer {
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Parent logic
  ///     }
  ///     .scope(
  ///       state: \.child,
  ///       action: CasePath(
  ///         extract: { if case .child(let a) = $0 { return a } else { return nil } },
  ///         embed: { .child($0) }
  ///       ),
  ///       child: ChildReducer()
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toChildState: Key path to child state
  ///   - toChildAction: Case path to child action
  ///   - child: The child reducer
  /// - Returns: A combined reducer that runs both parent and child logic
  public func scope<ChildState: Sendable, ChildAction: Sendable, Child: Reducer>(
    state toChildState: WritableKeyPath<State, ChildState>,
    action toChildAction: CasePath<Action, ChildAction>,
    child: Child
  ) -> CombinedReducer<Self, Scope<State, Action, Child>>
  where Child.State == ChildState, Child.Action == ChildAction, Action: Sendable {
    self.combined(
      with: Scope(state: toChildState, action: toChildAction, child: child)
    )
  }
}

// MARK: - ForEach Reducer

/// Embeds a child reducer for each element in a collection
///
/// `ForEach` allows you to run a child reducer on each element of a collection,
/// routing actions by ID to the appropriate element.
///
/// Example:
/// ```swift
/// struct TodosReducer: Reducer {
///   struct State {
///     var todos: IdentifiedArrayOf<Todo.State>
///   }
///
///   enum Action {
///     case todos(IdentifiedAction<UUID, Todo.Action>)
///   }
///
///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     ForEach(
///       state: \.todos,
///       action: CasePath(
///         extract: { if case .todos(let a) = $0 { return a.elementCasePath.extract(from: a) } else { return nil } },
///         embed: { .todos(.element(id: $0.id, action: $0.action)) }
///       ),
///       element: TodoReducer()
///     )
///     .reduce(into: &state, action: action)
///   }
/// }
/// ```
public struct ForEach<ParentState, ParentAction: Sendable, ID: Hashable & Sendable, Element: Reducer>: Reducer, @unchecked Sendable
where Element.State: Sendable, Element.Action: Sendable, Element: Sendable, ParentState: Sendable {
  @usableFromInline
  let toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, Element.State>>
  @usableFromInline
  let toElementAction: CasePath<ParentAction, (id: ID, action: Element.Action)>
  @usableFromInline
  let element: Element

  /// Creates a forEach reducer
  ///
  /// - Parameters:
  ///   - toElementsState: Key path to the identified array of element states
  ///   - toElementAction: Case path that extracts (id, action) tuples
  ///   - element: The child reducer to run on each element
  public init(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CasePath<ParentAction, (id: ID, action: Element.Action)>,
    element: Element
  ) {
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
  }

  public func reduce(
    into state: inout ParentState,
    action: ParentAction
  ) -> Effect<ParentAction> {
    // Extract the (id, elementAction) from the parent action
    guard let (id, elementAction) = toElementAction.extract(from: action) else {
      return .none
    }

    // Ensure the element exists
    guard state[keyPath: toElementsState][id: id] != nil else {
      // Element was removed - this is not an error, just ignore
      return .none
    }

    // Run the element reducer on the specific element
    let elementEffect = element.reduce(
      into: &state[keyPath: toElementsState][id: id]!,
      action: elementAction
    )

    // Transform element effects back to parent effects
    return transformEffect(elementEffect, id: id)
  }

  private func transformEffect(
    _ elementEffect: Effect<Element.Action>,
    id: ID
  ) -> Effect<ParentAction> {
    switch elementEffect.operation {
    case .none:
      return .none

    case let .run(priority, operation):
      return .run(priority: priority) { [toElementAction] send in
        let elementSend = Send<Element.Action> { elementAction in
          Task {
            await send(toElementAction.embed((id, elementAction)))
          }
        }
        await operation(elementSend)
      }
    }
  }
}

// MARK: - ForEach Convenience Extension

extension Reducer {
  /// Embeds a child reducer for each element in an identified array
  ///
  /// Use this to manage collections of child features.
  ///
  /// Example:
  /// ```swift
  /// struct TodosReducer: Reducer {
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Parent logic (add/remove todos)
  ///     }
  ///     .forEach(
  ///       \.todos,
  ///       action: CasePath(
  ///         extract: { /* extract (id, action) */ },
  ///         embed: { .todos(.element(id: $0, action: $1)) }
  ///       ),
  ///       element: TodoReducer()
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toElementsState: Key path to identified array
  ///   - toElementAction: Case path to (id, action) tuple
  ///   - element: The child reducer
  /// - Returns: A combined reducer
  public func forEach<ID: Hashable & Sendable, ElementState: Sendable, ElementAction: Sendable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: CasePath<Action, (id: ID, action: ElementAction)>,
    element: Element
  ) -> CombinedReducer<Self, ForEach<State, Action, ID, Element>>
  where Element.State == ElementState, Element.Action == ElementAction, Action: Sendable {
    self.combined(
      with: ForEach(state: toElementsState, action: toElementAction, element: element)
    )
  }
}

// MARK: - CaseKeyPath Support for Scope

extension Scope {
  /// Creates a scope reducer using case key path syntax
  ///
  /// This initializer enables the ergonomic syntax:
  /// ```swift
  /// Scope(state: \.child, action: \.child) {
  ///     ChildReducer()
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toChildState: A writable key path from parent state to child state
  ///   - toChildAction: A case key path from parent action to child action
  ///   - child: A closure returning the child reducer
  public init<ChildAction>(
    state toChildState: WritableKeyPath<ParentState, Child.State>,
    action toChildAction: CaseKeyPath<ParentAction, ChildAction>,
    @ReducerBuilder<Child.State, ChildAction> child: () -> Child
  ) where Child.Action == ChildAction, ParentAction: CasePathable {
    self.init(
      state: toChildState,
      action: toChildAction.casePath,
      child: child()
    )
  }

  /// Creates a scope reducer using case key path from AllCasePaths
  ///
  /// - Parameters:
  ///   - toChildState: A writable key path from parent state to child state
  ///   - toChildAction: A key path into AllCasePaths that returns the case key path
  ///   - child: A closure returning the child reducer
  public init(
    state toChildState: WritableKeyPath<ParentState, Child.State>,
    action toChildAction: KeyPath<ParentAction.AllCasePaths, CaseKeyPath<ParentAction, Child.Action>>,
    @ReducerBuilder<Child.State, Child.Action> child: () -> Child
  ) where ParentAction: CasePathable {
    let caseKeyPath = ParentAction.allCasePaths[keyPath: toChildAction]
    self.init(
      state: toChildState,
      action: caseKeyPath.casePath,
      child: child()
    )
  }
}

// MARK: - CaseKeyPath Support for ForEach

extension ForEach {
  /// Creates a forEach reducer using case key path syntax
  ///
  /// - Parameters:
  ///   - toElementsState: Key path to the identified array of element states
  ///   - toElementAction: Case key path that extracts (id, action) tuples
  ///   - element: A closure returning the child reducer
  public init(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CaseKeyPath<ParentAction, (id: ID, action: Element.Action)>,
    @ReducerBuilder<Element.State, Element.Action> element: () -> Element
  ) where ParentAction: CasePathable {
    self.init(
      state: toElementsState,
      action: toElementAction.casePath,
      element: element()
    )
  }

  /// Creates a forEach reducer using case key path from AllCasePaths
  ///
  /// - Parameters:
  ///   - toElementsState: Key path to the identified array of element states
  ///   - toElementAction: A key path into AllCasePaths that returns the case key path
  ///   - element: A closure returning the child reducer
  public init(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, Element.State>>,
    action toElementAction: KeyPath<ParentAction.AllCasePaths, CaseKeyPath<ParentAction, (id: ID, action: Element.Action)>>,
    @ReducerBuilder<Element.State, Element.Action> element: () -> Element
  ) where ParentAction: CasePathable {
    let caseKeyPath = ParentAction.allCasePaths[keyPath: toElementAction]
    self.init(
      state: toElementsState,
      action: caseKeyPath.casePath,
      element: element()
    )
  }
}

// MARK: - IdentifiedActionOf Support for ForEach

extension ForEach where ParentAction: CasePathable {
  /// Creates a forEach reducer using IdentifiedActionOf ergonomic syntax
  ///
  /// This initializer bridges the type gap between `CaseKeyPath<Action, IdentifiedActionOf<Element>>`
  /// (what @CasePathable generates) and the tuple type ForEach expects internally.
  ///
  /// Example:
  /// ```swift
  /// ForEach(state: \.counters, action: Action.allCasePaths.counters) {
  ///     CounterReducer()
  /// }
  /// ```
  public init(
    state toElementsState: WritableKeyPath<ParentState, IdentifiedArray<ID, Element.State>>,
    action toIdentifiedAction: CaseKeyPath<ParentAction, IdentifiedActionOf<Element>>,
    @ReducerBuilder<Element.State, Element.Action> element: () -> Element
  ) where Element.State: Identifiable, ID == Element.State.ID {
    // Chain the CaseKeyPath through IdentifiedAction.elementCasePath
    let combinedCasePath = CasePath<ParentAction, (id: ID, action: Element.Action)>(
      extract: { parentAction in
        guard let identifiedAction = toIdentifiedAction.extract(parentAction) else { return nil }
        return IdentifiedAction<ID, Element.Action>.elementCasePath.extract(from: identifiedAction)
      },
      embed: { tuple in
        toIdentifiedAction.embed(.element(id: tuple.id, action: tuple.action))
      }
    )
    self.init(state: toElementsState, action: combinedCasePath, element: element())
  }
}

// MARK: - CaseKeyPath Convenience Extensions

extension Reducer {
  /// Embeds a child reducer using case key path syntax
  ///
  /// Example:
  /// ```swift
  /// Reduce { state, action in ... }
  ///     .scope(state: \.child, action: \.child) {
  ///         ChildReducer()
  ///     }
  /// ```
  public func scope<ChildState: Sendable, ChildAction: Sendable, Child: Reducer>(
    state toChildState: WritableKeyPath<State, ChildState>,
    action toChildAction: CaseKeyPath<Action, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child
  ) -> CombinedReducer<Self, Scope<State, Action, Child>>
  where Child.State == ChildState, Child.Action == ChildAction, Action: Sendable {
    self.combined(
      with: Scope(state: toChildState, action: toChildAction.casePath, child: child())
    )
  }

  /// Embeds a forEach reducer using case key path syntax
  ///
  /// Example:
  /// ```swift
  /// Reduce { state, action in ... }
  ///     .forEach(\.items, action: \.items) {
  ///         ItemReducer()
  ///     }
  /// ```
  public func forEach<ID: Hashable & Sendable, ElementState: Sendable, ElementAction: Sendable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: CaseKeyPath<Action, (id: ID, action: ElementAction)>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element
  ) -> CombinedReducer<Self, ForEach<State, Action, ID, Element>>
  where Element.State == ElementState, Element.Action == ElementAction, Action: Sendable {
    self.combined(
      with: ForEach(state: toElementsState, action: toElementAction.casePath, element: element())
    )
  }

  /// Embeds a forEach reducer using IdentifiedActionOf ergonomic syntax
  ///
  /// Example:
  /// ```swift
  /// Reduce { state, action in ... }
  ///     .forEach(\.counters, identifiedAction: Action.allCasePaths.counters) {
  ///         CounterReducer()
  ///     }
  /// ```
  public func forEach<Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArrayOf<Element.State>>,
    identifiedAction toIdentifiedAction: CaseKeyPath<Action, IdentifiedActionOf<Element>>,
    @ReducerBuilder<Element.State, Element.Action> element: () -> Element
  ) -> CombinedReducer<Self, ForEach<State, Action, Element.State.ID, Element>>
  where Element.State: Identifiable, Action: Sendable {
    // Build combined CasePath that chains through IdentifiedAction.elementCasePath
    let combinedCasePath = CasePath<Action, (id: Element.State.ID, action: Element.Action)>(
      extract: { action in
        guard let identifiedAction = toIdentifiedAction.extract(action) else { return nil }
        return IdentifiedAction<Element.State.ID, Element.Action>.elementCasePath.extract(from: identifiedAction)
      },
      embed: { tuple in
        toIdentifiedAction.embed(.element(id: tuple.id, action: tuple.action))
      }
    )
    return self.combined(
      with: ForEach(state: toElementsState, action: combinedCasePath, element: element())
    )
  }
}
