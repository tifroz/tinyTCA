// Tiny TCA: Simple CasePath for enum case extraction (Android-compatible, no dependencies)

import Foundation

/// A type that can extract and embed values from/into enum cases
///
/// CasePaths are like KeyPaths but for enums. They allow you to:
/// - Extract associated values from an enum case (if it matches)
/// - Embed a value back into an enum case
///
/// Example:
/// ```swift
/// enum Action {
///   case child(ChildAction)
///   case parent
/// }
///
/// let casePath = CasePath<Action, ChildAction>(
///   extract: { action in
///     if case .child(let childAction) = action {
///       return childAction
///     }
///     return nil
///   },
///   embed: { childAction in
///     .child(childAction)
///   }
/// )
/// ```
public struct CasePath<Root, Value>: Sendable where Root: Sendable, Value: Sendable {
  private let _extract: @Sendable (Root) -> Value?
  private let _embed: @Sendable (Value) -> Root

  /// Creates a case path with extract and embed functions
  ///
  /// - Parameters:
  ///   - extract: A function that attempts to extract a value from the root enum
  ///   - embed: A function that embeds a value into the root enum
  public init(
    extract: @escaping @Sendable (Root) -> Value?,
    embed: @escaping @Sendable (Value) -> Root
  ) {
    self._extract = extract
    self._embed = embed
  }

  /// Attempts to extract a value from the root enum
  ///
  /// - Parameter root: The enum to extract from
  /// - Returns: The extracted value, or nil if the case doesn't match
  public func extract(from root: Root) -> Value? {
    _extract(root)
  }

  /// Embeds a value into the root enum
  ///
  /// - Parameter value: The value to embed
  /// - Returns: The enum with the embedded value
  public func embed(_ value: Value) -> Root {
    _embed(value)
  }
}

// MARK: - Convenience Initializer

extension CasePath where Value == Void {
  /// Creates a case path for enum cases without associated values
  public init(embed: @escaping @Sendable () -> Root) {
    self.init(extract: { _ in () }, embed: { embed() })
  }
}
