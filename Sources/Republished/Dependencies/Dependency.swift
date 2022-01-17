import Combine
import SwiftUI

/// A property wrapper that can read dependencies from enclosing `ObservableObject`s
///
/// Description
///
/// Example
@propertyWrapper
public struct Dependency<Value> {
  let keyPath: WritableKeyPath<Dependencies, Value>

  public init(_ keyPath: WritableKeyPath<Dependencies, Value>) {
    self.keyPath = keyPath
  }

  @available(*, unavailable, message: "@Dependency is only available on properties of classes")
  public var wrappedValue: Value {
    fatalError()
  }

  public static subscript<EnclosingSelf>(
    _enclosingInstance object: EnclosingSelf,
    wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: KeyPath<EnclosingSelf, Dependency<Value>>
  ) -> Value
    where EnclosingSelf: ObservableObject,
    EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    let dependencies = Dependencies.for(object)
    let keyPath = object[keyPath: storageKeyPath].keyPath
    return dependencies[keyPath: keyPath]
  }
}
