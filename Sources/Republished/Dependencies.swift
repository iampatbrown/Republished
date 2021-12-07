import Combine
import Foundation
import SwiftUI

public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
  static var testValue: Value { get }
  static var previewValue: Value { get }
}

extension DependencyKey {
  public static var testValue: Value { Self.defaultValue }
  public static var previewValue: Value { Self.defaultValue }

  fileprivate static var defaultValueForEnvironment: Value {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return Self.testValue }
    else if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return Self.previewValue }
    return Self.defaultValue
  }
}

public struct Dependencies {
  fileprivate var storage: [[ObjectIdentifier: Any]] = [[:]]
  private var isRunningWithDependenciesBody: Bool { self.storage.count > 1 }

  public init() {}

  public init(_ transform: (inout Dependencies) -> Void) {
    transform(&self)
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      let id = ObjectIdentifier(key)
      guard let value = self.storage.last?[id] as? Key.Value
      else { return Key.defaultValueForEnvironment }
      return value
    }
    set {
      self.storage[self.storage.count - 1][ObjectIdentifier(key)] = newValue
    }
  }

  @ThreadSafe static var shared = Dependencies()
}

extension Dependencies {
  static func bind<ObjectType: AnyObject>(
    _ dependencies: Dependencies,
    to object: ObjectType
  ) -> AnyCancellable {
    dependenciesLock.lock()
    defer { dependenciesLock.unlock() }
    let id = Dependencies.id(for: object)
    dependenciesStore[id] = dependencies
    return AnyCancellable {
      dependenciesLock.sync { dependenciesStore[id] = nil }
    }
  }

  static func bindInheritance<ObjectType: AnyObject>(
    _ object: ObjectType,
    parentId: @escaping () -> ObjectIdentifier?
  ) -> AnyCancellable {
    dependenciesLock.lock()
    defer { dependenciesLock.unlock() }
    let id = Dependencies.id(for: object)
    inheritanceRelationships[id] = parentId
    return AnyCancellable {
      dependenciesLock.sync { inheritanceRelationships[id] = nil }
    }
  }

  static func parentDependencies(for id: ObjectIdentifier) -> Dependencies? {
    guard var rootId = inheritanceRelationships[id]?() else { return nil }
    while let parentId = inheritanceRelationships[rootId]?() { rootId = parentId }
    return dependenciesStore[rootId]
  }

  static func `for`<ObjectType: AnyObject>(_ object: ObjectType) -> Dependencies {
    let id = Dependencies.id(for: object)

    if var dependencies = parentDependencies(for: id) ?? dependenciesStore[id] {
      if Dependencies.shared.isRunningWithDependenciesBody {
        for (id, value) in Dependencies.shared.storage.last! {
          dependencies.storage[dependencies.storage.count - 1][id] = value
        }
      }
      return dependencies
    } else {
      return Dependencies.shared
    }
  }

  static func id<ObjectType: AnyObject>(for object: ObjectType) -> ObjectIdentifier {
    observableObjectPublisher(for: object).map(ObjectIdentifier.init) ?? ObjectIdentifier(object)
  }
}

public func withDependencies<Result>(_ dependencies: Dependencies, _ body: () -> Result) -> Result {
  Dependencies.shared.storage.append(Dependencies.shared.storage.last!)
  for (id, value) in dependencies.storage.last! {
    Dependencies.shared.storage[Dependencies.shared.storage.count - 1][id] = value
  }
  defer { Dependencies.shared.storage.removeLast() }
  return body()
}

var dependenciesStore: [ObjectIdentifier: Dependencies] = [:]
var inheritanceRelationships: [ObjectIdentifier: () -> ObjectIdentifier?] = [:]
let dependenciesLock = NSRecursiveLock()
