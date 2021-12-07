import Foundation

public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
  static var testValue: Value { get }
  static var previewValue: Value { get }
}

extension DependencyKey {
  static var testValue: Value { Self.defaultValue }
  static var previewValue: Value { Self.defaultValue }
}

public class Dependencies {
  @usableFromInline
  static var shared = Dependencies()

  private var storage: [[ObjectIdentifier: Any]] = [[:]]

  @usableFromInline
  func withDependencies<Result>(_ transform: (Dependencies) -> Result) -> Result {
    self.storage.append(self.storage.last!)
    defer { self.storage.removeLast() }
    return transform(Self.shared)
  }

  func merge(with other: Dependencies) {
    for (id, value) in other.storage.last! {
      self.storage[self.storage.count - 1][id] = value
    }
  }

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      let id = ObjectIdentifier(key)
      guard let dependency = self.storage.last?[id]
      else {
        let dependency = self.defaultValue(for: key)
        self.storage[self.storage.count - 1][id] = dependency
        return self.storage.last![id] as! Key.Value
      }
      guard let value = dependency as? Key.Value
      else { fatalError("TODO: message") }
      return value
    }
    set {
      self.storage[self.storage.count - 1][ObjectIdentifier(key)] = newValue
    }
  }

  func defaultValue<Key: DependencyKey>(for key: Key.Type) -> Key.Value {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return Key.testValue }
    else if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return Key.previewValue }
    return Key.defaultValue
  }
}

@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: WritableKeyPath<Dependencies, Value>

  public init(_ keyPath: WritableKeyPath<Dependencies, Value>) {
    self.keyPath = keyPath
  }

  public init(wrappedValue: Value, _ keyPath: WritableKeyPath<Dependencies, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    Dependencies.shared[keyPath: self.keyPath]
  }
}

private enum ANumber: DependencyKey {
  static let defaultValue = 1
}

extension Dependencies {
  var aNumber: Int {
    get { self[ANumber.self] }
    set { self[ANumber.self] = newValue }
  }
}

class ViewModel {
  @Dependency(\.aNumber) var aNumber
}

let viewModel = ViewModel()


