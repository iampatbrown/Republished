import Combine
import SwiftUI

@propertyWrapper
public struct ScopedValue<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var scoped: ScopedSubject<ObjectType, Value>

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) where Value: ObservableObject {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    self.scoped.value
  }
  
  public func update() {
    self.scoped.root = self.root
  }
}
