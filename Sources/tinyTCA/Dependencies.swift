// Tiny TCA: Simple dependency injection system (Android-compatible, no Combine)

import Foundation

/// A property wrapper for accessing dependencies
///
/// Dependencies are resolved from the current context, allowing you to swap
/// implementations for testing.
@propertyWrapper
public struct Dependency<Value>: @unchecked Sendable {
  private let keyPath: WritableKeyPath<DependencyValues, Value>

  public init(_ keyPath: WritableKeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: keyPath]
  }
}

/// A collection of dependency values
///
/// Extend this type to add your own dependencies:
/// ```swift
/// extension DependencyValues {
///   var apiClient: APIClient {
///     get { self[APIClientKey.self] }
///     set { self[APIClientKey.self] = newValue }
///   }
/// }
/// ```
public struct DependencyValues: Sendable {
  private var storage: [ObjectIdentifier: any Sendable] = [:]

  @TaskLocal
  static var current = DependencyValues()

  subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      if let value = storage[ObjectIdentifier(key)] as? Key.Value {
        return value
      }
      return Key.defaultValue
    }
    set {
      storage[ObjectIdentifier(key)] = newValue
    }
  }

  /// Runs a closure with overridden dependencies
  ///
  /// - Parameters:
  ///   - updateValues: A closure to modify the dependency values
  ///   - operation: The operation to run with modified dependencies
  public static func withValues<T>(
    _ updateValues: (inout DependencyValues) -> Void,
    operation: () async throws -> T
  ) async rethrows -> T {
    var values = current
    updateValues(&values)
    return try await $current.withValue(values) {
      try await operation()
    }
  }
}

/// A key for accessing dependencies
public protocol DependencyKey {
  associatedtype Value: Sendable
  static var defaultValue: Value { get }
}
