// Tiny TCA: Simple IdentifiedArray for managing collections with stable IDs

import Foundation

/// A collection that ensures elements have unique identifiers
///
/// Similar to a regular Array, but provides O(1) lookup by ID and ensures
/// no duplicate IDs exist in the collection.
///
/// This is a simplified version of Point-Free's IdentifiedArray, designed
/// to work on any platform without dependencies.
public struct IdentifiedArray<ID: Hashable, Element>: @unchecked Sendable
where ID: Sendable, Element: Sendable {
  private var elements: [Element]
  private var idToIndex: [ID: Int]
  private let idExtractor: (Element) -> ID

  /// Creates an empty identified array
  ///
  /// - Parameter id: A key path to the element's identifier
  public init(id: KeyPath<Element, ID>) {
    self.elements = []
    self.idToIndex = [:]
    self.idExtractor = { element in element[keyPath: id] }
  }

  /// Creates an identified array from a sequence
  ///
  /// - Parameters:
  ///   - elements: The elements to initialize with
  ///   - id: A key path to the element's identifier
  public init<S: Sequence>(_ elements: S, id: KeyPath<Element, ID>) where S.Element == Element, KeyPath<Element, ID>: Sendable {
    self.init(id: id)
    for element in elements {
      self.append(element)
    }
  }

  /// Returns all IDs in the array, in order
  public var ids: [ID] {
    elements.map(idExtractor)
  }

  /// Accesses an element by its ID
  ///
  /// - Parameter id: The identifier of the element
  /// - Returns: The element if found, nil otherwise
  public subscript(id id: ID) -> Element? {
    get {
      guard let index = idToIndex[id] else { return nil }
      return elements[index]
    }
    set {
      guard let newValue else {
        remove(id: id)
        return
      }

      if let existingIndex = idToIndex[id] {
        elements[existingIndex] = newValue
      } else {
        append(newValue)
      }
    }
  }

  /// Adds an element to the end of the array
  ///
  /// If an element with the same ID already exists, this is a no-op.
  ///
  /// - Parameter element: The element to append
  public mutating func append(_ element: Element) {
    let id = idExtractor(element)
    guard idToIndex[id] == nil else { return }

    let index = elements.count
    elements.append(element)
    idToIndex[id] = index
  }

  /// Removes an element with the given ID
  ///
  /// - Parameter id: The identifier of the element to remove
  @discardableResult
  public mutating func remove(id: ID) -> Element? {
    guard let index = idToIndex[id] else { return nil }

    let removed = elements.remove(at: index)
    idToIndex.removeValue(forKey: id)

    // Update indices for all elements after the removed one
    for i in index..<elements.count {
      let elementID = idExtractor(elements[i])
      idToIndex[elementID] = i
    }

    return removed
  }

  /// Removes all elements
  public mutating func removeAll() {
    elements.removeAll()
    idToIndex.removeAll()
  }
}

// MARK: - Collection Conformance

extension IdentifiedArray: Collection {
  public typealias Index = Int

  public var startIndex: Int {
    elements.startIndex
  }

  public var endIndex: Int {
    elements.endIndex
  }

  public func index(after i: Int) -> Int {
    elements.index(after: i)
  }

  public subscript(position: Int) -> Element {
    elements[position]
  }
}

// MARK: - Additional Conveniences

extension IdentifiedArray {
  /// The number of elements in the array
  public var count: Int {
    elements.count
  }

  /// Whether the array is empty
  public var isEmpty: Bool {
    elements.isEmpty
  }

  /// The first element, if any
  public var first: Element? {
    elements.first
  }

  /// The last element, if any
  public var last: Element? {
    elements.last
  }

  /// Returns the element at the given index
  public func element(at index: Int) -> Element? {
    guard indices.contains(index) else { return nil }
    return elements[index]
  }

  /// Checks if an element with the given ID exists
  public func contains(id: ID) -> Bool {
    idToIndex[id] != nil
  }
}

// MARK: - Identifiable Convenience

extension IdentifiedArray where Element: Identifiable, ID == Element.ID {
  /// Creates an empty identified array for Identifiable elements
  public init() {
    self.init(id: \.id)
  }

  /// Creates an identified array from a sequence of Identifiable elements
  public init<S: Sequence>(_ elements: S) where S.Element == Element {
    self.init(elements, id: \.id)
  }
}

// MARK: - Equatable

extension IdentifiedArray: Equatable where Element: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.elements == rhs.elements
  }
}

// MARK: - Hashable

extension IdentifiedArray: Hashable where Element: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(elements)
  }
}

// MARK: - Codable

extension IdentifiedArray: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    fatalError("IdentifiedArray Decodable requires id keypath - use init(_:id:)")
  }
}

extension IdentifiedArray: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try elements.encode(to: encoder)
  }
}

// MARK: - Type Alias

/// A convenience type alias for identified arrays of Identifiable elements
public typealias IdentifiedArrayOf<Element: Identifiable> = IdentifiedArray<Element.ID, Element>
