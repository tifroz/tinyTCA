// Tiny TCA: Action wrapper for collection element actions tagged with IDs

import Foundation

/// An action type for collection elements that includes the element's ID
///
/// When working with collections of child features using `forEach`, actions
/// are wrapped in IdentifiedAction to route them to the correct element.
///
/// Example:
/// ```swift
/// enum ParentAction {
///   case todos(IdentifiedAction<UUID, TodoAction>)
/// }
///
/// store.send(.todos(.element(id: todoID, action: .toggle)))
/// ```
public enum IdentifiedAction<ID: Hashable & Sendable, Action: Sendable>: Sendable {
  /// An action targeted at a specific element by ID
  case element(id: ID, action: Action)
}

// MARK: - Convenience

extension IdentifiedAction {
  /// Creates a case path for extracting element actions
  public static var elementCasePath: CasePath<Self, (id: ID, action: Action)> {
    CasePath(
      extract: { action in
        if case .element(let id, let innerAction) = action {
          return (id, innerAction)
        }
        return nil
      },
      embed: { .element(id: $0.id, action: $0.action) }
    )
  }
}

// MARK: - Conformances

extension IdentifiedAction: Equatable where Action: Equatable {}
extension IdentifiedAction: Hashable where Action: Hashable {}

// MARK: - Type Alias

/// A convenience type alias for identified actions of a given reducer
public typealias IdentifiedActionOf<R: Reducer> = IdentifiedAction<R.State.ID, R.Action>
where R.State: Identifiable
