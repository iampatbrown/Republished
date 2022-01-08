import Combine
import Foundation
import SwiftUI

public struct Dependencies {
  private var storage: [[ObjectIdentifier: Any]] = [[:]]
  private var values: [ObjectIdentifier: Any] {
    _read { yield self.storage[self.storage.endIndex - 1] }
    _modify { yield &self.storage[self.storage.endIndex - 1] }
  }

  var hasMergedValues: Bool { self.storage.count > 1 }

  public init() {}

  public init(_ transform: (inout Dependencies) -> Void) {
    transform(&self)
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get { self.values[ObjectIdentifier(key)] as? Key.Value ?? self.defaultValue(key: key) }
    set { self.values[ObjectIdentifier(key)] = newValue }
  }

  private func defaultValue<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    if ProcessInfo.isRunningUnitTests { return key.testValue }
    else if ProcessInfo.isRunningPreviews { return key.previewValue }
    return key.defaultValue
  }

  mutating func push(_ dependencies: Dependencies) {
    self.storage.append(self.values)
    self.values.merge(dependencies.values) { $1 }
  }

  mutating func popLast() {
    self.storage.removeLast()
    if self.storage.isEmpty { self.storage.append([:]) }
  }

  @ThreadSafe static var shared = Dependencies()
}

extension Dependencies {
  @ThreadSafe private static var store: [ObjectIdentifier: Dependencies] = [:]
  @ThreadSafe private static var inheritanceRelationships: [ObjectIdentifier: () -> ObjectIdentifier?] = [:]

  private static let lock = NSRecursiveLock()

  static func bind<ObjectType: AnyObject>(
    _ dependencies: Dependencies,
    to object: ObjectType
  ) -> AnyCancellable {
    let id = Dependencies.id(for: object)
    Self.store[id] = dependencies
    return AnyCancellable {
      Self.store[id] = nil
    }
  }

  static func bindInheritance<ObjectType: AnyObject>(
    _ object: ObjectType,
    parentId: @escaping () -> ObjectIdentifier?
  ) -> AnyCancellable {
    let id = Dependencies.id(for: object)
    Self.inheritanceRelationships[id] = parentId
    return AnyCancellable {
      Self.inheritanceRelationships[id] = nil
    }
  }

  static func inheritedDependencies(for id: ObjectIdentifier) -> Dependencies? {
    // TODO: Clean up with Token
    guard var rootId = Self.inheritanceRelationships[id]?() else { return nil }
    while let parentId = Self.inheritanceRelationships[rootId]?() {
      rootId = parentId
    }
    return Self.store[rootId]
  }

  static func `for`<ObjectType: AnyObject>(_ object: ObjectType) -> Dependencies {
    let id = Dependencies.id(for: object)

    if var dependencies = inheritedDependencies(for: id) ?? store[id] {
      if Dependencies.shared.hasMergedValues {
        dependencies.push(Dependencies.shared)
      }
      return dependencies
    } else {
      return Dependencies.shared
    }
  }

  static func id<ObjectType: AnyObject>(for object: ObjectType) -> ObjectIdentifier {
    ObservableObjectPublisher.extract(from: object).map(ObjectIdentifier.init) ?? ObjectIdentifier(object)
  }
}
