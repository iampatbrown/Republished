import Combine
import SwiftUI

public struct Dependencies {
  private var stack = Stack<ObjectIdentifier, Any>()

  var hasPushedDependencies: Bool { self.stack.size > 1 }

  public init() {}

  public init(_ transform: (inout Dependencies) -> Void) {
    transform(&self)
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get { self.stack[ObjectIdentifier(key)] as? Key.Value ?? key.environmentDefault }
    set { self.stack[ObjectIdentifier(key)] = newValue }
  }

  mutating func push(_ dependencies: Dependencies) {
    self.stack.push(dependencies.stack)
  }

  mutating func popLast() {
    self.stack.popLast()
  }

  @ThreadSafe static var shared = Dependencies()
}

extension Dependencies {
  @ThreadSafe private static var store: [ObjectIdentifier: Dependencies] = [:]
  @ThreadSafe private static var inheritanceRelationships: [ObjectIdentifier: () -> ObjectIdentifier?] = [:]

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
    guard var rootId = Self.inheritanceRelationships[id]?() else { return nil }
    while let parentId = Self.inheritanceRelationships[rootId]?() {
      rootId = parentId
    }
    return Self.store[rootId]
  }

  static func `for`<ObjectType: AnyObject>(_ object: ObjectType) -> Dependencies {
    let id = Dependencies.id(for: object)
    if var dependencies = Self.inheritedDependencies(for: id) ?? Self.store[id] {
      if Dependencies.shared.hasPushedDependencies { dependencies.push(Dependencies.shared) }
      return dependencies
    } else {
      return Dependencies.shared
    }
  }

  static func id<ObjectType: AnyObject>(for object: ObjectType) -> ObjectIdentifier {
    ObservableObjectPublisher.extract(from: object).map(ObjectIdentifier.init) ?? ObjectIdentifier(object)
  }
}
