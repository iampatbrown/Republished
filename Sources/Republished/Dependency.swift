import Foundation
import SwiftUI

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

  public static subscript<EnclosingSelf: AnyObject>(
    _enclosingInstance object: EnclosingSelf,
    wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: KeyPath<EnclosingSelf, Dependency<Value>>
  ) -> Value {
    let dependencies = Dependencies.for(object)
    let keyPath = object[keyPath: storageKeyPath].keyPath
    return dependencies[keyPath: keyPath]
  }
}


